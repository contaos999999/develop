import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import * as XLSX from 'npm:xlsx@0.18.5'

const URL = Deno.env.get('SUPABASE_URL')!
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } })

class AppError extends Error {
  codigo: string
  detalheTecnico?: string
  constructor(codigo: string, detalheTecnico?: string) {
    super('Não foi possível concluir a importação dos dados financeiros.')
    this.codigo = codigo
    this.detalheTecnico = detalheTecnico
  }
}

async function sha256Hex(data: string | Uint8Array): Promise<string> {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  const hash = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, '0')).join('')
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

async function processarImportacaoFinanceira(payload: any) {
  const idImportacao = payload.id_importacao ?? payload.entidade_id
  if (!idImportacao) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação não informada.')

  const { data: imp, error: ei } = await sb.from('importacoes_financeiras').select('*').eq('id', idImportacao).single()
  if (ei || !imp) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', ei?.message ?? 'Importação não encontrada.')
  if (!imp.id_arquivo) throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', 'Importação sem arquivo de origem.')

  await sb.from('importacoes_financeiras').update({
    status: 'processando',
    iniciado_em: new Date().toISOString(),
    erro_detalhe: null,
  }).eq('id', idImportacao)

  try {
    const { data: arq, error: ea } = await sb.from('arquivos').select('*').eq('id', imp.id_arquivo).single()
    if (ea || !arq) throw new Error(ea?.message ?? 'Arquivo financeiro não encontrado.')

    const { data: blob, error: ed } = await sb.storage.from(arq.bucket).download(arq.path)
    if (ed || !blob) throw new Error(ed?.message ?? 'Falha ao baixar arquivo financeiro.')

    const wb = XLSX.read(await blob.arrayBuffer(), { type: 'array', cellDates: true })
    const ws = wb.Sheets[wb.SheetNames[0]]
    if (!ws) throw new Error('A planilha não contém uma aba válida para importação.')

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
      if (!data || !descricao || valor == null) {
        rejeitados++
        continue
      }

      const tipo = String(r.tipo ?? (valor < 0 ? 'saida' : 'entrada')).toLowerCase()
      const canonical = JSON.stringify({
        data,
        descricao,
        valor,
        tipo,
        documento: r.documento ?? r.numero_documento ?? null,
        fornecedor: r.fornecedor ?? r.favorecido ?? r.beneficiario ?? null,
        linha: i + 2,
      })

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
      const { error: et } = await sb.from('transacoes_financeiras').upsert(transacoes, {
        onConflict: 'id_contrato,hash_origem',
        ignoreDuplicates: true,
      })
      if (et) throw new Error(et.message)
    }

    await sb.from('importacoes_financeiras').update({
      status: 'concluida',
      total_registros: raw.length,
      total_importado: transacoes.length,
      total_rejeitado: rejeitados,
      concluido_em: new Date().toISOString(),
    }).eq('id', imp.id)

    return { registros: raw.length, importados: transacoes.length, rejeitados }
  } catch (e) {
    await sb.from('importacoes_financeiras').update({
      status: 'falhou',
      erro_detalhe: String(e),
      concluido_em: new Date().toISOString(),
    }).eq('id', imp.id)
    throw new AppError('IMPORTACAO_FINANCEIRA_FALHOU', String(e))
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return Response.json({
      ok: false,
      codigo: 'METODO_INVALIDO',
      titulo: 'Ação não permitida',
      mensagem: 'Este processador aceita somente chamadas internas do ContaOS.',
    }, { status: 405 })
  }

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: erroToken } = await sb.rpc('validar_token_interno', { p_token: token })
  if (erroToken || valido !== true) {
    return Response.json({
      ok: false,
      codigo: 'AUTH_ACESSO_NEGADO',
      titulo: 'Acesso não permitido',
      mensagem: 'Esta operação interna não está autorizada.',
    }, { status: 401 })
  }

  let body: any = {}
  try { body = await req.json() } catch { body = {} }
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 2), 1), 10)
  const resultados: any[] = []

  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error } = await sb.rpc('worker_pull_job', {
      p_fila: 'finance_imports',
      p_visibility_seconds: 180,
    })
    if (error) {
      return Response.json({
        ok: false,
        codigo: 'IMPORTACAO_FINANCEIRA_FALHOU',
        titulo: 'Importação temporariamente indisponível',
        mensagem: 'O processamento financeiro encontrou uma indisponibilidade temporária.',
      }, { status: 500 })
    }
    if (!job) break

    const msgId = Number(job.msg_id)
    try {
      const resultado = await processarImportacaoFinanceira(job.payload ?? {})
      const { data: finalizacao } = await sb.rpc('worker_finalizar_job', {
        p_fila: 'finance_imports',
        p_msg_id: msgId,
        p_sucesso: true,
        p_erro_codigo: null,
        p_erro_detalhe: null,
        p_max_tentativas: 5,
      })
      resultados.push({ ok: true, msg_id: msgId, resultado, finalizacao })
    } catch (erro) {
      const app = erro instanceof AppError ? erro : new AppError('IMPORTACAO_FINANCEIRA_FALHOU', String(erro))
      const { data: finalizacao } = await sb.rpc('worker_finalizar_job', {
        p_fila: 'finance_imports',
        p_msg_id: msgId,
        p_sucesso: false,
        p_erro_codigo: app.codigo,
        p_erro_detalhe: app.detalheTecnico ?? 'Falha interna na importação financeira.',
        p_max_tentativas: 5,
      })
      resultados.push({
        ok: false,
        msg_id: msgId,
        codigo: app.codigo,
        titulo: 'Importação não concluída',
        mensagem: 'Não foi possível concluir a importação financeira nesta tentativa.',
        orientacao: 'O ContaOS tentará novamente automaticamente.',
        finalizacao,
      })
    }
  }

  return Response.json({ ok: true, fila: 'finance_imports', processados: resultados.length, resultados }, {
    headers: { 'content-type': 'application/json; charset=utf-8' },
  })
})
