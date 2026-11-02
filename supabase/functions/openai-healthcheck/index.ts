import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? ''
const sb = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } })

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Este endpoint aceita somente validações internas do ContaOS.' }, { status: 405 })
  }
  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido } = await sb.rpc('validar_token_interno', { p_token: token })
  if (valido !== true) {
    return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta validação interna não está autorizada.' }, { status: 401 })
  }
  if (!OPENAI_API_KEY) {
    return Response.json({ ok: false, codigo: 'OPENAI_CHAVE_AUSENTE', titulo: 'Configuração da IA pendente', mensagem: 'A chave da OpenAI ainda não está disponível no ambiente do ContaOS.' }, { status: 503 })
  }
  try {
    const r = await fetch('https://api.openai.com/v1/models', {
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
      signal: AbortSignal.timeout(10000),
    })
    if (!r.ok) {
      return Response.json({ ok: false, codigo: 'OPENAI_CHAVE_INVALIDA', titulo: 'Não foi possível validar a OpenAI', mensagem: 'A credencial configurada não foi aceita ou a validação não pôde ser concluída.' }, { status: 502 })
    }
    return Response.json({ ok: true, codigo: 'OPENAI_OK', titulo: 'OpenAI conectada', mensagem: 'A integração com a OpenAI está disponível para o ContaOS HML.' })
  } catch {
    return Response.json({ ok: false, codigo: 'OPENAI_INDISPONIVEL', titulo: 'OpenAI temporariamente indisponível', mensagem: 'A validação excedeu o tempo seguro ou a OpenAI está temporariamente indisponível.' }, { status: 503 })
  }
})
