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
  ARQUIVO_LIMITE_PROCESSAMENTO: 'O arquivo ultrapassa o limite seguro para processamento automático neste ambiente.',
  DOCUMENTO_PROCESSAMENTO_FALHOU: 'Não foi possível concluir a leitura do documento. Tente novamente.',
}
const mensagem = (codigo) => mensagens[codigo] ?? mensagens.DOCUMENTO_PROCESSAMENTO_FALHOU

async function sha256Hex(bytes) {
  const h = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, '0')).join('')
}
function extensao(nome) { return (nome.split('.').pop() ?? '').toLowerCase() }
function numeroSeguro(v, padrao, minimo = 1) {
  const n = Number(v)
  return Number.isFinite(n) && n >= minimo ? Math.floor(n) : padrao
}
function u16(view, off) { return view.getUint16(off, true) }
function u32(view, off) { return view.getUint32(off, true) }
function caminhoZipSeguro(nome) {
  if (!nome || nome.includes('\0')) return false
  const normalizado = nome.replace(/\\/g, '/')
  if (normalizado.startsWith('/') || /^[a-zA-Z]:/.test(normalizado)) return false
  const partes = normalizado.split('/')
  return !partes.some((p) => p === '..')
}
function localizarEocd(bytes) {
  if (bytes.byteLength < 22) return -1
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const inicio = Math.max(0, bytes.byteLength - (22 + 0xffff))
  for (let i = bytes.byteLength - 22; i >= inicio; i--) {
    if (u32(view, i) !== 0x06054b50) continue
    const comentario = u16(view, i + 20)
    if (i + 22 + comentario === bytes.byteLength) return i
  }
  return -1
}
function validarZipOoxml(nomeArquivo, bytes, cfg) {
  const ext = extensao(nomeArquivo)
  if (!['docx', 'xlsx'].includes(ext)) return null

  const maxEntradas = numeroSeguro(cfg?.max_entradas_compactadas, 5000)
  const maxDescompactado = numeroSeguro(cfg?.tamanho_maximo_descompactado_bytes, 104857600)
  const maxRazao = numeroSeguro(cfg?.razao_maxima_compactacao, 200)
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const eocd = localizarEocd(bytes)
  if (eocd < 0) throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Estrutura ZIP inválida ou incompleta.')

  const disco = u16(view, eocd + 4)
  const discoCentral = u16(view, eocd + 6)
  const entradasDisco = u16(view, eocd + 8)
  const entradasTotal = u16(view, eocd + 10)
  const tamanhoCentral = u32(view, eocd + 12)
  const offsetCentral = u32(view, eocd + 16)

  if (entradasDisco === 0xffff || entradasTotal === 0xffff || tamanhoCentral === 0xffffffff || offsetCentral === 0xffffffff) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'ZIP64 não é aceito no processamento documental.')
  }
  if (disco !== 0 || discoCentral !== 0 || entradasDisco !== entradasTotal) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Arquivos ZIP multidisco não são aceitos.')
  }
  if (entradasTotal < 1 || entradasTotal > maxEntradas) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Quantidade de entradas compactadas fora do limite seguro.')
  }
  if (offsetCentral + tamanhoCentral > eocd || offsetCentral < 0 || tamanhoCentral < 0) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Diretório central ZIP inconsistente.')
  }

  let pos = offsetCentral
  let totalCompactado = 0
  let totalDescompactado = 0
  const nomes = new Set()

  for (let i = 0; i < entradasTotal; i++) {
    if (pos + 46 > bytes.byteLength || u32(view, pos) !== 0x02014b50) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Entrada ZIP inválida.')
    }
    const flags = u16(view, pos + 8)
    const metodo = u16(view, pos + 10)
    const tamCompactado = u32(view, pos + 20)
    const tamDescompactado = u32(view, pos + 24)
    const tamNome = u16(view, pos + 28)
    const tamExtra = u16(view, pos + 30)
    const tamComentario = u16(view, pos + 32)
    const discoInicio = u16(view, pos + 34)
    const offsetLocal = u32(view, pos + 42)
    const fimCabecalho = pos + 46 + tamNome + tamExtra + tamComentario

    if (fimCabecalho > bytes.byteLength || discoInicio !== 0 || offsetLocal === 0xffffffff ||
        tamCompactado === 0xffffffff || tamDescompactado === 0xffffffff) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Metadados ZIP fora do formato seguro suportado.')
    }
    if ((flags & 0x0001) !== 0) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Arquivos compactados criptografados não são aceitos.')
    }
    if (![0, 8].includes(metodo)) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Método de compressão não permitido.')
    }

    const nomeBytes = bytes.subarray(pos + 46, pos + 46 + tamNome)
    const nome = new TextDecoder('utf-8', { fatal: false }).decode(nomeBytes).replace(/\\/g, '/')
    if (!caminhoZipSeguro(nome)) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Caminho interno inseguro detectado no arquivo compactado.')
    }

    const nomeLower = nome.toLowerCase()
    if (nomeLower.endsWith('/vbaproject.bin') || nomeLower.includes('/activex/') || nomeLower.startsWith('activex/')) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Conteúdo ativo ou macro não é aceito neste formato.')
    }

    totalCompactado += tamCompactado
    totalDescompactado += tamDescompactado
    if (totalDescompactado > maxDescompactado) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Conteúdo descompactado acima do limite seguro.')
    }
    if (tamDescompactado > 0 && tamCompactado === 0) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Razão de compressão inválida.')
    }
    if (tamCompactado > 0 && tamDescompactado / tamCompactado > maxRazao) {
      throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Razão de compressão suspeita detectada.')
    }

    nomes.add(nome)
    pos = fimCabecalho
  }

  if (pos > offsetCentral + tamanhoCentral) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Diretório central ZIP ultrapassa o tamanho declarado.')
  }
  if (totalCompactado > 0 && totalDescompactado / totalCompactado > maxRazao) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Razão global de compressão suspeita detectada.')
  }

  if (!nomes.has('[Content_Types].xml')) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'Pacote OOXML sem estrutura obrigatória.')
  }
  if (ext === 'docx' && !nomes.has('word/document.xml')) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'O arquivo não possui a estrutura esperada de um DOCX.')
  }
  if (ext === 'xlsx' && !nomes.has('xl/workbook.xml')) {
    throw new AppError('ARQUIVO_BLOQUEADO_SEGURANCA', 'O arquivo não possui a estrutura esperada de um XLSX.')
  }

  return { entradas: entradasTotal, total_compactado: totalCompactado, total_descompactado: totalDescompactado }
}
function assinaturaValida(nome, mime, bytes) {
  const ext = extensao(nome)
  if (bytes.length >= 2 && bytes[0] === 0x4d && bytes[1] === 0x5a) return false
  if (bytes.length >= 4 && bytes[0] === 0x7f && bytes[1] === 0x45 && bytes[2] === 0x4c && bytes[3] === 0x46) return false
  if (ext === 'pdf') return new TextDecoder().decode(bytes.slice(0, 5)) === '%PDF-'
  if (ext === 'docx' || ext === 'xlsx') return bytes[0] === 0x50 && bytes[1] === 0x4b
  if (ext === 'png') return bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47
  if (ext === 'jpg' || ext === 'jpeg') return bytes[0] === 0xff && bytes[1] === 0xd8
  if (ext === 'webp') return new TextDecoder().decode(bytes.slice(0, 4)) === 'RIFF' && new TextDecoder().decode(bytes.slice(8, 12)) === 'WEBP'
  return ['txt', 'csv', 'json', 'xml'].includes(ext) || (mime ?? '').startsWith('text/')
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
  if (['txt', 'csv', 'json', 'xml'].includes(ext) || (mime ?? '').startsWith('text/')) return [{ pagina: 1, texto: new TextDecoder('utf-8', { fatal: false }).decode(bytes) }]
  if (ext === 'docx') {
    const mammoth = await import('npm:mammoth@1.13.0')
    const result = await mammoth.extractRawText({ arrayBuffer: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) })
    return [{ pagina: 1, texto: result.value ?? '' }]
  }
  if (ext === 'pdf') {
    const pdfjs = await import('npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs')
    const doc = await pdfjs.getDocument({ data: bytes, useSystemFonts: true, isEvalSupported: false, disableFontFace: true }).promise
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
  const { data: cfg, error: erroCfg } = await sb.from('configuracao_upload').select('tamanho_maximo_processamento_bytes,tamanho_maximo_descompactado_bytes,max_entradas_compactadas,razao_maxima_compactacao').eq('id', true).single()
  if (erroCfg || !cfg) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Configuração de segurança de arquivos indisponível.')
  const maxProcessamento = numeroSeguro(cfg.tamanho_maximo_processamento_bytes, 50331648)
  if (Number(arquivo.tamanho ?? 0) > maxProcessamento) {
    await sb.from('arquivos').update({ status_seguranca: 'bloqueado' }).eq('id', arquivo.id)
    await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: 'ARQUIVO_LIMITE_PROCESSAMENTO', erro_detalhe: 'Arquivo acima do limite de processamento automático.', resultado: { codigo: 'ARQUIVO_LIMITE_PROCESSAMENTO', titulo: 'Arquivo acima do limite de processamento', mensagem: mensagem('ARQUIVO_LIMITE_PROCESSAMENTO') }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { bloqueado: true, codigo: 'ARQUIVO_LIMITE_PROCESSAMENTO' }
  }
  await sb.from('processamentos_documento').update({ status: 'processando', iniciado_em: new Date().toISOString(), erro_codigo: null, erro_detalhe: null }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
  const { data: blob, error: erroDownload } = await sb.storage.from(arquivo.bucket).download(arquivo.path)
  if (erroDownload || !blob) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'Não foi possível ler o arquivo no armazenamento.')
  const bytes = new Uint8Array(await blob.arrayBuffer())
  if (bytes.byteLength > maxProcessamento || bytes.byteLength !== Number(arquivo.tamanho ?? bytes.byteLength)) {
    await sb.from('arquivos').update({ status_seguranca: 'quarentena' }).eq('id', arquivo.id)
    throw new AppError('ARQUIVO_INTEGRIDADE', 'Tamanho real divergente ou acima do limite de processamento.')
  }
  const hashCalculado = await sha256Hex(bytes)
  if (hashCalculado.toLowerCase() !== String(arquivo.sha256).toLowerCase()) {
    await sb.from('arquivos').update({ status_seguranca: 'quarentena' }).eq('id', arquivo.id)
    throw new AppError('ARQUIVO_INTEGRIDADE', 'Hash do arquivo divergente.')
  }
  if (!assinaturaValida(arquivo.nome_original, arquivo.mime, bytes)) {
    await sb.from('arquivos').update({ status_seguranca: 'bloqueado' }).eq('id', arquivo.id)
    await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: 'ARQUIVO_BLOQUEADO_SEGURANCA', resultado: { codigo: 'ARQUIVO_BLOQUEADO_SEGURANCA', titulo: 'Arquivo bloqueado', mensagem: mensagem('ARQUIVO_BLOQUEADO_SEGURANCA') }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { bloqueado: true }
  }
  let zipInfo = null
  try {
    zipInfo = validarZipOoxml(arquivo.nome_original, bytes, cfg)
  } catch (erro) {
    if (erro instanceof AppError) {
      await sb.from('arquivos').update({ status_seguranca: 'bloqueado' }).eq('id', arquivo.id)
      await sb.from('processamentos_documento').update({ status: 'cancelado', erro_codigo: erro.codigo, erro_detalhe: erro.message, resultado: { codigo: erro.codigo, titulo: 'Arquivo bloqueado', mensagem: mensagem(erro.codigo) }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
      return { bloqueado: true, codigo: erro.codigo }
    }
    throw erro
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
  await sb.from('processamentos_documento').update({ status: 'concluido', resultado: { codigo: 'DOCUMENTO_PROCESSADO', titulo: 'Documento processado', mensagem: 'O documento foi validado e processado com sucesso.', paginas: paginas.length, fragmentos: fragmentos.length, validacao_seguranca: zipInfo ? 'integridade_assinatura_zip_ooxml' : 'integridade_e_assinatura', zip: zipInfo }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
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
      const app = erro instanceof AppError ? erro : new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', String(erro)); await sb.rpc('worker_finalizar_job', { p_fila: 'documents', p_msg_id: Number(job.msg_id), p_sucesso: false, p_erro_codigo: app.codigo, p_erro_detalhe: app.message, p_max_tentativas: 5 }); resultados.push({ ok: false, msg_id: job.msg_id, codigo: app.codigo, titulo: 'Documento não processado', mensagem: mensagem(app.codigo) })
    }
  }
  return Response.json({ ok: true, fila: 'documents', processados: resultados.length, resultados }, { headers: { 'content-type': 'application/json; charset=utf-8' } })
})
