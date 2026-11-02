import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import { ZipReader, Uint8ArrayReader, TextWriter } from 'npm:@zip.js/zip.js@2.24.0'
import { XMLParser } from 'npm:fast-xml-parser@5.11.2'

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
    if ((flags & 0x0001) !== 0) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Planilhas criptografadas não são aceitas.')
    if (![0, 8].includes(metodo)) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Método de compressão não permitido.')

    const nome = new TextDecoder('utf-8', { fatal: false }).decode(bytes.subarray(pos + 46, pos + 46 + tamNome)).replace(/\\/g, '/')
    if (!caminhoZipSeguro(nome)) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Caminho interno inseguro detectado na planilha.')
    const lower = nome.toLowerCase()
    if (lower.endsWith('/vbaproject.bin') || lower.includes('/activex/') || lower.startsWith('activex/') || lower.includes('/embeddings/') || lower.startsWith('embeddings/') || lower.includes('/oleobjects/') || lower.startsWith('oleobjects/') || lower.includes('/externallinks/') || lower.startsWith('externallinks/') || lower.endsWith('/connections.xml')) {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Conteúdo ativo, incorporado ou externo não é aceito na planilha.')
    }

    totalCompactado += tamCompactado
    totalDescompactado += tamDescompactado
    if (totalDescompactado > maxDescompactado) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Conteúdo descompactado acima do limite seguro.')
    if (tamDescompactado > 0 && tamCompactado === 0) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão de compressão inválida.')
    if (tamCompactado > 0 && tamDescompactado / tamCompactado > maxRazao) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão de compressão suspeita detectada.')

    nomes.add(nome)
    pos = fim
  }

  if (pos > offsetCentral + tamanhoCentral) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Diretório central ZIP inválido.')
  if (totalCompactado > 0 && totalDescompactado / totalCompactado > maxRazao) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Razão global de compressão suspeita detectada.')
  if (!nomes.has('[Content_Types].xml') || !nomes.has('xl/workbook.xml') || !nomes.has('xl/_rels/workbook.xml.rels')) {
    throw new AppError('PLANILHA_TIPO_INVALIDO', 'O arquivo não possui a estrutura esperada de uma planilha XLSX.')
  }
  return { entradas: entradasTotal, totalCompactado, totalDescompactado, nomes }
}

function validarXmlSeguro(xml: string, maxChars = 20_000_000): string {
  if (xml.length > maxChars) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'XML interno acima do limite seguro.')
  const inicio = xml.slice(0, 4096).toUpperCase()
  if (inicio.includes('<!DOCTYPE') || inicio.includes('<!ENTITY')) {
    throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'DOCTYPE e entidades XML não são aceitos.')
  }
  return xml
}

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  parseTagValue: false,
  parseAttributeValue: false,
  processEntities: false,
  trimValues: false,
  allowBooleanAttributes: false,
  maxNestedTags: 128,
})

function arr<T>(v: T | T[] | null | undefined): T[] {
  if (v == null) return []
  return Array.isArray(v) ? v : [v]
}

function textoNode(v: any): string {
  if (v == null) return ''
  if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') return String(v)
  if (Array.isArray(v)) return v.map(textoNode).join('')
  if (typeof v === 'object') {
    if (v['#text'] != null) return textoNode(v['#text'])
    if (v.t != null) return textoNode(v.t)
    if (v.r != null) return arr(v.r).map((x: any) => textoNode(x?.t ?? x)).join('')
  }
  return ''
}

function colunaPorReferencia(ref: string): number {
  const m = String(ref ?? '').match(/^([A-Z]+)\d+$/i)
  if (!m) return -1
  let n = 0
  for (const ch of m[1].toUpperCase()) n = n * 26 + ch.charCodeAt(0) - 64
  return n - 1
}

function caminhoAlvoXlsx(target: string): string {
  let p = String(target ?? '').replace(/\\/g, '/').replace(/^\/+/, '')
  if (!p.startsWith('xl/')) p = `xl/${p}`
  const partes = p.split('/')
  const normalizadas: string[] = []
  for (const parte of partes) {
    if (!parte || parte === '.') continue
    if (parte === '..') {
      if (normalizadas.length <= 1) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Relacionamento XLSX fora do pacote permitido.')
      normalizadas.pop()
    } else normalizadas.push(parte)
  }
  p = normalizadas.join('/')
  if (!p.startsWith('xl/worksheets/')) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'A primeira planilha aponta para um recurso inesperado.')
  return p
}

function excelSerialParaISO(v: number): string | null {
  if (!Number.isFinite(v) || v < 1 || v > 2958465) return null
  const dias = Math.floor(v)
  const ms = Date.UTC(1899, 11, 30) + dias * 86400000
  const d = new Date(ms)
  if (Number.isNaN(d.getTime())) return null
  return d.toISOString().slice(0, 10)
}

function dataISO(v: unknown): string | null {
  if (v instanceof Date && !Number.isNaN(v.getTime())) return v.toISOString().slice(0, 10)
  if (typeof v === 'number') return excelSerialParaISO(v)
  const s = String(v ?? '').trim()
  let m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/)
  if (m) return `${m[3]}-${m[2]}-${m[1]}`
  m = s.match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (m) return `${m[1]}-${m[2]}-${m[3]}`
  return null
}

async function lerXlsxSeguro(bytes: Uint8Array, cfg: any, maxLinhas: number, maxColunas: number): Promise<Record<string, unknown>[]> {
  validarZipXlsx(bytes, cfg)
  const reader = new ZipReader(new Uint8ArrayReader(bytes))
  try {
    const entries = await reader.getEntries()
    const mapa = new Map<string, any>()
    for (const entry of entries) {
      const nome = String(entry.filename ?? '').replace(/\\/g, '/')
      if (!caminhoZipSeguro(nome)) throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Caminho ZIP inseguro.')
      mapa.set(nome, entry)
    }

    const lerXml = async (nome: string, maxChars = 20_000_000): Promise<string> => {
      const entry = mapa.get(nome)
      if (!entry || entry.directory) throw new AppError('PLANILHA_TIPO_INVALIDO', `Componente obrigatório ausente: ${nome}`)
      const texto = await entry.getData(new TextWriter())
      return validarXmlSeguro(String(texto ?? ''), maxChars)
    }

    const workbook = xmlParser.parse(await lerXml('xl/workbook.xml', 2_000_000))
    const sheets = arr(workbook?.workbook?.sheets?.sheet)
    if (!sheets.length) throw new AppError('PLANILHA_TIPO_INVALIDO', 'A planilha não possui aba disponível.')
    const primeira = sheets[0] as any
    const rid = primeira?.['@_r:id'] ?? primeira?.['@_id']
    if (!rid) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Relacionamento da primeira aba ausente.')

    const rels = xmlParser.parse(await lerXml('xl/_rels/workbook.xml.rels', 2_000_000))
    const relationships = arr(rels?.Relationships?.Relationship)
    const rel = relationships.find((r: any) => String(r?.['@_Id'] ?? '') === String(rid)) as any
    if (!rel || String(rel?.['@_TargetMode'] ?? '').toLowerCase() === 'external') {
      throw new AppError('ARQUIVO_FINANCEIRO_BLOQUEADO', 'Relacionamento externo ou inválido na planilha.')
    }
    const sheetPath = caminhoAlvoXlsx(String(rel?.['@_Target'] ?? ''))

    let sharedStrings: string[] = []
    if (mapa.has('xl/sharedStrings.xml')) {
      const shared = xmlParser.parse(await lerXml('xl/sharedStrings.xml', 20_000_000))
      sharedStrings = arr(shared?.sst?.si).map((si: any) => textoNode(si))
      if (sharedStrings.length > maxLinhas * Math.max(2, maxColunas)) {
        throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Tabela de textos compartilhados acima do limite seguro.')
      }
    }

    const sheet = xmlParser.parse(await lerXml(sheetPath, 40_000_000))
    const rows = arr(sheet?.worksheet?.sheetData?.row)
    if (rows.length > maxLinhas + 1) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de linhas acima do limite.')
    if (!rows.length) return []

    const converterCelula = (c: any): unknown => {
      const tipo = String(c?.['@_t'] ?? '')
      if (tipo === 'inlineStr') return textoNode(c?.is)
      const bruto = c?.v
      if (bruto == null) return null
      const s = textoNode(bruto)
      if (tipo === 's') {
        const idx = Number(s)
        return Number.isInteger(idx) && idx >= 0 && idx < sharedStrings.length ? sharedStrings[idx] : null
      }
      if (tipo === 'str') return s
      if (tipo === 'b') return s === '1'
      if (tipo === 'e') return null
      const n = Number(s)
      return s !== '' && Number.isFinite(n) ? n : s
    }

    const linhaParaMapa = (row: any): Map<number, unknown> => {
      const m = new Map<number, unknown>()
      for (const c of arr(row?.c)) {
        const col = colunaPorReferencia(String((c as any)?.['@_r'] ?? ''))
        if (col < 0 || col >= maxColunas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de colunas acima do limite.')
        m.set(col, converterCelula(c))
      }
      return m
    }

    const headerMap = linhaParaMapa(rows[0])
    if (!headerMap.size) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Cabeçalho da planilha vazio.')
    const maxHeaderCol = Math.max(...headerMap.keys())
    if (maxHeaderCol + 1 > maxColunas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de colunas acima do limite.')

    const cabecalhos: string[] = []
    const usados = new Map<string, number>()
    for (let i = 0; i <= maxHeaderCol; i++) {
      let nome = String(headerMap.get(i) ?? '').trim() || `coluna_${i + 1}`
      const base = nome
      const n = (usados.get(base) ?? 0) + 1
      usados.set(base, n)
      if (n > 1) nome = `${base}_${n}`
      cabecalhos[i] = nome
    }

    const out: Record<string, unknown>[] = []
    for (let r = 1; r < rows.length; r++) {
      const mapaLinha = linhaParaMapa(rows[r])
      const obj: Record<string, unknown> = Object.create(null)
      let possuiValor = false
      for (let c = 0; c < cabecalhos.length; c++) {
        const valor = mapaLinha.get(c) ?? null
        if (valor !== null && String(valor).trim() !== '') possuiValor = true
        obj[cabecalhos[c]] = valor
      }
      if (possuiValor) out.push(obj)
      if (out.length > maxLinhas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de registros acima do limite.')
    }
    return out
  } finally {
    await reader.close()
  }
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

function parseCsvSeguro(texto: string, sep: string, maxLinhas: number, maxColunas: number): Record<string, unknown>[] {
  const linhas: string[][] = []
  let linha: string[] = []
  let campo = ''
  let aspas = false
  for (let i = 0; i <= texto.length; i++) {
    const ch = i < texto.length ? texto[i] : '\n'
    if (aspas) {
      if (ch === '"') {
        if (texto[i + 1] === '"') { campo += '"'; i++ }
        else aspas = false
      } else campo += ch
      continue
    }
    if (ch === '"') { aspas = true; continue }
    if (ch === sep) {
      linha.push(campo); campo = ''
      if (linha.length > maxColunas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de colunas acima do limite.')
      continue
    }
    if (ch === '\r' && texto[i + 1] === '\n') continue
    if (ch === '\n' || ch === '\r') {
      linha.push(campo); campo = ''
      if (linha.some((x) => x !== '')) linhas.push(linha)
      linha = []
      if (linhas.length > maxLinhas + 1) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de linhas acima do limite.')
      continue
    }
    campo += ch
  }
  if (aspas) throw new AppError('PLANILHA_TIPO_INVALIDO', 'CSV contém aspas não encerradas.')
  if (!linhas.length) return []

  const usados = new Map<string, number>()
  const cabecalhos = linhas[0].map((x, i) => {
    let nome = String(x ?? '').trim() || `coluna_${i + 1}`
    const base = nome
    const n = (usados.get(base) ?? 0) + 1
    usados.set(base, n)
    if (n > 1) nome = `${base}_${n}`
    return nome
  })
  if (cabecalhos.length > maxColunas) throw new AppError('PLANILHA_LIMITE_EXCEDIDO', 'Quantidade de colunas acima do limite.')

  return linhas.slice(1).map((vals) => {
    const obj: Record<string, unknown> = Object.create(null)
    for (let i = 0; i < cabecalhos.length; i++) obj[cabecalhos[i]] = vals[i] ?? null
    return obj
  })
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
    if (arq.id_organizacao !== imp.id_organizacao || arq.id_contrato !== imp.id_contrato) throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Arquivo fora do escopo da importação.')
    if (String(arq.sha256 ?? '').toLowerCase() !== String(imp.hash ?? '').toLowerCase()) throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Hash da importação divergente do arquivo confirmado.')

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
    if (bytes.byteLength > maxProcessamento || bytes.byteLength !== Number(arq.tamanho ?? bytes.byteLength)) throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Tamanho real divergente ou acima do limite.')
    const hashReal = await sha256Hex(bytes)
    if (hashReal.toLowerCase() !== String(arq.sha256).toLowerCase() || hashReal.toLowerCase() !== String(imp.hash).toLowerCase()) throw new AppError('ARQUIVO_FINANCEIRO_INTEGRIDADE', 'Hash real do arquivo divergente.')

    let raw: Record<string, unknown>[]
    if (ext === 'xlsx') {
      if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) throw new AppError('PLANILHA_TIPO_INVALIDO', 'Assinatura XLSX inválida.')
      raw = await lerXlsxSeguro(bytes, cfg, maxLinhas, maxColunas)
    } else {
      const texto = validarCsv(new TextDecoder('utf-8', { fatal: false }).decode(bytes))
      raw = parseCsvSeguro(texto, detectarSeparadorCsv(texto), maxLinhas, maxColunas)
    }

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
  if (req.method !== 'POST') return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Este processador aceita somente chamadas internas do ContaOS.' }, { status: 405 })

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: erroToken } = await sb.rpc('validar_token_interno', { p_token: token })
  if (erroToken || valido !== true) return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta operação interna não está autorizada.' }, { status: 401 })

  let body: any = {}
  try { body = await req.json() } catch { body = {} }
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 2), 1), 10)
  const resultados: any[] = []

  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error } = await sb.rpc('worker_pull_job', { p_fila: 'finance_imports', p_visibility_seconds: 180 })
    if (error) return Response.json({ ok: false, codigo: 'IMPORTACAO_FINANCEIRA_FALHOU', titulo: 'Importação temporariamente indisponível', mensagem: 'O processamento financeiro encontrou uma indisponibilidade temporária.' }, { status: 500 })
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
