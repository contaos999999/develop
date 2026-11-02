import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

function responder(status: number, codigo: string, titulo: string, mensagem: string) {
  return Response.json(
    { ok: false, codigo, titulo, mensagem },
    {
      status,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
      },
    },
  )
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return responder(
      405,
      'METODO_INVALIDO',
      'Ação não permitida',
      'Este endpoint interno aceita somente solicitações POST.',
    )
  }

  const token = req.headers.get('x-contaos-internal-token') ?? ''
  const { data: valido, error } = await sb.rpc('validar_token_interno', { p_token: token })
  if (error || valido !== true) {
    return responder(
      401,
      'AUTH_ACESSO_NEGADO',
      'Acesso não permitido',
      'Esta operação interna não está autorizada.',
    )
  }

  return responder(
    410,
    'WORKER_LEGADO_DESATIVADO',
    'Processador legado desativado',
    'Este processador genérico foi aposentado por segurança. O ContaOS utiliza somente os processadores internos dedicados e homologados para cada fila.',
  )
})
