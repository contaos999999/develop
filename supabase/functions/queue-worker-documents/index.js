import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL = Deno.env.get('SUPABASE_URL')
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const sb = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } })

class AppError extends Error {
  constructor(codigo, mensagem) {
    super(mensagem)
    this.codigo = codigo
  }
}

const mensagens = {
  ARQUIVO_INTEGRIDADE: 'Não foi possível confirmar a integridade do arquivo. Envie o documento novamente.',
  ARQUIVO_TIPO_NAO_SUPORTADO: 'Este formato de arquivo não pode ser processado pelo ContaOS.',
  ARQUIVO_BLOQUEADO_SEGURANCA: 'O arquivo foi bloqueado pela validação de segurança e não será utilizado na análise.',
  ARQUIVO_PROCESSAMENTO_MUITO_GRANDE: 'O arquivo foi armazenado com segurança, mas ultrapassa o limite do processamento automático deste ambiente.',
  ARQUIVO_COMPACTADO_INSEGURO: 'O arquivo compactado foi bloqueado porque sua estrutura excede os limites seguros de processamento.',
  DOCUMENTO_PROCESSAMENTO_FALHOU: 'Não foi possível concluir a leitura do documento. Tente novamente.',
}
const mensagem = (codigo) => mensagens[codigo] ?? mensagens.DOCUMENTO_PROCESSAMENTO_FALHOU

async function sha256Hex(bytes) {
  const h = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, '0')).join('')
}
function extensao(nome) { return (nome.split('.').pop() ?? '').toLowerCase() }
function mimeCompativel(ext, mime) {
  const m = String(mime ?? '').toLowerCase()
  const mapa = {
    pdf: ['application/pdf'],
    xlsx: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    csv: ['text/csv'],
    docx: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    png: ['image/png'], jpg: ['image/jpeg'], jpeg: ['image/jpeg'], webp: ['image/webp'],
    txt: ['text/plain'], json: ['application/json'], xml: ['application/xml', 'text/xml'],
  }
  return (mapa[ext] ?? []).includes(m)
}
function assinaturaValida(nome, mime, bytes) {
  const ext = extensao(nome)
  if (!mimeCompativel(ext, mime)) return false
  if (bytes.length >= 2 && bytes[0] === 0x4d && bytes[1] === 0x5a) return false
  if (bytes.length >= 4 && bytes[0] === 0x7f && bytes[1] === 0x45 && bytes[2] === 0x4c && bytes[3] === 0x46) return false
  if (ext === 'pdf') return new TextDecoder().decode(bytes.slice(0, 5)) === '%PDF-'
  if (ext === 'docx' || ext === 'xlsx') return bytes.length >= 4 && bytes[0] === 0x50 && bytes[1] === 0x4b
  if (ext === 'png') return bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47
  if (ext === 'jpg' || ext === 'jpeg') return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
  if (ext === 'webp') return bytes.length >= 12 && new TextDecoder().decode(bytes.slice(0, 4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8, 12)) === 'WEBP'
  if (ext === 'json') { try { JSON.parse(new TextDecoder('utf-8', { fatal: false }).decode(bytes)); return true } catch { return false } }
  return ['txt', 'csv', 'xml'].includes(ext)
}
function validarZipSeguro(bytes, cfg) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const minimo = Math.max(0, bytes.length - 22 - 65535)
  let eocd = -1
  for (let p = bytes.length - 22; p >= minimo; p--) {
    if (view.getUint32(p, true) === 0x06054b50) { eocd = p; break }
  }
  if (eocd < 0) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Diretório central ZIP não encontrado.')
  const entradas = view.getUint16(eocd + 10, true)
  const tamanhoCentral = view.getUint32(eocd + 12, true)
  const offsetCentral = view.getUint32(eocd + 16, true)
  if (entradas === 0xffff || tamanhoCentral === 0xffffffff || offsetCentral === 0xffffffff) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'ZIP64 não é aceito no processamento automático.')
  const maxEntradas = Number(cfg?.max_entradas_compactadas ?? 5000)
  const maxDescompactado = Number(cfg?.tamanho_maximo_descompactado_bytes ?? 104857600)
  const maxRazao = Number(cfg?.razao_maxima_compactacao ?? 200)
  if (entradas > maxEntradas || offsetCentral + tamanhoCentral > bytes.length) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Estrutura ZIP excede os limites seguros.')
  let pos = offsetCentral; let totalDescompactado = 0
  const decoder = new TextDecoder('utf-8', { fatal: false })
  for (let i = 0; i < entradas; i++) {
    if (pos + 46 > bytes.length || view.getUint32(pos, true) !== 0x02014b50) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Entrada ZIP inválida.')
    const flags = view.getUint16(pos + 8, true)
    const comprimido = view.getUint32(pos + 20, true)
    const descompactado = view.getUint32(pos + 24, true)
    const nomeLen = view.getUint16(pos + 28, true)
    const extraLen = view.getUint16(pos + 30, true)
    const comentarioLen = view.getUint16(pos + 32, true)
    if (comprimido === 0xffffffff || descompactado === 0xffffffff || (flags & 0x0001) !== 0) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Entrada ZIP criptografada ou ZIP64 não é aceita.')
    if (pos + 46 + nomeLen + extraLen + comentarioLen > bytes.length) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Entrada ZIP truncada.')
    const nome = decoder.decode(bytes.slice(pos + 46, pos + 46 + nomeLen)).replace(/\\/g, '/')
    if (nome.startsWith('/') || /^[A-Za-z]:\//.test(nome) || nome.split('/').includes('..')) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Caminho inseguro dentro do arquivo compactado.')
    totalDescompactado += descompactado
    if (totalDescompactado > maxDescompactado) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Conteúdo descompactado excede o limite seguro.')
    if (descompactado > 1048576 && descompactado / Math.max(comprimido, 1) > maxRazao) throw new AppError('ARQUIVO_COMPACTADO_INSEGURO', 'Razão de compactação suspeita detectada.')
    pos += 46 + nomeLen + extraLen + comentarioLen
  }
  return { entradas, totalDescompactado }
}
function fragmentar(texto, tamanho = 1400, sobreposicao = 180) {
  const limpo = texto.replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim()
  if (!limpo) return []
  const out = []; let inicio = 0
  while (inicio < limpo.length) {
    let fim = Math.min(inicio + tamanho, limpo.length)
    if (fim < limpo.length) { const corte = limpo.lastIndexOf('\n', fim); if (corte > inicio + 500) fim = corte }
    out.push(limpo.slice(inicio, fim).trim())
    if (fim >= limpo.length) break
    inicio = Math.max(fim - sobreposicao, inicio + 1)
  }
  return out.filter(Boolean)
}
async function extrairPaginas(nome, mime, bytes) {
  const ext = extensao(nome)
  if (['txt', 'csv', 'json', 'xml'].includes(ext)) return [{ pagina: 1, texto: new TextDecoder('utf-8', { fatal: false }).decode(bytes) }]
  if (ext === 'docx') {
    const mammoth = await import('npm:mammoth@1.10.0')
    const result = await mammoth.extractRawText({ arrayBuffer: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) })
    return [{ pagina: 1, texto: result.value ?? '' }]
  }
  if (ext === 'pdf') {
    const pdfjs = await import('npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs')
    const doc = await pdfjs.getDocument({ data: bytes, useSystemFonts: true, isEvalSupported: false, disableFontFace: true }).promise
    if (doc.numPages > 2000) throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'PDF excede o limite seguro de páginas.')
    const paginas = []
    for (let p = 1; p <= doc.numPages; p++) {
      const page = await doc.getPage(p); const content = await page.getTextContent()
      const texto = content.items.map((item) => typeof item?.str === 'string' ? item.str : '').join(' ').replace(/\s+/g, ' ').trim()
      paginas.push({ pagina: p, texto })
    }
    return paginas
  }
  if (['png', 'jpg', 'jpeg', 'webp'].includes(ext)) return []
  throw new AppError('ARQUIVO_TIPO_NAO_SUPORTADO', 'Formato não suportado.')
}
async function processarDocumento(payload) {
  const idVersao = payload.id_versao_documento ?? payload.entidade_id
  if (!idVersao) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Versão documental não informada.')
  const { data: versao, error: erroVersao } = await sb.from('versoes_documento').select('*').eq('id', idVersao).single()
  if (erroVersao || !versao) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Versão documental não encontrada.')
  const { data: arquivo, error: erroArquivo } = await sb.from('arquivos').select('*').eq('id', versao.id_arquivo).single()
  if (erroArquivo || !arquivo) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Arquivo não encontrado.')
  const { data: cfg } = await sb.from('configuracao_upload').select('tamanho_maximo_processamento_bytes,tamanho_maximo_descompactado_bytes,max_entradas_compactadas,razao_maxima_compactacao').eq('id', true).single()
  const limiteProcessamento = Number(cfg?.tamanho_maximo_processamento_bytes ?? 50331648)
  if (Number(arquivo.tamanho) > limiteProcessamento) {
    await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: 'ARQUIVO_PROCESSAMENTO_MUITO_GRANDE', erro_detalhe: null, resultado: { codigo: 'ARQUIVO_PROCESSAMENTO_MUITO_GRANDE', titulo: 'Processamento automático limitado', mensagem: mensagem('ARQUIVO_PROCESSAMENTO_MUITO_GRANDE'), limite_bytes: limiteProcessamento }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { processamento_limitado: true, limite_bytes: limiteProcessamento }
  }
  await sb.from('processamentos_documento').update({ status: 'processando', iniciado_em: new Date().toISOString(), erro_codigo: null, erro_detalhe: null }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
  const { data: blob, error: erroDownload } = await sb.storage.from(arquivo.bucket).download(arquivo.path)
  if (erroDownload || !blob) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Não foi possível ler o arquivo no armazenamento.')
  if (blob.size > limiteProcessamento) throw new AppError('ARQUIVO_PROCESSAMENTO_MUITO_GRANDE', 'Objeto armazenado excede o limite seguro de processamento.')
  const bytes = new Uint8Array(await blob.arrayBuffer()); const hashCalculado = await sha256Hex(bytes)
  if (hashCalculado.toLowerCase() !== String(arquivo.sha256).toLowerCase()) {
    await sb.from('arquivos').update({ status_seguranca: 'quarentena' }).eq('id', arquivo.id)
    throw new AppError('ARQUIVO_INTEGRIDADE', 'Hash do arquivo divergente.')
  }
  if (!assinaturaValida(arquivo.nome_original, arquivo.mime, bytes)) {
    await sb.from('arquivos').update({ status_seguranca: 'bloqueado' }).eq('id', arquivo.id)
    await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: 'ARQUIVO_BLOQUEADO_SEGURANCA', resultado: { codigo: 'ARQUIVO_BLOQUEADO_SEGURANCA', titulo: 'Arquivo bloqueado', mensagem: mensagem('ARQUIVO_BLOQUEADO_SEGURANCA') }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { bloqueado: true }
  }
  const ext = extensao(arquivo.nome_original)
  if (ext === 'docx' || ext === 'xlsx') {
    try { validarZipSeguro(bytes, cfg) }
    catch (erro) {
      await sb.from('arquivos').update({ status_seguranca: 'bloqueado' }).eq('id', arquivo.id)
      const app = erro instanceof AppError ? erro : new AppError('ARQUIVO_COMPACTADO_INSEGURO', String(erro))
      await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: app.codigo, resultado: { codigo: app.codigo, titulo: 'Arquivo compactado bloqueado', mensagem: mensagem(app.codigo) }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
      return { bloqueado: true, codigo: app.codigo }
    }
  }
  await sb.from('arquivos').update({ status_seguranca: 'aprovado' }).eq('id', arquivo.id)
  const paginas = await extrairPaginas(arquivo.nome_original, arquivo.mime, bytes)
  if (paginas.length === 0 || paginas.every((p) => !p.texto.trim())) {
    await sb.rpc('worker_enfileirar_job', { p_fila: 'ocr', p_id_organizacao: versao.id_organizacao, p_id_contrato: versao.id_contrato, p_entidade_tipo: 'versao_documento', p_entidade_id: idVersao, p_payload: { id_versao_documento: idVersao, entidade_tipo: 'versao_documento', entidade_id: idVersao }, p_chave_idempotencia: `ocr:${idVersao}` })
    await sb.from('processamentos_documento').update({ status: 'pendente', resultado: { codigo: 'OCR_AGUARDANDO', titulo: 'Leitura adicional necessária', mensagem: 'O documento foi validado e seguirá para leitura por OCR.' } }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { ocr: true }
  }
  await sb.from('paginas_documento').delete().eq('id_versao_documento', idVersao); await sb.from('fragmentos_documento').delete().eq('id_versao_documento', idVersao)
  const paginasInsert = []; const fragmentosInsert = []; let indice = 0
  for (const pagina of paginas) {
    paginasInsert.push({ id_organizacao: versao.id_organizacao, id_contrato: versao.id_contrato, id_versao_documento: idVersao, numero_pagina: pagina.pagina, texto_extraido: pagina.texto || null, hash_texto: pagina.texto ? await sha256Hex(new TextEncoder().encode(pagina.texto)) : null, metadados: { origem: 'extracao_segura', idioma: 'pt-BR' } })
    for (const trecho of fragmentar(pagina.texto)) fragmentosInsert.push({ id_organizacao: versao.id_organizacao, id_contrato: versao.id_contrato, id_versao_documento: idVersao, pagina_inicio: pagina.pagina, pagina_fim: pagina.pagina, indice_fragmento: indice++, texto: trecho, metadados: { idioma: 'pt-BR', origem: 'documento' } })
  }
  if (paginasInsert.length) { const { error } = await sb.from('paginas_documento').insert(paginasInsert); if (error) throw error }
  let fragmentos = []
  if (fragmentosInsert.length) {
    const { data, error } = await sb.from('fragmentos_documento').insert(fragmentosInsert).select('id,id_organizacao,id_contrato'); if (error) throw error; fragmentos = data ?? []
    for (const frag of fragmentos) await sb.rpc('worker_enfileirar_job', { p_fila: 'embeddings', p_id_organizacao: frag.id_organizacao, p_id_contrato: frag.id_contrato, p_entidade_tipo: 'fragmento_documento', p_entidade_id: frag.id, p_payload: { entidade_tipo: 'fragmento_documento', entidade_id: frag.id }, p_chave_idempotencia: `embed:fragmento:${frag.id}` })
  }
  await sb.from('processamentos_documento').update({ status: 'concluido', resultado: { codigo: 'DOCUMENTO_PROCESSADO', titulo: 'Documento processado', mensagem: 'O documento foi validado e processado com sucesso.', paginas: paginas.length, fragmentos: fragmentos.length, validacao_seguranca: 'integridade_assinatura_mime_zip' }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
  return { paginas: paginas.length, fragmentos: fragmentos.length }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Este processador aceita somente chamadas internas do ContaOS.' }, { status: 405 })
  const token = req.headers.get('x-contaos-internal-token') ?? ''; const { data: valido } = await sb.rpc('validar_token_interno', { p_token: token })
  if (valido !== true) return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta operação interna não está autorizada.' }, { status: 401 })
  let body = {}; try { body = await req.json() } catch {}
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 3), 1), 10); const resultados = []
  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error } = await sb.rpc('worker_pull_job', { p_fila: 'documents', p_visibility_seconds: 180 })
    if (error) return Response.json({ ok: false, codigo: 'GERAL_ERRO_INESPERADO', titulo: 'Não foi possível processar a fila', mensagem: 'O processamento documental encontrou uma indisponibilidade temporária.' }, { status: 500 })
    if (!job) break
    try {
      const resultado = await processarDocumento(job.payload ?? {}); await sb.rpc('worker_finalizar_job', { p_fila: 'documents', p_msg_id: Number(job.msg_id), p_sucesso: true, p_erro_codigo: null, p_erro_detalhe: null, p_max_tentativas: 5 }); resultados.push({ ok: true, msg_id: job.msg_id, resultado })
    } catch (erro) {
      const app = erro instanceof AppError ? erro : new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', String(erro))
      const deterministico = ['ARQUIVO_INTEGRIDADE','ARQUIVO_BLOQUEADO_SEGURANCA','ARQUIVO_PROCESSAMENTO_MUITO_GRANDE','ARQUIVO_COMPACTADO_INSEGURO','ARQUIVO_TIPO_NAO_SUPORTADO'].includes(app.codigo)
      await sb.rpc('worker_finalizar_job', { p_fila: 'documents', p_msg_id: Number(job.msg_id), p_sucesso: false, p_erro_codigo: app.codigo, p_erro_detalhe: app.message, p_max_tentativas: deterministico ? 1 : 5 }); resultados.push({ ok: false, msg_id: job.msg_id, codigo: app.codigo, titulo: 'Documento não processado', mensagem: mensagem(app.codigo) })
    }
  }
  return Response.json({ ok: true, fila: 'documents', processados: resultados.length, resultados }, { headers: { 'content-type': 'application/json; charset=utf-8' } })
})
