import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL = Deno.env.get('SUPABASE_URL')!
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const KEY = Deno.env.get('OPENAI_API_KEY') ?? ''
const sb = createClient(URL, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } })

async function testar(finalidade: string, model: string) {
  try {
    const r = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model, input: 'Responda apenas: OK', max_output_tokens: 16, store: false }),
      signal: AbortSignal.timeout(10000),
    })
    if (r.ok) {
      const j = await r.json()
      return { ok: true, finalidade, model: j.model ?? model, id: j.id ?? null }
    }
    return {
      ok: false,
      finalidade,
      model,
      status: r.status,
      codigo: 'OPENAI_MODELO_INDISPONIVEL',
      mensagem: 'Não foi possível validar este modelo da OpenAI neste momento.',
    }
  } catch {
    return {
      ok: false,
      finalidade,
      model,
      status: 503,
      codigo: 'OPENAI_TIMEOUT_OU_INDISPONIVEL',
      mensagem: 'A validação do modelo excedeu o tempo seguro ou a OpenAI está temporariamente indisponível.',
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, codigo: 'METODO_INVALIDO', mensagem: 'Este endpoint aceita somente validações internas do ContaOS.' }, { status: 405 })
  }
  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido } = await sb.rpc('validar_token_interno', { p_token: token })
  if (valido !== true) {
    return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', mensagem: 'Esta validação interna não está autorizada.' }, { status: 401 })
  }
  if (!KEY) {
    return Response.json({ ok: false, codigo: 'OPENAI_CHAVE_AUSENTE', mensagem: 'A chave da OpenAI ainda não está disponível no ambiente.' }, { status: 503 })
  }
  const resultados = [await testar('ocr', 'gpt-6-luna'), await testar('analise', 'gpt-6-luna')]
  return Response.json({ ok: resultados.every((x) => x.ok), modelo_operacional: 'gpt-6-luna', modelo_preferencial_futuro: 'gpt-6.1-sol', resultados })
})
