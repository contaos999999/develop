import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import * as XLSX from 'https://cdn.sheetjs.com/xlsx-0.20.3/package/xlsx.mjs'

const URL = Deno.env.get('SUPABASE_URL')!
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } })

class AppError extends Error {
  codigo: string
  constructor(codigo: string, mensagem = 'Não foi possível concluir a importação dos dados financeiros.') {
    super(mensagem)
    this.codigo = codigo
  }
}

const mensagens: Record<string, string> = {
  IMPORTACAO_FINANCEIRA_FALHOU: 'Não foi possível concluir a importação financeira nesta tentativa.',
  ARQUIVO_FINANCEIRO_INTEGRIDADE: 'Não foi possível confirmar a integridade do arquivo financeiro.',
  ARQUIVO_FINANCEIRO_BLOQUEADO: 'O arquivo financeiro foi bloqueado pela validação de segurança.',
  PLANILHA_LIMITE_EXCEDIDO: 'A planilha ultrapassa os limites seguros de processamento deste ambiente.',
  PLANILHA_TIPO_INVALIDO: 'O formato do arquivo financeiro não é aceito para importação.',
}
const mensagem = (codigo: string) => mensagens[codigo] ?? mensagens.IMPORTACAO_FINANCEIRA_FALHOU

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  const hash = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

function extensao(nome: string): string {
  return (String(nome ?? '').split('.').pop() ?? '').toLowerCase()
}

function numeroSeguro(v: unknown, padrao: number, minimo = 1): number {
  const n = Number(v)
  return Number.isFinite(n) && n >= minimo ? Math.floor(n) : padrao
}

function u16(view: DataView, off: number): number { return view.getUint16(off, true) }
function u32(view: DataView, off: number): number { return view.getUint32(off, true) }

function caminhoZipSeguro(nome: string): boolean {
  if (!nome || nome.includes('\0')) return false
  const normalizado = nome.replace(/\\/g, '/')
  if (normalizado.startsWith('/') || /^[a-zA-Z]:/.test(normalizado)) return false
  return !normalizado.split('/').some((p) => p === '..')
}

function localizarEocd(bytes: Uint8Array): number {
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

function validarZipXlsx(bytes: Uint8Array, cfg: any) {
  const maxEntradas = numeroSeguro(cfg?.max_entradas_compactadas, 5000)
  const maxDescompactado = numeroSeguro(cfg?.tamanho_maximo_descompactado_bytes, 104857600)
  const maxRazao = numeroSeguro(cfg?.razao_maxima_compactacao, 200)
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const eocd = localizarEocd(bytes)
  if (eocd < 0) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Estrutura ZIP inválida ou incompleta.')

  const disco = u16(view, eocd + 4)
  const discoCentral = u16(view, eocd + 6)
  const entradasDisco = u16(view, eocd + 8)
  const entradasTotal = u16(view, eocd + 10)
  const tamanhoCentral = u32(view, eocd + 12)
  const offsetCentral = u32(view, eocd + 16)

  if (entradasDisco === 0xffff || entradasTotal === 0xffff || tamanhoCentral === 0xffffffff || offsetCentral === 0xffffffff) {
    throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'ZIP64 não é aceito para importação financeira.')
  }
  if (disco !== 0 || discoCentral !== 0 || entradasDisco !== entradasTotal) {
    throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Arquivos ZIP multidisco não são aceitos.')
  }
  if (entradasTotal < 1 || entradasTotal > maxEntradas) {
    throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de entradas compactadas fora do limite seguro.')
  }
  if (offsetCentral + tamanhoCentral > eocd) {
    throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Diretório central ZIP inconsistente.')
  }

  let pos = offsetCentral
  let totalCompactado = 0
  let totalDescompactado = 0
  const nomes = new Set<string>()

  for (let i = 0; i < entradasTotal; i++) {
    if (pos + 46 > bytes.byteLength || u32(view, pos) !== 0x02014b50) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Entrada ZIP inválida.')
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
    const fim = pos + 46 + tamNome + tamExtra + tamComentario

    if (fim > bytes.byteLength || discoInicio !== 0 || offsetLocal === 0xffffffff || tamCompactado === 0xffffffff || tamDescompactado === 0xffffffff) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Metadados ZIP fora do formato seguro suportado.')
    }
    if ((flags & 0x0001) !== 0) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Planilhas compactadas criptografadas não são aceitas.')
    }
    if (![0, 8].includes(metodo)) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Método de compressão não permitido.')
    }

    const nome = new TextDecoder('utf-8', { fatal: false }).decode(bytes.subarray(pos + 46, pos + 46 + tamNome)).replace(/\\/g, '/')
    if (!caminhoZipSeguro(nome)) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Caminho interno inseguro detectado na planilha.')
    }
    const lower = nome.toLowerCase()
    if (lower.endsWith('/vbaproject.bin') || lower.includes('/activex/') || lower.startsWith('activex/') || lower.includes('/embeddings/') || lower.startsWith('embeddings/')) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Conteúdo ativo ou incorporado não é aceito na planilha.')
    }

    totalCompactado += tamCompactado
    totalDescompactado += tamDescompactado
    if (totalDescompactado > maxDescompactado) {
      throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Conteúdo descompactado acima do limite seguro.')
    }
    if (tamDescompactado > 0 && tamCompactado === 0) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão de compressão inválida.')
    }
    if (tamCompactado > 0 && tamDescompactado / tamCompactado > maxRazao) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão de compressão suspeita detectada.')
    }

    nomes.add(nome)
    pos = fim
  }

  if (pos > offsetCentral + tamanhoCentral) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Diretório central ZIP inválido.')
  if (totalCompactado > 0 && totalDescompactado / totalCompactado > maxRazao) {
    throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão global de compressão suspeita detectada.')
  }
  if (!nomes.has('[Content_Types].xml') || !nomes.has('xl/workbook.xml')) {
    throw new AppError('PLANILHA_TIPO_INVALIDO', 'O arquivo não possui a estrutura esperada de uma planilha XLSX.')
  }
  return { entradas: entradasTotal, totalCompactado, totalDescompactado }
}

function validarCsv(texto: string): string {
  const limpo = texto.replace(/^\uFEFF/, '')
  if (limpo.includes('\0')) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'O CSV contém bytes inválidos.')
  const inicio = limpo.trimStart().slice(0, 128).toLowerCase()
  if (inicio.startsWith('<html') || inicio.startsWith('<!doctype html') || inicio.startsWith('<?xml') || inicio.startsWith('{\\rtf') || inicio.startsWith('%pdf-')) {
    throw new AppError('PLANILHA_TIPO_INVALIDO', 'O conteúdo não corresponde a um arquivo CSV.')
  }
  return limpo
}

function detectarSeparadorCsv(texto: string): string {
  const primeiraLinha = texto.split(/\r?\n/, 1)[0] ?? ''
  const candidatos = [';', ',', '\t', '|']
  let melhor = ';'
  let maior = -1
  for (const sep of candidatos) {
    let contagem = 0
    let emAspas = false
    for (let i = 0; i < primeiraLinha.length; i++) {
      const ch = primeiraLinha[i]
      if (ch === '"') {
        if (emAspas && primeiraLinha[i + 1] === '"') i++
        else emAspas = !emAspas
      } else if (!emAspas && ch === sep) contagem++
    }
    if (contagem > maior) { maior = contagem; melhor = sep }
  }
  if (maior < 1) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Não foi possível identificar as colunas do CSV.')
  return melhor
}

function normalizarCabecalho(v: unknown): string {
  return String(v ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '')
}

function valorBR(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v
  if (v == null || String(v).trim() === '') return null
  const s = String(v).trim().replace(/R\$/gi, '').replace(/\s/g, '')
  const n = s.includes(',') ? Number(s.replace(/\./g, '').replace(',', '.')) : Number(s)
  return Number.isFinite(n) ? n : null
}

function dataISO(v: unknown): string | null {
  if (v instanceof Date && !Number.isNaN(v.getTime())) return v.toISOString().slice(0, 10)
  if (typeof v === 'number') {
    const d = XLSX.SSF.parse_date_code(v)
    if (d) return `${d.y}-${String(d.m).padStart(2, '0')}-${String(d.d).padStart(2, '0')}`
  }
  const s = String(v ?? '').trim()
  let m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
  if (m) return `${m[3]}-${m[2]}-${m[1]}`
  m = s.match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (m) return `${m[1]}-${m[2]}-${m[3]}`
  return null
}

function validarDimensoes(ws: any, maxLinhas: number, maxColunas: number) {
  const ref = ws?.['!fullref'] ?? ws?.['!ref']
  if (!ref) return
  const range = XLSX.utils.decode_range(ref)
  const linhas = range.e.r - range.s.r + 1
  const colunas = range.e.c - range.s.c + 1
  if (linhas > maxLinhas + 1 || colunas > maxColunas) {
    throw new AppError('PLANILHA_LIMITE_EXCEDIDO', `Planilha com ${linhas} linhas e ${colunas} colunas.`)
  }
}

async function processarImportacaoFinanceira(payload: any) {
  const idImportacao = payload.id_importacao ?? payload.entidade_id
  if (!idImportacao) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação não informada.')

  const { data: imp, error: ei } = await sb.from('importacoes_financeiras').select('*').eq('id', idImportacao).single()
  if (ei || !imp) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação não encontrada.')
  if (!imp.id_arquivo) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação sem arquivo de origem.')

  await sb.from('importacoes_financeiras').update({ status: 'processando', iniciado_em: new Date().toISOString(), erro_detalhe: null }).eq('id', idImportacao)

  try {
    const { data: arq, error: ea } = await sb.from('arquivos').select('*').eq('id', imp.id_arquivo).single()
    if (ea || !arq) throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Arquivo financeiro não encontrado.')
    if (arq.id_organizacao !== imp.id_organizacao || arq.id_contrato !== imp.id_contrato) {
      throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Arquivo fora do escopo da importação.')
    }
    if (String(arq.sha256 ?? '').toLowerCase() !== String(imp.hash ?? '').toLowerCase()) {
      throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Hash da importação divergente do arquivo confirmado.')
    }

    const { data: cfg, error: ecfg } = await sb.from('configuracao_upload').select('tamanho_maximo_processamento_bytes,tamanho_maximo_descompactado_bytes,max_entradas_compactadas,razao_maxima_compactacao,max_linhas_planilha,max_colunas_planilha').eq('id', true).single()
    if (ecfg || !cfg) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Configuração de segurança indisponível.')
    const maxProcessamento = numeroSeguro(cfg.tamanho_maximo_processamento_bytes, 50331648)
    const maxLinhas = numeroSeguro(cfg.max_linhas_planilha, 100000)
    const maxColunas = numeroSeguro(cfg.max_colunas_planilha, 200)
    if (Number(arq.tamanho ?? 0) > maxProcessamento) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Arquivo acima do limite de processamento.')

    const ext = extensao(arq.nome_original)
    const mime = String(arq.mime ?? '').toLowerCase()
    const xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    if (ext === 'xlsx' && mime !== xlsxMime) throw new AppError('PLANILHA_TIPO_INVALIDO', 'MIME incompatível com XLSX.')
    if (ext === 'csv' && mime !== 'text/csv') throw new AppError('PLANILHA_TIPO_INVALIDO', 'MIME incompatível com CSV.')
    if (!['xlsx', 'csv'].includes(ext)) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Extensão não permitida para importação financeira.')

    const { data: blob, error: ed } = await sb.storage.from(arq.bucket).download(arq.path)
    if (ed || !blob) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Falha ao baixar arquivo financeiro.')
    const bytes = new Uint8Array(await blob.arrayBuffer())
    if (bytes.byteLength > maxProcessamento || bytes.byteLength !== Number(arq.tamanho ?? bytes.byteLength)) {
      throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Tamanho real divergente ou acima do limite.')
    }
    const hashReal = await sha256Hex(bytes)
    if (hashReal.toLowerCase() !== String(arq.sha256).toLowerCase() || hashReal.toLowerCase() !== String(imp.hash).toLowerCase()) {
      throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Hash real do arquivo divergente.')
    }

    let wb: any
    const opcoesBase: any = {
      cellDates: true,
      dense: true,
      sheetRows: maxLinhas + 2,
      sheets: 0,
      cellFormula: false,
      cellHTML: false,
      cellStyles: false,
      bookDeps: false,
      bookFiles: false,
      bookVBA: false,
      WTF: true,
    }
    if (ext === 'xlsx') {
      if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Assinatura XLSX inválida.')
      validarZipXlsx(bytes, cfg)
      wb = XLSX.read(bytes, { ...opcoesBase, type: 'array' })
    } else {
      const texto = validarCsv(new TextDecoder('utf-8', { fatal: false }).decode(bytes))
      const fs = detectarSeparadorCsv(texto)
      wb = XLSX.read(texto, { ...opcoesBase, type: 'string', raw: true, FS: fs })
    }

    const ws = wb.Sheets[wb.SheetNames[0]]
    if (!ws) throw new AppError('PLANILHA_TIPO_INVALIDO', 'A planilha não contém uma aba válida para importação.')
    validarDimensoes(ws, maxLinhas, maxColunas)

    const raw = XLSX.utils.sheet_to_json<any>(ws, { defval: null, raw: true })
    if (raw.length > maxLinhas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de linhas acima do limite.')

    const transacoes: any[] = []
    let rejeitados = 0
    for (let i = 0; i < raw.length; i++) {
      const original = raw[i]
      const r: Record<string, unknown> = Object.create(null)
      for (const [k, v] of Object.entries(original)) r[normalizarCabecalho(k)] = v

      const data = dataISO(r.data ?? r.data_lancamento ?? r.dt ?? r.data_pagamento)
      const descricao = String(r.descricao ?? r.historico ?? r.historico_lancamento ?? r.memo ?? '').trim()
      const valor = valorBR(r.valor ?? r.valor_pago ?? r.amount ?? r.total)
      if (!data || !descricao || valor == null) { rejeitados++; continue }

      const tipo = String(r.tipo ?? (valor < 0 ? 'saida' : 'entrada')).toLowerCase()
      const canonical = JSON.stringify({ data, descricao, valor, tipo, documento: r.documento ?? r.numero_documento ?? null, fornecedor: r.fornecedor ?? r.favorecido ?? r.beneficiario ?? null, linha: i + 2 })
      transacoes.push({
        id_organizacao: imp.id_organizacao,
        id_contrato: imp.id_contrato,
        id_importacao: imp.id,
        data,
        descricao,
        documento: r.documento ?? r.numero_documento ?? null,
        fornecedor_nome_original: r.fornecedor ?? r.favorecido ?? r.beneficiario ?? null,
        fornecedor_documento_original: r.cnpj ?? r.cpf ?? r.documento_fornecedor ?? null,
        valor,
        tipo,
        hash_origem: await sha256Hex(`${imp.id}|${canonical}`),
        dados_brutos: original,
      })
    }

    if (transacoes.length) {
      const { error: et } = await sb.from('transacoes_financeiras').upsert(transacoes, { onConflict: 'id_contrato,hash_origem', ignoreDuplicates: true })
      if (et) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Falha ao persistir transações.')
    }

    await sb.from('importacoes_financeiras').update({ status: 'concluida', total_registros: raw.length, total_importado: transacoes.length, total_rejeitado: rejeitados, erro_detalhe: null, concluido_em: new Date().toISOString() }).eq('id', imp.id)
    return { registros: raw.length, importados: transacoes.length, rejeitados }
  } catch (e) {
    const app = e instanceof AppError ? e : new AppError('IMPORTACAO_FINANCEIRA_FALHOU')
    await sb.from('importacoes_financeiras').update({ status: 'falhou', erro_detalhe: mensagem(app.codigo), concluido_em: new Date().toISOString() }).eq('id', imp.id)
    throw app
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Este processador aceita somente chamadas internas do ContaOS.' }, { status: 405 })
  }

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: erroToken } = await sb.rpc('validar_token_interno', { p_token: token })
  if (erroToken || valido !== true) {
    return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta operação interna não está autorizada.' }, { status: 401 })
  }

  let body: any = {}
  try { body = await req.json() } catch { body = {} }
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 2), 1), 10)
  const resultados: any[] = []

  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error } = await sb.rpc('worker_pull_job', { p_fila: 'finance_imports', p_visibility_seconds: 180 })
    if (error) {
      return Response.json({ ok: false, codigo: 'IMPORTACAO_FINANCEIRA_FALHOU', titulo: 'Importação temporariamente indisponível', mensagem: 'O processamento financeiro encontrou uma indisponibilidade temporária.' }, { status: 500 })
    }
    if (!job) break

    const msgId = Number(job.msg_id)
    try {
      const resultado = await processarImportacaoFinanceira(job.payload ?? {})
      const { data: finalizacao } = await sb.rpc('worker_finalizar_job', { p_fila: 'finance_imports', p_msg_id: msgId, p_sucesso: true, p_erro_codigo: null, p_erro_detalhe: null, p_max_tentativas: 5 })
      resultados.push({ ok: true, msg_id: msgId, resultado, finalizacao })
    } catch (erro) {
      const app = erro instanceof AppError ? erro : new AppError('IMPORTACAO_FINANCEIRA_FALHOU')
      const { data: finalizacao } = await sb.rpc('worker_finalizar_job', { p_fila: 'finance_imports', p_msg_id: msgId, p_sucesso: false, p_erro_codigo: app.codigo, p_erro_detalhe: mensagem(app.codigo), p_max_tentativas: 5 })
      resultados.push({ ok: false, msg_id: msgId, codigo: app.codigo, titulo: 'Importação não concluída', mensagem: mensagem(app.codigo), orientacao: 'O ContaOS tentará novamente automaticamente.', finalizacao })
    }
  }

  return Response.json({ ok: true, fila: 'finance_imports', processados: resultados.length, resultados }, { headers: { 'content-type': 'application/json; charset=utf-8' } })
})
