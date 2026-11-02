import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import ipaddr from 'npm:ipaddr.js@2.5.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const WEBHOOK_TIMEOUT_MS = 10_000
const DNS_TIMEOUT_MS = 2_500
const MAX_RESPONSE_BYTES = 4_000

type CodigoWebhook =
  | 'WEBHOOK_DESTINO_BLOQUEADO'
  | 'WEBHOOK_TIMEOUT'
  | 'WEBHOOK_FALHOU'
  | 'WEBHOOK_CONFIGURACAO_INVALIDA'

class WebhookError extends Error {
  codigo: CodigoWebhook
  statusHttp: number | null

  constructor(codigo: CodigoWebhook, detalhe: string, statusHttp: number | null = null) {
    super(detalhe)
    this.codigo = codigo
    this.statusHttp = statusHttp
  }
}

function respostaErro(status: number, codigo: string, titulo: string, mensagem: string) {
  return Response.json({ ok: false, codigo, titulo, mensagem }, { status })
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

function hostSemColchetes(hostname: string): string {
  return hostname.startsWith('[') && hostname.endsWith(']') ? hostname.slice(1, -1) : hostname
}

function ipEhPublico(ip: string): boolean {
  try {
    if (!ipaddr.isValid(ip)) return false
    const endereco = ipaddr.process(ip)
    return endereco.range() === 'unicast'
  } catch {
    return false
  }
}

function hostLocalOuEspecial(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/\.$/, '')
  return host === 'localhost'
    || host.endsWith('.localhost')
    || host.endsWith('.local')
    || host.endsWith('.internal')
    || host === 'metadata.google.internal'
    || host === 'metadata.google'
}

async function resolverIpsPublicos(hostname: string): Promise<string[]> {
  const host = hostSemColchetes(hostname)
  if (ipaddr.isValid(host)) {
    if (!ipEhPublico(host)) throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino de webhook aponta para endereço IP não público.')
    return [host]
  }

  const resolver = async (tipo: 'A' | 'AAAA') => {
    try {
      return await Deno.resolveDns(host, tipo, { signal: AbortSignal.timeout(DNS_TIMEOUT_MS) })
    } catch {
      return [] as string[]
    }
  }

  const [ipv4, ipv6] = await Promise.all([resolver('A'), resolver('AAAA')])
  const ips = [...new Set([...ipv4, ...ipv6])]
  if (!ips.length) throw new WebhookError('WEBHOOK_CONFIGURACAO_INVALIDA', 'Não foi possível resolver o endereço do webhook.')
  if (ips.some((ip) => !ipEhPublico(ip))) {
    throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino de webhook resolve para rede privada, local, reservada ou não roteável publicamente.')
  }
  return ips.sort()
}

async function validarDestinoWebhook(valor: unknown): Promise<URL> {
  let url: URL
  try {
    url = new URL(String(valor ?? ''))
  } catch {
    throw new WebhookError('WEBHOOK_CONFIGURACAO_INVALIDA', 'URL de webhook inválida.')
  }

  if (url.protocol !== 'https:') throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Webhook exige HTTPS.')
  if (url.username || url.password) throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Credenciais embutidas na URL do webhook não são permitidas.')
  if (!url.hostname || hostLocalOuEspecial(url.hostname)) {
    throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino local ou interno não é permitido para webhook.')
  }

  await resolverIpsPublicos(url.hostname)
  await resolverIpsPublicos(url.hostname)
  return url
}

async function lerRespostaLimitada(res: Response): Promise<string> {
  if (!res.body) return ''
  const reader = res.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0

  try {
    while (total < MAX_RESPONSE_BYTES) {
      const { value, done } = await reader.read()
      if (done) break
      if (!value?.length) continue
      const restante = MAX_RESPONSE_BYTES - total
      const parte = value.length > restante ? value.slice(0, restante) : value
      chunks.push(parte)
      total += parte.length
      if (value.length > restante || total >= MAX_RESPONSE_BYTES) {
        await reader.cancel('Limite de resposta do webhook atingido.')
        break
      }
    }
  } finally {
    try { reader.releaseLock() } catch { /* noop */ }
  }

  const bytes = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.length
  }
  return new TextDecoder('utf-8', { fatal: false }).decode(bytes)
}

async function registrarFalha(idEvento: string, erro: WebhookError, respostaTexto = '') {
  await sb.rpc('worker_registrar_entrega_webhook', {
    p_id_evento: idEvento,
    p_sucesso: false,
    p_status_http: erro.statusHttp,
    p_resposta_hash: respostaTexto ? await sha256Hex(respostaTexto) : null,
    p_erro: `${erro.codigo}: ${erro.message}`.slice(0, 500),
  })
}

function erroEhTimeout(e: unknown): boolean {
  if (!e || typeof e !== 'object') return false
  const nome = String((e as { name?: unknown }).name ?? '')
  return nome === 'TimeoutError' || nome === 'AbortError'
}

async function processarWebhook(payload: any) {
  const idEvento = String(payload?.id_evento_webhook ?? payload?.entidade_id ?? '')
  if (!idEvento) throw new WebhookError('WEBHOOK_CONFIGURACAO_INVALIDA', 'Evento de webhook não informado.')

  const { data: cfg, error: ec } = await sb.rpc('worker_obter_webhook', { p_id_evento: idEvento })
  if (ec || !cfg) throw new WebhookError('WEBHOOK_CONFIGURACAO_INVALIDA', ec?.message ?? 'Configuração do webhook não encontrada.')

  let url: URL
  try {
    url = await validarDestinoWebhook(cfg.url)
  } catch (e) {
    const erro = e instanceof WebhookError ? e : new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino de webhook rejeitado pela validação de segurança.')
    await registrarFalha(idEvento, erro)
    throw erro
  }

  const timestamp = new Date().toISOString()
  const deliveryId = idEvento
  const body = JSON.stringify({
    delivery_id: deliveryId,
    evento: cfg.evento,
    dados: cfg.payload,
    correlation_id: cfg.correlation_id,
    enviado_em: timestamp,
  })
  const assinaturaBase = `${timestamp}.${deliveryId}.${body}`
  const assinatura = await hmacSha256Hex(cfg.secret, assinaturaBase)
  let respostaTexto = ''

  try {
    const res = await fetch(url, {
      method: 'POST',
      redirect: 'manual',
      signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS),
      headers: {
        'content-type': 'application/json',
        'x-contaos-evento': String(cfg.evento ?? ''),
        'x-contaos-assinatura': `v1=${assinatura}`,
        'x-contaos-signature-version': 'v1',
        'x-contaos-timestamp': timestamp,
        'x-contaos-delivery-id': deliveryId,
        'x-contaos-correlation-id': String(cfg.correlation_id ?? ''),
      },
      body,
    })

    respostaTexto = await lerRespostaLimitada(res)
    const respostaHash = await sha256Hex(respostaTexto)

    if (res.status >= 300 && res.status < 400) {
      const erro = new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Redirecionamentos HTTP não são permitidos para webhooks.', res.status)
      await registrarFalha(idEvento, erro, respostaTexto)
      throw erro
    }

    const sucesso = res.ok
    await sb.rpc('worker_registrar_entrega_webhook', {
      p_id_evento: idEvento,
      p_sucesso: sucesso,
      p_status_http: res.status,
      p_resposta_hash: respostaHash,
      p_erro: sucesso ? null : `HTTP ${res.status}`,
    })

    if (!sucesso) throw new WebhookError('WEBHOOK_FALHOU', `Webhook respondeu HTTP ${res.status}.`, res.status)
    return { status_http: res.status, delivery_id: deliveryId, enviado_em: timestamp }
  } catch (e) {
    if (e instanceof WebhookError) throw e
    const timeout = erroEhTimeout(e)
    const erro = new WebhookError(timeout ? 'WEBHOOK_TIMEOUT' : 'WEBHOOK_FALHOU', timeout ? 'Tempo limite de 10 segundos excedido na integração.' : 'Falha de rede ao entregar webhook.')
    await registrarFalha(idEvento, erro, respostaTexto)
    throw erro
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respostaErro(405, 'METODO_INVALIDO', 'Ação não permitida', 'Este processador aceita somente chamadas internas do ContaOS.')
  }

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error: et } = await sb.rpc('validar_token_interno', { p_token: token })
  if (et || valido !== true) {
    return respostaErro(401, 'AUTH_ACESSO_NEGADO', 'Acesso não permitido', 'Esta operação interna não está autorizada.')
  }

  let body: any = {}
  try { body = await req.json() } catch { body = {} }
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 3), 1), 10)
  const resultados: any[] = []

  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error: ep } = await sb.rpc('worker_pull_job', { p_fila: 'webhooks', p_visibility_seconds: 180 })
    if (ep) {
      return respostaErro(500, 'GERAL_ERRO_INESPERADO', 'Não foi possível concluir', 'O processador de integrações encontrou um problema interno.')
    }
    if (!job) break

    const msgId = Number(job.msg_id)
    try {
      const resultado = await processarWebhook(job.payload ?? {})
      const { data: fim } = await sb.rpc('worker_finalizar_job', {
        p_fila: 'webhooks', p_msg_id: msgId, p_sucesso: true,
        p_erro_codigo: null, p_erro_detalhe: null, p_max_tentativas: 5,
      })
      resultados.push({ msg_id: msgId, ok: true, resultado, finalizacao: fim })
    } catch (e) {
      const erro = e instanceof WebhookError ? e : new WebhookError('WEBHOOK_FALHOU', 'Falha inesperada ao entregar webhook.')
      const maxTentativas = erro.codigo === 'WEBHOOK_DESTINO_BLOQUEADO' || erro.codigo === 'WEBHOOK_CONFIGURACAO_INVALIDA' ? 1 : 5
      const { data: fim } = await sb.rpc('worker_finalizar_job', {
        p_fila: 'webhooks', p_msg_id: msgId, p_sucesso: false,
        p_erro_codigo: erro.codigo, p_erro_detalhe: erro.message.slice(0, 500), p_max_tentativas: maxTentativas,
      })
      resultados.push({ msg_id: msgId, ok: false, codigo: erro.codigo, finalizacao: fim })
    }
  }

  return Response.json({ ok: true, fila: 'webhooks', processados: resultados.length, resultados })
})
