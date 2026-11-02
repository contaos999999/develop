import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const url = Deno.env.get('SUPABASE_URL')!
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
const LIMITE_JSON = 8 * 1024

function resposta(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff' } })
}

async function lerJsonLimitado(req:Request,limite:number){
  const informado=Number(req.headers.get('content-length')??0)
  if(Number.isFinite(informado)&&informado>limite) throw new Error('PAYLOAD_GRANDE')
  if(!req.body) return {}
  const reader=req.body.getReader(); const partes:Uint8Array[]=[]; let total=0
  try{
    while(true){
      const {done,value}=await reader.read(); if(done) break
      total+=value.byteLength
      if(total>limite){try{await reader.cancel()}catch{}; throw new Error('PAYLOAD_GRANDE')}
      partes.push(value)
    }
  }finally{try{reader.releaseLock()}catch{}}
  const bytes=new Uint8Array(total); let pos=0
  for(const parte of partes){bytes.set(parte,pos);pos+=parte.byteLength}
  return JSON.parse(new TextDecoder().decode(bytes))
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return resposta({ ok:false, codigo:'METODO_INVALIDO', titulo:'Ação não permitida', mensagem:'Esta operação aceita somente solicitações de processamento de documento.' }, 405)
  const authorization = req.headers.get('authorization') ?? ''
  if (!authorization) return resposta({ ok:false, codigo:'AUTH_NAO_AUTENTICADO', titulo:'Sessão necessária', mensagem:'Para continuar, faça login novamente.', orientacao:'Entre novamente na sua conta e repita a ação.' }, 401)

  let body: any = {}
  try { body = await lerJsonLimitado(req,LIMITE_JSON) } catch (e) {
    if(e instanceof Error&&e.message==='PAYLOAD_GRANDE') return resposta({ok:false,codigo:'REQUISICAO_MUITO_GRANDE',titulo:'Solicitação acima do limite',mensagem:'Os dados enviados para iniciar o processamento ultrapassam o limite permitido.'},413)
    return resposta({ ok:false, codigo:'DADOS_INVALIDOS', titulo:'Revise as informações', mensagem:'Não foi possível ler os dados enviados.', orientacao:'Atualize a página e tente novamente.' }, 400)
  }
  const idVersao = String(body.id_versao_documento ?? '').trim()
  const idempotencyKey = String(body.idempotency_key ?? `document:${idVersao}`)
  if (!idVersao) return resposta({ ok:false, codigo:'CAMPO_OBRIGATORIO', titulo:'Informação obrigatória', mensagem:'Informe a versão do documento que deve ser processada.', orientacao:'Selecione novamente o documento e tente outra vez.' }, 400)
  if(idempotencyKey.length>240) return resposta({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Chave de processamento inválida',mensagem:'A identificação desta solicitação ultrapassa o limite permitido.'},400)

  const client = createClient(url, anonKey, { global: { headers: { Authorization: authorization } }, auth: { persistSession:false, autoRefreshToken:false } })
  const { data, error } = await client.rpc('enfileirar_processamento_documento', { p_id_versao_documento:idVersao, p_chave_idempotencia:idempotencyKey })
  if (error) {
    const { data: amigavel } = await client.rpc('normalizar_erro_backend', { p_codigo_sql:error.code ?? '', p_mensagem_tecnica:error.message ?? '' })
    return resposta(amigavel ?? { ok:false, codigo:'DOCUMENTO_PROCESSAMENTO_FALHOU', titulo:'Não foi possível iniciar a análise do documento', mensagem:'O documento foi recebido, mas o processamento não pôde ser iniciado.', orientacao:'Tente novamente. Se o problema continuar, procure o suporte.' }, 400)
  }
  return resposta({ ok:true, codigo:'GERAL_PROCESSANDO', titulo:'Documento recebido', mensagem:'O documento entrou na fila de processamento. Você pode continuar usando o ContaOS normalmente.', id_execucao:data })
})
