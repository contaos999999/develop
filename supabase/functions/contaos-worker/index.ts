import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import * as XLSX from 'npm:xlsx@0.18.5'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const MENSAGENS: Record<string, { titulo: string; mensagem: string; orientacao?: string }> = {
  GERAL_ERRO_INESPERADO: {
    titulo: 'Não foi possível concluir',
    mensagem: 'Ocorreu um problema inesperado durante o processamento.',
    orientacao: 'Tente novamente. Se o problema continuar, informe o código exibido ao suporte.',
  },
  DOCUMENTO_PROCESSAMENTO_FALHOU: {
    titulo: 'Não foi possível analisar o documento',
    mensagem: 'O documento foi recebido, mas não conseguimos concluir a leitura automática.',
    orientacao: 'Tente processar novamente ou envie uma versão pesquisável do documento.',
  },
  OCR_NAO_CONFIGURADO: {
    titulo: 'Documento precisa de leitura adicional',
    mensagem: 'Este arquivo parece depender de OCR para ser lido automaticamente.',
    orientacao: 'Envie uma versão pesquisável do PDF ou configure o provedor de OCR do ambiente.',
  },
  ANALISE_FALHOU: {
    titulo: 'A análise não foi concluída',
    mensagem: 'Ocorreu um problema durante a análise automática. Nenhuma decisão foi tomada automaticamente.',
    orientacao: 'Tente executar a análise novamente ou encaminhe para revisão humana.',
  },
  IA_INDISPONIVEL: {
    titulo: 'Assistente temporariamente indisponível',
    mensagem: 'O assistente não conseguiu concluir a consulta neste momento.',
    orientacao: 'Tente novamente mais tarde. As demais funções do ContaOS continuam disponíveis.',
  },
  IMPORTACAO_FINANCEIRA_FALHOU: {
    titulo: 'Importação não concluída',
    mensagem: 'Não foi possível concluir a importação dos dados financeiros.',
    orientacao: 'Confira o arquivo de origem e tente novamente.',
  },
  WEBHOOK_FALHOU: {
    titulo: 'Integração não confirmada',
    mensagem: 'O sistema integrado não confirmou o recebimento da informação.',
    orientacao: 'O ContaOS tentará novamente automaticamente.',
  },
}

class AppError extends Error {
  codigo: string
  detalheTecnico?: string
  constructor(codigo: string, detalheTecnico?: string) {
    super(MENSAGENS[codigo]?.mensagem ?? MENSAGENS.GERAL_ERRO_INESPERADO.mensagem)
    this.codigo = codigo
    this.detalheTecnico = detalheTecnico
  }
}

function erroJson(codigo: string, detalheTecnico?: string) {
  const m = MENSAGENS[codigo] ?? MENSAGENS.GERAL_ERRO_INESPERADO
  return { ok: false, codigo, titulo: m.titulo, mensagem: m.mensagem, orientacao: m.orientacao ?? null, detalhe_tecnico: detalheTecnico ?? null }
}

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  const hash = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function hmacSha256Hex(secret: string, data: string): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data))
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('')
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

function fragmentar(texto: string, tamanho = 1400, sobreposicao = 180): string[] {
  const limpo = texto.replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim()
  if (!limpo) return []
  const out: string[] = []
  let i = 0
  while (i < limpo.length) {
    let fim = Math.min(i + tamanho, limpo.length)
    if (fim < limpo.length) {
      const corte = limpo.lastIndexOf('\n', fim)
      if (corte > i + 500) fim = corte
    }
    out.push(limpo.slice(i, fim).trim())
    if (fim >= limpo.length) break
    i = Math.max(fim - sobreposicao, i + 1)
  }
  return out.filter(Boolean)
}

async function extrairPaginas(nome: string, mime: string | null, bytes: Uint8Array): Promise<Array<{ pagina: number; texto: string }>> {
  const lower = nome.toLowerCase()
  if ((mime ?? '').startsWith('text/') || lower.endsWith('.txt') || lower.endsWith('.csv') || lower.endsWith('.json') || lower.endsWith('.xml')) {
    return [{ pagina: 1, texto: new TextDecoder('utf-8', { fatal: false }).decode(bytes) }]
  }
  if (lower.endsWith('.docx') || mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
    const mammoth = await import('npm:mammoth@1.10.0')
    const result = await mammoth.extractRawText({ arrayBuffer: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) })
    return [{ pagina: 1, texto: result.value ?? '' }]
  }
  if (lower.endsWith('.pdf') || mime === 'application/pdf') {
    try {
      const pdfjs = await import('npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs')
      const doc = await pdfjs.getDocument({ data: bytes, useSystemFonts: true, isEvalSupported: false, disableFontFace: true }).promise
      const paginas: Array<{ pagina: number; texto: string }> = []
      for (let p = 1; p <= doc.numPages; p++) {
        const page = await doc.getPage(p)
        const content = await page.getTextContent()
        const texto = content.items.map((it: any) => typeof it?.str === 'string' ? it.str : '').join(' ').replace(/\s+/g, ' ').trim()
        paginas.push({ pagina: p, texto })
      }
      if (paginas.every((p) => !p.texto.trim())) throw new AppError('OCR_NAO_CONFIGURADO', 'PDF sem camada de texto pesquisável.')
      return paginas
    } catch (e) {
      if (e instanceof AppError) throw e
      throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', `Falha ao extrair PDF: ${String(e)}`)
    }
  }
  if ((mime ?? '').startsWith('image/')) throw new AppError('OCR_NAO_CONFIGURADO', `Imagem ${mime ?? ''} requer OCR.`)
  throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', `Formato não suportado para extração automática: ${mime ?? nome}`)
}

async function processarDocumento(payload: any) {
  const idVersao = payload.id_versao_documento ?? payload.entidade_id
  if (!idVersao) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', 'ID da versão documental ausente.')

  const { data: versao, error: ev } = await sb.from('versoes_documento').select('*').eq('id', idVersao).single()
  if (ev || !versao) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', ev?.message ?? 'Versão documental não encontrada.')
  const { data: arquivo, error: ea } = await sb.from('arquivos').select('*').eq('id', versao.id_arquivo).single()
  if (ea || !arquivo) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', ea?.message ?? 'Arquivo não encontrado.')

  await sb.from('processamentos_documento').update({ status: 'processando', iniciado_em: new Date().toISOString(), tentativas: 1, erro_codigo: null, erro_detalhe: null }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')

  const { data: blob, error: ed } = await sb.storage.from(arquivo.bucket).download(arquivo.path)
  if (ed || !blob) throw new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', ed?.message ?? 'Falha ao baixar o arquivo do Storage.')
  const bytes = new Uint8Array(await blob.arrayBuffer())

  try {
    const paginas = await extrairPaginas(arquivo.nome_original, arquivo.mime, bytes)
    await sb.from('paginas_documento').delete().eq('id_versao_documento', idVersao)
    await sb.from('fragmentos_documento').delete().eq('id_versao_documento', idVersao)

    const paginasInsert = [] as any[]
    for (const p of paginas) {
      paginasInsert.push({
        id_organizacao: versao.id_organizacao,
        id_contrato: versao.id_contrato,
        id_versao_documento: idVersao,
        numero_pagina: p.pagina,
        texto_extraido: p.texto || null,
        hash_texto: p.texto ? await sha256Hex(p.texto) : null,
        metadados: { origem: 'extracao_automatica' },
      })
    }
    if (paginasInsert.length) {
      const { error } = await sb.from('paginas_documento').insert(paginasInsert)
      if (error) throw error
    }

    const fragmentosInsert = [] as any[]
    let idx = 0
    for (const p of paginas) {
      for (const trecho of fragmentar(p.texto)) {
        fragmentosInsert.push({
          id_organizacao: versao.id_organizacao,
          id_contrato: versao.id_contrato,
          id_versao_documento: idVersao,
          pagina_inicio: p.pagina,
          pagina_fim: p.pagina,
          indice_fragmento: idx++,
          texto: trecho,
          metadados: { idioma: 'pt-BR', origem: 'documento' },
        })
      }
    }
    let fragmentos: any[] = []
    if (fragmentosInsert.length) {
      const { data, error } = await sb.from('fragmentos_documento').insert(fragmentosInsert).select('id,id_organizacao,id_contrato')
      if (error) throw error
      fragmentos = data ?? []
      for (const f of fragmentos) {
        await sb.rpc('worker_enfileirar_job', {
          p_fila: 'embeddings', p_id_organizacao: f.id_organizacao, p_id_contrato: f.id_contrato,
          p_entidade_tipo: 'fragmento_documento', p_entidade_id: f.id,
          p_payload: { entidade_tipo: 'fragmento_documento', entidade_id: f.id }, p_chave_idempotencia: `embed:fragmento:${f.id}`,
        })
      }
    }

    await sb.from('processamentos_documento').update({
      status: 'concluido', concluido_em: new Date().toISOString(),
      resultado: { paginas: paginas.length, fragmentos: fragmentos.length, mensagem: 'Documento processado com sucesso.' },
    }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    return { paginas: paginas.length, fragmentos: fragmentos.length }
  } catch (e) {
    const app = e instanceof AppError ? e : new AppError('DOCUMENTO_PROCESSAMENTO_FALHOU', String(e))
    const m = MENSAGENS[app.codigo] ?? MENSAGENS.GERAL_ERRO_INESPERADO
    await sb.from('processamentos_documento').update({
      status: 'falhou', concluido_em: new Date().toISOString(), erro_codigo: app.codigo,
      erro_detalhe: app.detalheTecnico ?? null,
      resultado: { codigo: app.codigo, titulo: m.titulo, mensagem: m.mensagem, orientacao: m.orientacao ?? null },
    }).eq('id_versao_documento', idVersao).eq('etapa', 'documents')
    if (app.codigo === 'OCR_NAO_CONFIGURADO') return { requer_ocr: true, codigo: app.codigo }
    throw app
  }
}

const embeddingModel = new Supabase.ai.Session('gte-small')
async function gerarEmbedding(texto: string): Promise<number[]> {
  const out = await embeddingModel.run(texto.slice(0, 6000), { mean_pool: true, normalize: true })
  return Array.from(out as number[])
}

async function processarEmbedding(payload: any) {
  const tipo = payload.entidade_tipo
  const id = payload.entidade_id
  if (!tipo || !id) throw new AppError('GERAL_ERRO_INESPERADO', 'Entidade para embedding não informada.')
  if (tipo === 'fragmento_documento') {
    const { data, error } = await sb.from('fragmentos_documento').select('id,texto').eq('id', id).single()
    if (error || !data) throw new AppError('GERAL_ERRO_INESPERADO', error?.message ?? 'Fragmento não encontrado.')
    const embedding = await gerarEmbedding(data.texto)
    const { error: eu } = await sb.from('fragmentos_documento').update({ embedding, modelo_embedding: 'Supabase/gte-small-384' }).eq('id', id)
    if (eu) throw new AppError('GERAL_ERRO_INESPERADO', eu.message)
    return { entidade: tipo, id }
  }
  if (tipo === 'precedente') {
    const { data, error } = await sb.from('precedentes').select('id,problema,solucao,desfecho').eq('id', id).single()
    if (error || !data) throw new AppError('GERAL_ERRO_INESPERADO', error?.message ?? 'Precedente não encontrado.')
    const embedding = await gerarEmbedding([data.problema, data.solucao, data.desfecho].filter(Boolean).join('\n'))
    const { error: eu } = await sb.from('precedentes').update({ embedding }).eq('id', id)
    if (eu) throw new AppError('GERAL_ERRO_INESPERADO', eu.message)
    return { entidade: tipo, id }
  }
  if (tipo === 'consulta_semantica') {
    const { data, error } = await sb.from('consultas_semanticas').select('id,texto_consulta').eq('id', id).single()
    if (error || !data) throw new AppError('IA_INDISPONIVEL', error?.message ?? 'Consulta não encontrada.')
    const embedding = await gerarEmbedding(data.texto_consulta)
    const { error: eu } = await sb.from('consultas_semanticas').update({ embedding }).eq('id', id)
    if (eu) throw new AppError('IA_INDISPONIVEL', eu.message)
    return { entidade: tipo, id }
  }
  throw new AppError('GERAL_ERRO_INESPERADO', `Tipo de embedding não suportado: ${tipo}`)
}

async function processarAnalise(payload: any) {
  const idExecucao = payload.id_execucao ?? payload.entidade_id
  const { data: exec, error: ee } = await sb.from('execucoes_analise').select('*').eq('id', idExecucao).single()
  if (ee || !exec) throw new AppError('ANALISE_FALHOU', ee?.message ?? 'Execução não encontrada.')
  await sb.from('execucoes_analise').update({ status: 'processando', iniciada_em: exec.iniciada_em ?? new Date().toISOString(), provedor: 'contaos', modelo: 'motor-deterministico-v1', prompt_versao: 'pt-BR-v1' }).eq('id', idExecucao)

  const { data: requisitos, error: er } = await sb.from('requisitos_competencia').select('*').eq('id_competencia', exec.id_competencia).order('ordem')
  if (er) throw new AppError('ANALISE_FALHOU', er.message)
  let naoConformes = 0
  let inconclusivos = 0

  for (const req of requisitos ?? []) {
    const { data: docs } = await sb.from('documentos_competencia').select('id').eq('id_competencia', exec.id_competencia).eq('id_requisito_competencia', req.id).eq('situacao', 'ativo').limit(1)
    const temDocumento = (docs?.length ?? 0) > 0
    const resultado = req.origem_tipo === 'item_lista' && req.obrigatorio && req.aplicavel && !temDocumento ? 'nao_conforme' : 'inconclusivo'
    if (resultado === 'nao_conforme') naoConformes++; else inconclusivos++
    const justificativa = resultado === 'nao_conforme'
      ? 'Não foi localizada evidência documental vinculada a este requisito obrigatório.'
      : 'O ContaOS localizou o requisito, mas a conclusão exige validação humana com base nas evidências disponíveis.'
    const fundamento = resultado === 'nao_conforme' ? 'Ausência de evidência vinculada no momento da análise.' : 'Análise conservadora: nenhuma conformidade é aprovada automaticamente sem evidência suficiente e revisão humana.'
    const { error } = await sb.from('resultados_requisitos').insert({
      id_organizacao: exec.id_organizacao, id_contrato: exec.id_contrato, id_competencia: exec.id_competencia,
      id_execucao: exec.id, id_requisito: req.id, resultado, confianca: resultado === 'nao_conforme' ? 0.99 : 0.5,
      justificativa, fundamento, metadados: { origem: 'motor_deterministico', idioma: 'pt-BR', requer_revisao_humana: true },
    })
    if (error && !error.message.includes('duplicate key')) throw new AppError('ANALISE_FALHOU', error.message)
  }

  await sb.from('execucoes_analise').update({
    status: 'concluida', concluida_em: new Date().toISOString(),
    metadados: { resumo: { nao_conformes: naoConformes, inconclusivos }, mensagem: 'Análise automática concluída. Os resultados inconclusivos aguardam revisão humana.' },
  }).eq('id', idExecucao)
  await sb.from('competencias').update({ situacao: naoConformes > 0 ? 'pendente_correcao' : 'em_analise', percentual_conformidade: 0 }).eq('id', exec.id_competencia)
  if (exec.iniciada_por) {
    await sb.from('notificacoes').insert({
      id_organizacao: exec.id_organizacao, id_usuario: exec.iniciada_por, evento: 'analise_concluida',
      titulo: 'Análise concluída', mensagem: naoConformes > 0 ? 'A análise terminou e encontrou pontos que precisam de correção ou revisão.' : 'A análise terminou. Revise os itens inconclusivos antes de aprovar a competência.',
      canal: 'in_app', status: 'enviada', entidade_tipo: 'execucao_analise', entidade_id: exec.id, enviada_em: new Date().toISOString(),
    })
  }
  return { nao_conformes: naoConformes, inconclusivos }
}

async function processarConsulta(payload: any) {
  const idConsulta = payload.id_consulta ?? payload.entidade_id
  const { data: consulta, error: ec } = await sb.from('consultas_semanticas').select('*').eq('id', idConsulta).single()
  if (ec || !consulta) throw new AppError('IA_INDISPONIVEL', ec?.message ?? 'Consulta não encontrada.')
  if (!consulta.id_contrato) throw new AppError('IA_INDISPONIVEL', 'Consulta sem contrato associado.')
  await sb.from('consultas_semanticas').update({ status: 'processando' }).eq('id', idConsulta)
  const embedding = await gerarEmbedding(consulta.texto_consulta)
  await sb.from('consultas_semanticas').update({ embedding, modelo: 'Supabase/gte-small-384' }).eq('id', idConsulta)
  const { data: fontes, error: ef } = await sb.rpc('worker_buscar_fragmentos', {
    p_id_organizacao: consulta.id_organizacao, p_id_contrato: consulta.id_contrato, p_embedding: embedding, p_limite: 8,
  })
  if (ef) throw new AppError('IA_INDISPONIVEL', ef.message)
  const trechos = fontes ?? []
  const conteudo = trechos.length
    ? `Encontrei ${trechos.length} trecho(s) relacionado(s) à sua pergunta nos documentos do contrato. Abaixo estão as fontes mais relevantes. Use essas evidências como apoio e valide a conclusão antes de tomar uma decisão.\n\n${trechos.slice(0, 5).map((f: any, i: number) => `${i + 1}. ${String(f.texto ?? '').slice(0, 420)}${String(f.texto ?? '').length > 420 ? '…' : ''}`).join('\n\n')}`
    : 'Não encontrei evidências suficientes nos documentos deste contrato para responder com segurança. Inclua novas fontes ou revise os documentos disponíveis.'

  const { data: retorno, error: er } = await sb.from('retornos_modelo').insert({
    id_organizacao: consulta.id_organizacao, id_contrato: consulta.id_contrato, id_consulta: consulta.id,
    provedor: 'supabase', modelo: 'gte-small-384+retrieval', prompt_versao: 'copiloto-pt-BR-v1',
    resposta: { tipo: 'recuperacao_semantica', conteudo, aviso: 'Resposta baseada apenas em fontes localizadas no contrato. Requer validação humana.' },
    uso_tokens: {}, status: 'concluido', fontes: trechos.map((f: any) => ({ id: f.id, id_versao_documento: f.id_versao_documento, pagina_inicio: f.pagina_inicio, pagina_fim: f.pagina_fim, similaridade: f.similaridade })),
  }).select('id').single()
  if (er || !retorno) throw new AppError('IA_INDISPONIVEL', er?.message ?? 'Falha ao registrar resposta.')
  const { data: msgUsuario } = await sb.from('mensagens_copiloto').select('id_sessao').eq('id_consulta_semantica', idConsulta).eq('papel', 'usuario').order('criado_em', { ascending: false }).limit(1).maybeSingle()
  if (msgUsuario?.id_sessao) {
    const { data: msgAssist } = await sb.from('mensagens_copiloto').insert({
      id_organizacao: consulta.id_organizacao, id_contrato: consulta.id_contrato, id_sessao: msgUsuario.id_sessao,
      papel: 'assistente', conteudo, id_consulta_semantica: consulta.id, id_retorno_modelo: retorno.id,
    }).select('id').single()
    if (msgAssist) {
      for (const f of trechos) {
        await sb.from('fontes_resposta_copiloto').insert({
          id_organizacao: consulta.id_organizacao, id_contrato: consulta.id_contrato, id_mensagem: msgAssist.id,
          fonte_tipo: 'fragmento_documento', fonte_id: f.id, id_versao_documento: f.id_versao_documento,
          pagina: f.pagina_inicio, trecho: String(f.texto ?? '').slice(0, 1200), score: f.similaridade,
          metadados: { pagina_fim: f.pagina_fim, modelo: 'Supabase/gte-small-384' },
        })
      }
    }
  }
  await sb.from('consultas_semanticas').update({ status: 'concluida' }).eq('id', idConsulta)
  return { fontes: trechos.length, resposta: conteudo }
}

async function processarAI(payload: any) {
  const tipo = payload.entidade_tipo
  if (tipo === 'execucao_analise' || payload.id_execucao) return await processarAnalise(payload)
  if (tipo === 'consulta_semantica' || payload.id_consulta) return await processarConsulta(payload)
  throw new AppError('IA_INDISPONIVEL', `Tipo de job de IA não reconhecido: ${tipo ?? 'não informado'}`)
}

async function processarImportacaoFinanceira(payload: any) {
  const idImportacao = payload.id_importacao ?? payload.entidade_id
  const { data: imp, error: ei } = await sb.from('importacoes_financeiras').select('*').eq('id', idImportacao).single()
  if (ei || !imp) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', ei?.message ?? 'Importação não encontrada.')
  if (!imp.id_arquivo) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação sem arquivo de origem.')
  await sb.from('importacoes_financeiras').update({ status: 'processando', iniciado_em: new Date().toISOString(), erro_detalhe: null }).eq('id', idImportacao)
  try {
    const { data: arq, error: ea } = await sb.from('arquivos').select('*').eq('id', imp.id_arquivo).single()
    if (ea || !arq) throw new Error(ea?.message ?? 'Arquivo financeiro não encontrado.')
    const { data: blob, error: ed } = await sb.storage.from(arq.bucket).download(arq.path)
    if (ed || !blob) throw new Error(ed?.message ?? 'Falha ao baixar arquivo financeiro.')
    const wb = XLSX.read(await blob.arrayBuffer(), { type: 'array', cellDates: true })
    const ws = wb.Sheets[wb.SheetNames[0]]
    const raw = XLSX.utils.sheet_to_json<any>(ws, { defval: null, raw: true })
    const transacoes: any[] = []
    let rejeitados = 0
    for (let i = 0; i < raw.length; i++) {
      const original = raw[i]
      const r: Record<string, unknown> = {}
      for (const [k, v] of Object.entries(original)) r[normalizarCabecalho(k)] = v
      const data = dataISO(r.data ?? r.data_lancamento ?? r.dt ?? r.data_pagamento)
      const descricao = String(r.descricao ?? r.historico ?? r.historico_lancamento ?? r.memo ?? '').trim()
      const valor = valorBR(r.valor ?? r.valor_pago ?? r.amount ?? r.total)
      if (!data || !descricao || valor == null) { rejeitados++; continue }
      const tipo = String(r.tipo ?? (valor < 0 ? 'saida' : 'entrada')).toLowerCase()
      const canonical = JSON.stringify({ data, descricao, valor, tipo, documento: r.documento ?? r.numero_documento ?? null, fornecedor: r.fornecedor ?? r.favorecido ?? r.beneficiario ?? null, linha: i + 2 })
      transacoes.push({
        id_organizacao: imp.id_organizacao, id_contrato: imp.id_contrato, id_importacao: imp.id,
        data, descricao, documento: r.documento ?? r.numero_documento ?? null,
        fornecedor_nome_original: r.fornecedor ?? r.favorecido ?? r.beneficiario ?? null,
        fornecedor_documento_original: r.cnpj ?? r.cpf ?? r.documento_fornecedor ?? null,
        valor, tipo, hash_origem: await sha256Hex(`${imp.id}|${canonical}`), dados_brutos: original,
      })
    }
    if (transacoes.length) {
      const { error: et } = await sb.from('transacoes_financeiras').upsert(transacoes, { onConflict: 'id_contrato,hash_origem', ignoreDuplicates: true })
      if (et) throw new Error(et.message)
    }
    await sb.from('importacoes_financeiras').update({ status: 'concluida', total_registros: raw.length, total_importado: transacoes.length, total_rejeitado: rejeitados, concluido_em: new Date().toISOString() }).eq('id', imp.id)
    return { registros: raw.length, importados: transacoes.length, rejeitados }
  } catch (e) {
    await sb.from('importacoes_financeiras').update({ status: 'falhou', erro_detalhe: String(e), concluido_em: new Date().toISOString() }).eq('id', imp.id)
    throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', String(e))
  }
}

async function processarPacoteEvidencias(payload: any) {
  const idPacote = payload.id_pacote ?? payload.entidade_id
  const { data: pacote, error: ep } = await sb.from('pacotes_evidencias').select('*').eq('id', idPacote).single()
  if (ep || !pacote) throw new AppError('GERAL_ERRO_INESPERADO', ep?.message ?? 'Pacote de evidências não encontrado.')
  const manifest: any = {
    versao_manifesto: '1.0', idioma: 'pt-BR', id_pacote: pacote.id, id_organizacao: pacote.id_organizacao,
    id_contrato: pacote.id_contrato, escopo: pacote.escopo, gerado_em: new Date().toISOString(), itens: [],
  }
  const { data: itens } = await sb.from('itens_pacote_evidencias').select('*').eq('id_pacote', pacote.id).order('ordem')
  manifest.itens = itens ?? []
  if (pacote.id_contrato) {
    const { data: aprovacoes } = await sb.from('aprovacoes').select('id,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,criado_em').eq('id_contrato', pacote.id_contrato).order('criado_em')
    const { data: apresentacoes } = await sb.from('apresentacoes_contratante').select('id,id_competencia,numero_rodada,tipo,protocolo,forma_apresentacao,apresentado_em,apresentado_por').eq('id_contrato', pacote.id_contrato).order('apresentado_em')
    manifest.aprovacoes = aprovacoes ?? []
    manifest.apresentacoes = apresentacoes ?? []
  }
  const json = JSON.stringify(manifest, null, 2)
  const bytes = new TextEncoder().encode(json)
  const hash = await sha256Hex(bytes)
  const path = `${pacote.id_organizacao}/pacotes-evidencias/${pacote.id}/manifesto.json`
  const { error: eu } = await sb.storage.from('contaos-documentos').upload(path, bytes, { contentType: 'application/json; charset=utf-8', upsert: true })
  if (eu) throw new AppError('GERAL_ERRO_INESPERADO', eu.message)
  const { data: arq, error: ea } = await sb.from('arquivos').insert({
    id_organizacao: pacote.id_organizacao, id_contrato: pacote.id_contrato, bucket: 'contaos-documentos', path,
    nome_original: `pacote-evidencias-${pacote.id}.json`, mime: 'application/json', tamanho: bytes.byteLength,
    sha256: hash, status_seguranca: 'aprovado', origem: 'pacote_evidencias', criado_por: pacote.criado_por,
  }).select('id').single()
  if (ea || !arq) throw new AppError('GERAL_ERRO_INESPERADO', ea?.message ?? 'Falha ao registrar arquivo do pacote.')
  await sb.from('exportacoes_evidencias').insert({ id_organizacao: pacote.id_organizacao, id_pacote: pacote.id, formato: 'json', id_arquivo: arq.id, hash, tamanho: bytes.byteLength, exportado_por: pacote.criado_por, metadados: { idioma: 'pt-BR', tipo: 'manifesto_auditavel' } })
  await sb.from('pacotes_evidencias').update({ status: 'disponivel', hash, id_arquivo_exportacao: arq.id, congelado_em: new Date().toISOString() }).eq('id', pacote.id)
  return { id_arquivo: arq.id, hash }
}

async function processarIntegracao(payload: any) {
  if (payload.entidade_tipo === 'notificacao' || payload.id_usuario) {
    const idUsuario = payload.id_usuario ?? payload.entidade_id
    const { data: notas } = await sb.from('notificacoes').select('*').eq('id_usuario', idUsuario).eq('status', 'pendente').order('criado_em').limit(20)
    let enviadas = 0
    let falhas = 0
    for (const n of notas ?? []) {
      if (n.canal === 'in_app') {
        await sb.from('notificacoes').update({ status: 'enviada', enviada_em: new Date().toISOString(), erro: null }).eq('id', n.id)
        enviadas++
      } else {
        await sb.from('notificacoes').update({ status: 'falhou', erro: 'O envio por e-mail ainda não está configurado neste ambiente. A notificação permanece disponível dentro do ContaOS.' }).eq('id', n.id)
        falhas++
      }
    }
    return { enviadas, falhas }
  }
  return { mensagem: 'Nenhuma integração pendente para este job.' }
}

async function processarWebhook(payload: any) {
  const idEvento = payload.id_evento_webhook ?? payload.entidade_id
  const { data: cfg, error: ec } = await sb.rpc('worker_obter_webhook', { p_id_evento: idEvento })
  if (ec || !cfg) throw new AppError('WEBHOOK_FALHOU', ec?.message ?? 'Configuração do webhook não encontrada.')
  const body = JSON.stringify({ evento: cfg.evento, dados: cfg.payload, correlation_id: cfg.correlation_id, enviado_em: new Date().toISOString() })
  const assinatura = await hmacSha256Hex(cfg.secret, body)
  let status = 0
  let respostaTexto = ''
  try {
    const res = await fetch(cfg.url, {
      method: 'POST', headers: { 'content-type': 'application/json', 'x-contaos-evento': cfg.evento, 'x-contaos-assinatura': `sha256=${assinatura}`, 'x-contaos-correlation-id': cfg.correlation_id }, body,
    })
    status = res.status
    respostaTexto = (await res.text()).slice(0, 4000)
    const sucesso = res.ok
    await sb.rpc('worker_registrar_entrega_webhook', { p_id_evento: idEvento, p_sucesso: sucesso, p_status_http: status, p_resposta_hash: await sha256Hex(respostaTexto), p_erro: sucesso ? null : `HTTP ${status}` })
    if (!sucesso) throw new AppError('WEBHOOK_FALHOU', `Webhook respondeu HTTP ${status}.`)
    return { status_http: status }
  } catch (e) {
    if (!(e instanceof AppError)) await sb.rpc('worker_registrar_entrega_webhook', { p_id_evento: idEvento, p_sucesso: false, p_status_http: status || null, p_resposta_hash: respostaTexto ? await sha256Hex(respostaTexto) : null, p_erro: String(e) })
    throw e instanceof AppError ? e : new AppError('WEBHOOK_FALHOU', String(e))
  }
}

async function processarOCR(payload: any) {
  const idVersao = payload.id_versao_documento ?? payload.entidade_id
  if (idVersao) {
    const m = MENSAGENS.OCR_NAO_CONFIGURADO
    await sb.from('processamentos_documento').update({ status: 'falhou', erro_codigo: 'OCR_NAO_CONFIGURADO', erro_detalhe: 'Provedor de OCR não configurado no HML.', resultado: { codigo: 'OCR_NAO_CONFIGURADO', titulo: m.titulo, mensagem: m.mensagem, orientacao: m.orientacao }, concluido_em: new Date().toISOString() }).eq('id_versao_documento', idVersao)
  }
  return { codigo: 'OCR_NAO_CONFIGURADO', mensagem: MENSAGENS.OCR_NAO_CONFIGURADO.mensagem }
}

async function executarFila(fila: string, payload: any) {
  switch (fila) {
    case 'documents': return await processarDocumento(payload)
    case 'ocr': return await processarOCR(payload)
    case 'embeddings': return await processarEmbedding(payload)
    case 'ai': return await processarAI(payload)
    case 'finance_imports': return await processarImportacaoFinanceira(payload)
    case 'reports': return await processarPacoteEvidencias(payload)
    case 'integrations': return await processarIntegracao(payload)
    case 'webhooks': return await processarWebhook(payload)
    default: throw new AppError('GERAL_ERRO_INESPERADO', `Fila desconhecida: ${fila}`)
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Use uma solicitação POST para executar o worker.' }, { status: 405 })
  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: et } = await sb.rpc('validar_token_interno', { p_token: token })
  if (et || valido !== true) return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta operação interna não está autorizada.' }, { status: 401 })

  let body: any = {}
  try { body = await req.json() } catch { body = {} }
  const fila = String(body.queue ?? '').trim()
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 3), 1), 10)
  const permitidas = ['documents','ocr','ai','embeddings','finance_imports','reports','integrations','webhooks']
  if (!permitidas.includes(fila)) return Response.json({ ok: false, codigo: 'FILA_INVALIDA', titulo: 'Fila inválida', mensagem: 'A fila informada não é reconhecida pelo ContaOS.' }, { status: 400 })

  const resultados: any[] = []
  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error: ep } = await sb.rpc('worker_pull_job', { p_fila: fila, p_visibility_seconds: 180 })
    if (ep) return Response.json(erroJson('GERAL_ERRO_INESPERADO', ep.message), { status: 500 })
    if (!job) break
    const msgId = Number(job.msg_id)
    try {
      const resultado = await executarFila(fila, job.payload ?? {})
      const { data: fim } = await sb.rpc('worker_finalizar_job', { p_fila: fila, p_msg_id: msgId, p_sucesso: true, p_erro_codigo: null, p_erro_detalhe: null, p_max_tentativas: 5 })
      resultados.push({ msg_id: msgId, ok: true, resultado, finalizacao: fim })
    } catch (e) {
      const app = e instanceof AppError ? e : new AppError('GERAL_ERRO_INESPERADO', String(e))
      const { data: fim } = await sb.rpc('worker_finalizar_job', { p_fila: fila, p_msg_id: msgId, p_sucesso: false, p_erro_codigo: app.codigo, p_erro_detalhe: app.detalheTecnico ?? String(e), p_max_tentativas: 5 })
      resultados.push({ msg_id: msgId, ...erroJson(app.codigo, app.detalheTecnico), finalizacao: fim })
    }
  }
  return Response.json({ ok: true, fila, processados: resultados.length, resultados }, { headers: { 'content-type': 'application/json; charset=utf-8' } })
})
