import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import ipaddr from 'npm:ipaddr.js@2.5.0'
import { request as httpsRequest } from 'node:https'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const WEBHOOK_TIMEOUT_MS = 10_000
const DNS_TIMEOUT_MS = 2_500
const MAX_RESPONSE_BYTES = 4_000
const MAX_RESPONSE_HEADERS_BYTES = 16 * 1024

type CodigoWebhook =
  | 'WEBHOOK_DESTINO_BLOQUEADO'
  | 'WEBHOOK_TIMEOUT'
  | 'WEBHOOK_FALHOU'
  | 'WEBHOOK_CONFIGURACAO_INVALIDA'

type DestinoWebhookValidado = {
  url: URL
  ips: string[]
}

type RespostaWebhook = {
  status: number
  texto: string
}

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

function familiaIp(ip: string): 4 | 6 {
  return ipaddr.process(ip).kind() === 'ipv6' ? 6 : 4
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

function listasIguais(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false
  return a.every((valor, i) => valor === b[i])
}

function valorHeaderSeguro(valor: unknown, max = 240): string {
  return String(valor ?? '')
    .normalize('NFKC')
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max)
}

async function resolverIpsPublicos(hostname: string): Promise<string[]> {
  const host = hostSemColchetes(hostname)
  if (ipaddr.isValid(host)) {
    if (!ipEhPublico(host)) throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino de webhook aponta para endereço IP não público.')
    return [ipaddr.process(host).toString()]
  }

  const resolver = async (tipo: 'A' | 'AAAA') => {
    try {
      return await Deno.resolveDns(host, tipo, { signal: AbortSignal.timeout(DNS_TIMEOUT_MS) })
    } catch {
      return [] as string[]
    }
  }

  const [ipv4, ipv6] = await Promise.all([resolver('A'), resolver('AAAA')])
  const ips = [...new Set([...ipv4, ...ipv6].map((ip) => ipaddr.process(ip).toString()))].sort()
  if (!ips.length) throw new WebhookError('WEBHOOK_CONFIGURACAO_INVALIDA', 'Não foi possível resolver o endereço do webhook.')
  if (ips.some((ip) => !ipEhPublico(ip))) {
    throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Destino de webhook resolve para rede privada, local, reservada ou não roteável publicamente.')
  }
  return ips
}

async function validarDestinoWebhook(valor: unknown): Promise<DestinoWebhookValidado> {
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

  const primeira = await resolverIpsPublicos(url.hostname)
  const segunda = await resolverIpsPublicos(url.hostname)
  if (!listasIguais(primeira, segunda)) {
    throw new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'O DNS do webhook apresentou resolução instável durante a validação de segurança.')
  }

  return { url, ips: segunda }
}

function juntarChunks(chunks: Uint8Array[], total: number): string {
  const bytes = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.length
  }
  return new TextDecoder('utf-8', { fatal: false }).decode(bytes)
}

async function postHttpsFixado(
  destino: DestinoWebhookValidado,
  body: string,
  headers: Record<string, string>,
): Promise<RespostaWebhook> {
  const ip = destino.ips.find((item) => familiaIp(item) === 4) ?? destino.ips[0]
  const family = familiaIp(ip)

  return await new Promise<RespostaWebhook>((resolve, reject) => {
    let concluido = false
    const chunks: Uint8Array[] = []
    let total = 0

    const concluir = (status: number) => {
      if (concluido) return
      concluido = true
      resolve({ status, texto: juntarChunks(chunks, total) })
    }

    const req = httpsRequest(destino.url, {
      method: 'POST',
      headers,
      signal: AbortSignal.timeout(WEBHOOK_TIMEOUT_MS),
      maxHeaderSize: MAX_RESPONSE_HEADERS_BYTES,
      lookup: (_hostname: string, _options: unknown, callback: (...args: any[]) => void) => {
        callback(null, ip, family)
      },
    }, (res) => {
      const status = Number(res.statusCode ?? 0)

      res.on('data', (chunk: Uint8Array) => {
        if (concluido) return
        const bytes = chunk instanceof Uint8Array ? chunk : new Uint8Array(chunk)
        const restante = MAX_RESPONSE_BYTES - total
        if (restante > 0) {
          const parte = bytes.length > restante ? bytes.subarray(0, restante) : bytes
          chunks.push(new Uint8Array(parte))
          total += parte.length
        }
        if (bytes.length > restante || total >= MAX_RESPONSE_BYTES) {
          concluir(status)
          res.destroy()
        }
      })

      res.on('end', () => concluir(status))
      res.on('error', (e) => {
        if (!concluido) {
          concluido = true
          reject(e)
        }
      })
    })

    req.on('error', (e) => {
      if (!concluido) {
        concluido = true
        reject(e)
      }
    })

    req.end(body)
  })
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

  let destino: DestinoWebhookValidado
  try {
    destino = await validarDestinoWebhook(cfg.url)
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
    const resposta = await postHttpsFixado(destino, body, {
      'content-type': 'application/json',
      'x-contaos-evento': valorHeaderSeguro(cfg.evento),
      'x-contaos-assinatura': `v1=${assinatura}`,
      'x-contaos-signature-version': 'v1',
      'x-contaos-timestamp': timestamp,
      'x-contaos-delivery-id': valorHeaderSeguro(deliveryId),
      'x-contaos-correlation-id': valorHeaderSeguro(cfg.correlation_id),
    })

    respostaTexto = resposta.texto
    const respostaHash = await sha256Hex(respostaTexto)

    if (resposta.status >= 300 && resposta.status < 400) {
      const erro = new WebhookError('WEBHOOK_DESTINO_BLOQUEADO', 'Redirecionamentos HTTP não são permitidos para webhooks.', resposta.status)
      await registrarFalha(idEvento, erro, respostaTexto)
      throw erro
    }

    const sucesso = resposta.status >= 200 && resposta.status < 300
    await sb.rpc('worker_registrar_entrega_webhook', {
      p_id_evento: idEvento,
      p_sucesso: sucesso,
      p_status_http: resposta.status,
      p_resposta_hash: respostaHash,
      p_erro: sucesso ? null : `HTTP ${resposta.status}`,
    })

    if (!sucesso) throw new WebhookError('WEBHOOK_FALHOU', `Webhook respondeu HTTP ${resposta.status}.`, resposta.status)
    return { status_http: resposta.status, delivery_id: deliveryId, enviado_em: timestamp }
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
