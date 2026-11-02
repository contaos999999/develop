import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL = Deno.env.get('SUPABASE_URL')!
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const LIMITE_JSON = 8 * 1024
const COMANDO = 'adm01.convidar_usuario'

const admin = createClient(URL, SERVICE, {
  auth: { persistSession: false, autoRefreshToken: false },
})

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, apikey, x-client-info, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
}

const resp = (body: unknown, status = 200) => Response.json(body, {
  status,
  headers: {
    ...cors,
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  },
})

async function lerJsonLimitado(req: Request, limite: number) {
  const informado = Number(req.headers.get('content-length') ?? 0)
  if (Number.isFinite(informado) && informado > limite) throw new Error('PAYLOAD_GRANDE')
  if (!req.body) return {}
  const reader = req.body.getReader()
  const partes: Uint8Array[] = []
  let total = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      total += value.byteLength
      if (total > limite) {
        try { await reader.cancel() } catch {}
        throw new Error('PAYLOAD_GRANDE')
      }
      partes.push(value)
    }
  } finally {
    try { reader.releaseLock() } catch {}
  }
  const bytes = new Uint8Array(total)
  let pos = 0
  for (const parte of partes) {
    bytes.set(parte, pos)
    pos += parte.byteLength
  }
  return JSON.parse(new TextDecoder().decode(bytes))
}

async function sha256(texto: string) {
  const bytes = new TextEncoder().encode(texto)
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

const uuidOk = (valor: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(valor)
const emailOk = (valor: string) => valor.length <= 320 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(valor)

async function buscarUsuarioPorEmail(email: string) {
  const { data, error } = await admin
    .from('usuarios')
    .select('id_usuario,email,nome')
    .ilike('email', email)
    .order('id_usuario')
    .limit(1)
    .maybeSingle()
  if (error) throw new Error('BUSCA_USUARIO_FALHOU')
  return data as { id_usuario: string; email: string | null; nome: string | null } | null
}

async function marcarFalha(id: string | null, codigo: string) {
  if (!id) return
  await admin
    .from('comandos_idempotentes')
    .update({ status: 'falhou', resposta: { ok: false, codigo } })
    .eq('id', id)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors })
  if (req.method !== 'POST') {
    return resp({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Use esta função apenas para convidar ou localizar uma conta de usuário.' }, 405)
  }

  const authorization = req.headers.get('authorization') ?? ''
  if (!authorization) {
    return resp({ ok: false, codigo: 'AUTH_NAO_AUTENTICADO', titulo: 'Sessão necessária', mensagem: 'Para continuar, faça login novamente.' }, 401)
  }

  let body: any = {}
  try {
    body = await lerJsonLimitado(req, LIMITE_JSON)
  } catch (e) {
    if (e instanceof Error && e.message === 'PAYLOAD_GRANDE') {
      return resp({ ok: false, codigo: 'REQUISICAO_MUITO_GRANDE', titulo: 'Solicitação acima do limite', mensagem: 'Os dados enviados ultrapassam o limite permitido.' }, 413)
    }
    return resp({ ok: false, codigo: 'DADOS_INVALIDOS', titulo: 'Revise as informações', mensagem: 'Não foi possível ler os dados enviados.' }, 400)
  }

  const idOrganizacao = String(body.id_organizacao ?? '').trim()
  const email = String(body.email ?? '').trim().toLowerCase()
  const nome = String(body.nome ?? '').trim().slice(0, 200)
  const chave = String(body.chave_idempotencia ?? '').trim()

  if (!uuidOk(idOrganizacao) || !emailOk(email) || !chave || chave.length > 200) {
    return resp({ ok: false, codigo: 'DADOS_INVALIDOS', titulo: 'Revise as informações', mensagem: 'Informe organização, e-mail e identificação da operação válidos.' }, 422)
  }

  const caller = createClient(URL, ANON, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: userData, error: userErr } = await caller.auth.getUser()
  if (userErr || !userData.user) {
    return resp({ ok: false, codigo: 'AUTH_SESSAO_INVALIDA', titulo: 'Sessão expirada', mensagem: 'Sua sessão não é mais válida.', orientacao: 'Entre novamente no ContaOS.' }, 401)
  }

  const { error: adminErr } = await caller.rpc('validar_administrador_organizacao', { p_id_organizacao: idOrganizacao })
  if (adminErr) {
    return resp({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Você não tem permissão para administrar usuários desta organização.' }, 403)
  }

  const hashPayload = await sha256(JSON.stringify({ email, nome }))
  let comandoId: string | null = null

  const { data: existente, error: existenteErr } = await admin
    .from('comandos_idempotentes')
    .select('id,hash_payload,status,resposta')
    .eq('id_organizacao', idOrganizacao)
    .eq('comando', COMANDO)
    .eq('chave', chave)
    .maybeSingle()

  if (existenteErr) {
    return resp({ ok: false, codigo: 'OPERACAO_INDISPONIVEL', titulo: 'Não foi possível continuar', mensagem: 'Tente novamente em instantes.' }, 500)
  }

  if (existente) {
    comandoId = existente.id
    if (existente.hash_payload !== hashPayload) {
      return resp({ ok: false, codigo: 'CONFLITO_IDEMPOTENCIA', titulo: 'Ação já utilizada', mensagem: 'Esta identificação de operação já foi usada com outros dados. Atualize a tela e tente novamente.' }, 409)
    }
    if (existente.status === 'concluido' && existente.resposta) return resp(existente.resposta, 200)
    if (existente.status === 'iniciado') {
      return resp({ ok: false, codigo: 'OPERACAO_EM_PROCESSAMENTO', titulo: 'Ação em processamento', mensagem: 'Esta ação já está sendo processada. Aguarde a atualização da tela antes de tentar novamente.' }, 409)
    }
    await admin.from('comandos_idempotentes').update({ status: 'iniciado', resposta: null }).eq('id', comandoId)
  } else {
    const expiraEm = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    const { data: reservado, error: reservarErr } = await admin
      .from('comandos_idempotentes')
      .insert({ id_organizacao: idOrganizacao, comando: COMANDO, chave, hash_payload: hashPayload, status: 'iniciado', expira_em: expiraEm })
      .select('id')
      .single()

    if (reservarErr || !reservado) {
      if (reservarErr?.code === '23505') {
        return resp({ ok: false, codigo: 'OPERACAO_EM_PROCESSAMENTO', titulo: 'Ação em processamento', mensagem: 'Esta ação já está sendo processada. Aguarde a atualização da tela antes de tentar novamente.' }, 409)
      }
      return resp({ ok: false, codigo: 'OPERACAO_INDISPONIVEL', titulo: 'Não foi possível continuar', mensagem: 'Tente novamente em instantes.' }, 500)
    }
    comandoId = reservado.id
  }

  try {
    let usuario = await buscarUsuarioPorEmail(email)
    let conviteEnviado = false

    if (!usuario) {
      const { data: convite, error: conviteErr } = await admin.auth.admin.inviteUserByEmail(email, nome ? { data: { nome } } : undefined)
      if (conviteErr || !convite.user) {
        usuario = await buscarUsuarioPorEmail(email)
        if (!usuario) {
          await marcarFalha(comandoId, 'CONVITE_NAO_ENVIADO')
          return resp({ ok: false, codigo: 'CONVITE_NAO_ENVIADO', titulo: 'Convite não enviado', mensagem: 'Não foi possível enviar o convite agora. Verifique o e-mail e tente novamente.' }, 422)
        }
      } else {
        conviteEnviado = true
        usuario = { id_usuario: convite.user.id, email: convite.user.email ?? email, nome }
      }
    }

    const resposta = {
      ok: true,
      codigo: conviteEnviado ? 'USUARIO_CONVIDADO' : 'USUARIO_EXISTENTE',
      titulo: conviteEnviado ? 'Convite enviado' : 'Conta localizada',
      mensagem: conviteEnviado
        ? 'O convite foi enviado. Agora conclua o vínculo, perfil e escopo do usuário.'
        : 'A conta já existe no ContaOS. Agora conclua o vínculo, perfil e escopo do usuário.',
      usuario: { id_usuario: usuario.id_usuario, email: usuario.email ?? email, nome: (usuario.nome ?? nome) || null },
      convite_enviado: conviteEnviado,
      proxima_acao: 'salvar_vinculo_usuario_adm',
    }

    const { error: concluirErr } = await admin
      .from('comandos_idempotentes')
      .update({ status: 'concluido', resposta })
      .eq('id', comandoId)

    if (concluirErr) {
      return resp({ ok: false, codigo: 'OPERACAO_NAO_CONFIRMADA', titulo: 'Não foi possível confirmar a operação', mensagem: 'A conta foi localizada, mas a confirmação da operação falhou. Atualize a tela antes de repetir a ação.' }, 500)
    }

    return resp(resposta, 200)
  } catch {
    await marcarFalha(comandoId, 'CONVITE_FALHOU')
    return resp({ ok: false, codigo: 'CONVITE_FALHOU', titulo: 'Não foi possível concluir', mensagem: 'Não foi possível localizar ou convidar a conta agora. Tente novamente em instantes.' }, 500)
  }
})
