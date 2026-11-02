import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL = Deno.env.get('SUPABASE_URL')!
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } })
const modelo = new Supabase.ai.Session('gte-small')

const LIMITE_JSON = 4 * 1024
const LIMITE_TEXTO = 6_000
const MAX_JOBS_POR_CHAMADA = 3
const VISIBILIDADE_SEGUNDOS = 180

type TipoEntidade = 'fragmento_documento' | 'precedente'

class EmbeddingError extends Error {
  constructor(public codigo: string, mensagem: string) { super(mensagem) }
}

function respostaErro(status: number, codigo: string, titulo: string, mensagem: string) {
  return Response.json({ ok: false, codigo, titulo, mensagem }, {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  })
}

function uuidSeguro(valor: unknown): string | null {
  const texto = String(valor ?? '').trim().toLowerCase()
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(texto) ? texto : null
}

async function lerJsonLimitado(req: Request, limite: number) {
  const informado = Number(req.headers.get('content-length') ?? 0)
  if (Number.isFinite(informado) && informado > limite) throw new EmbeddingError('REQUISICAO_MUITO_GRANDE', 'A solicitação interna ultrapassa o limite permitido.')
  if (!req.body) return {}

  const reader = req.body.getReader()
  const partes: Uint8Array[] = []
  let total = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      if (!value?.length) continue
      total += value.byteLength
      if (total > limite) {
        try { await reader.cancel('payload acima do limite') } catch {}
        throw new EmbeddingError('REQUISICAO_MUITO_GRANDE', 'A solicitação interna ultrapassa o limite permitido.')
      }
      partes.push(value)
    }
  } finally {
    try { reader.releaseLock() } catch {}
  }

  const bytes = new Uint8Array(total)
  let offset = 0
  for (const parte of partes) {
    bytes.set(parte, offset)
    offset += parte.byteLength
  }
  if (!bytes.length) return {}
  try {
    return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes))
  } catch {
    throw new EmbeddingError('DADOS_INVALIDOS', 'Não foi possível interpretar a solicitação interna.')
  }
}

function textoPrecedente(registro: { problema?: unknown; solucao?: unknown; desfecho?: unknown }) {
  return [
    `Problema: ${String(registro.problema ?? '').trim()}`,
    `Solução: ${String(registro.solucao ?? '').trim()}`,
    `Desfecho: ${String(registro.desfecho ?? '').trim()}`,
  ].join('\n').trim()
}

async function gerarEmbedding(texto: string): Promise<number[]> {
  const entrada = texto.replace(/\u0000/g, '').trim().slice(0, LIMITE_TEXTO)
  if (!entrada) throw new EmbeddingError('EMBEDDING_CONTEUDO_VAZIO', 'Não há conteúdo textual suficiente para gerar o vetor semântico.')
  const vetor = Array.from(await modelo.run(entrada, { mean_pool: true, normalize: true }) as number[])
  if (vetor.length !== 384 || vetor.some((valor) => !Number.isFinite(Number(valor)))) {
    throw new EmbeddingError('EMBEDDING_RESPOSTA_INVALIDA', 'O modelo semântico retornou um vetor inválido.')
  }
  return vetor.map(Number)
}

async function processarFragmento(id: string) {
  const { data: fragmento, error } = await sb
    .from('fragmentos_documento')
    .select('id,id_organizacao,id_contrato,texto')
    .eq('id', id)
    .maybeSingle()

  if (error) throw new EmbeddingError('EMBEDDING_FALHOU', error.message)
  if (!fragmento) throw new EmbeddingError('EMBEDDING_ENTIDADE_NAO_ENCONTRADA', 'O fragmento solicitado não foi encontrado.')

  const embedding = await gerarEmbedding(String(fragmento.texto ?? ''))
  const { error: updateError } = await sb
    .from('fragmentos_documento')
    .update({ embedding })
    .eq('id', fragmento.id)
    .eq('id_organizacao', fragmento.id_organizacao)
    .eq('id_contrato', fragmento.id_contrato)

  if (updateError) throw new EmbeddingError('EMBEDDING_FALHOU', updateError.message)
  return { entidade_tipo: 'fragmento_documento', entidade_id: fragmento.id, dimensoes: embedding.length, modelo: 'gte-small' }
}

async function processarPrecedente(id: string) {
  const { data: precedente, error } = await sb
    .from('precedentes')
    .select('id,id_organizacao,id_contrato_origem,problema,solucao,desfecho,status')
    .eq('id', id)
    .maybeSingle()

  if (error) throw new EmbeddingError('EMBEDDING_FALHOU', error.message)
  if (!precedente) throw new EmbeddingError('EMBEDDING_ENTIDADE_NAO_ENCONTRADA', 'O precedente solicitado não foi encontrado.')
  if (precedente.status !== 'ativo') throw new EmbeddingError('EMBEDDING_ENTIDADE_INATIVA', 'O precedente não está ativo para indexação semântica.')

  const embedding = await gerarEmbedding(textoPrecedente(precedente))
  const { error: updateError } = await sb
    .from('precedentes')
    .update({ embedding })
    .eq('id', precedente.id)
    .eq('id_organizacao', precedente.id_organizacao)
    .eq('id_contrato_origem', precedente.id_contrato_origem)

  if (updateError) throw new EmbeddingError('EMBEDDING_FALHOU', updateError.message)
  return { entidade_tipo: 'precedente', entidade_id: precedente.id, dimensoes: embedding.length, modelo: 'gte-small' }
}

async function processarJob(payload: Record<string, unknown>) {
  const tipo = String(payload.entidade_tipo ?? '') as TipoEntidade
  const id = uuidSeguro(payload.entidade_id)
  if (!id) throw new EmbeddingError('DADOS_INVALIDOS', 'O identificador da entidade para indexação é inválido.')

  if (tipo === 'fragmento_documento') return await processarFragmento(id)
  if (tipo === 'precedente') return await processarPrecedente(id)
  throw new EmbeddingError('EMBEDDING_TIPO_NAO_SUPORTADO', 'O tipo de entidade informado não pode ser indexado por este processador.')
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respostaErro(405, 'METODO_INVALIDO', 'Ação não permitida', 'Este processador aceita somente chamadas internas do ContaOS.')
  }

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: erroToken } = await sb.rpc('validar_token_interno', { p_token: token })
  if (erroToken || valido !== true) {
    return respostaErro(401, 'AUTH_ACESSO_NEGADO', 'Acesso não permitido', 'Esta operação interna não está autorizada.')
  }

  let body: Record<string, unknown> = {}
  try {
    body = await lerJsonLimitado(req, LIMITE_JSON) as Record<string, unknown>
  } catch (e) {
    const erro = e instanceof EmbeddingError ? e : new EmbeddingError('DADOS_INVALIDOS', 'Não foi possível interpretar a solicitação interna.')
    return respostaErro(erro.codigo === 'REQUISICAO_MUITO_GRANDE' ? 413 : 400, erro.codigo, 'Solicitação inválida', erro.message)
  }

  const maxJobs = Math.min(Math.max(Math.trunc(Number(body.max_jobs ?? 2)) || 2, 1), MAX_JOBS_POR_CHAMADA)
  const resultados: Array<Record<string, unknown>> = []

  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error: pullError } = await sb.rpc('worker_pull_job', {
      p_fila: 'embeddings',
      p_visibility_seconds: VISIBILIDADE_SEGUNDOS,
    })

    if (pullError) {
      return respostaErro(500, 'EMBEDDING_FILA_INDISPONIVEL', 'Indexação temporariamente indisponível', 'O ContaOS não conseguiu consultar a fila semântica nesta tentativa.')
    }
    if (!job) break

    const msgId = Number(job.msg_id)
    try {
      const resultado = await processarJob((job.payload ?? {}) as Record<string, unknown>)
      await sb.rpc('worker_finalizar_job', {
        p_fila: 'embeddings',
        p_msg_id: msgId,
        p_sucesso: true,
        p_erro_codigo: null,
        p_erro_detalhe: null,
        p_max_tentativas: 5,
      })
      resultados.push({ ok: true, msg_id: msgId, ...resultado })
    } catch (e) {
      const erro = e instanceof EmbeddingError ? e : new EmbeddingError('EMBEDDING_FALHOU', 'Falha inesperada ao gerar o vetor semântico.')
      await sb.rpc('worker_finalizar_job', {
        p_fila: 'embeddings',
        p_msg_id: msgId,
        p_sucesso: false,
        p_erro_codigo: erro.codigo,
        p_erro_detalhe: erro.message.slice(0, 500),
        p_max_tentativas: 5,
      })
      resultados.push({ ok: false, msg_id: msgId, codigo: erro.codigo, mensagem: 'A indexação semântica não foi concluída nesta tentativa.' })
    }
  }

  return Response.json({
    ok: true,
    fila: 'embeddings',
    modelo: 'gte-small',
    dimensoes: 384,
    processados: resultados.length,
    resultados,
  }, {
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  })
})
