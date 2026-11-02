import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL=Deno.env.get('SUPABASE_URL')!
const ANON=Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const B='contaos-documentos'
const LIMITE_JSON=8*1024
const admin=createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}})
const resp=(b:unknown,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}})
const seguro=(n:string)=>n.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9._-]+/g,'-').replace(/-+/g,'-').slice(-180) || 'arquivo'

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

Deno.serve(async(req:Request)=>{
 if(req.method!=='POST') return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta função apenas para solicitar autorização de upload.'},405)
 const authorization=req.headers.get('authorization')??''
 if(!authorization) return resp({ok:false,codigo:'AUTH_NAO_AUTENTICADO',titulo:'Sessão necessária',mensagem:'Para continuar, faça login novamente.'},401)
 let body:any={}
 try{body=await lerJsonLimitado(req,LIMITE_JSON)}catch(e){
  if(e instanceof Error&&e.message==='PAYLOAD_GRANDE') return resp({ok:false,codigo:'REQUISICAO_MUITO_GRANDE',titulo:'Solicitação acima do limite',mensagem:'Os dados enviados para preparar o upload ultrapassam o limite permitido.'},413)
  return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Revise as informações',mensagem:'Não foi possível ler os dados do arquivo.'},400)
 }
 const org=String(body.id_organizacao??''); const contrato=body.id_contrato?String(body.id_contrato):null; const nome=String(body.nome_arquivo??''); const mime=String(body.mime??'').toLowerCase(); const tamanho=Number(body.tamanho??0)
 if(!org||!nome||!mime||!Number.isFinite(tamanho)||tamanho<0) return resp({ok:false,codigo:'CAMPO_OBRIGATORIO',titulo:'Informações incompletas',mensagem:'Informe organização, nome, tipo e tamanho do arquivo antes de continuar.'},400)

 const client=createClient(URL,ANON,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}})
 const {data:userData,error:userErr}=await client.auth.getUser()
 if(userErr||!userData.user) return resp({ok:false,codigo:'AUTH_SESSAO_INVALIDA',titulo:'Sessão expirada',mensagem:'Sua sessão não é mais válida.','orientacao':'Entre novamente no ContaOS.'},401)
 const {data:orgOk}=await client.from('organizacoes').select('id').eq('id',org).maybeSingle()
 if(!orgOk) return resp({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Seu usuário não possui acesso à organização informada.'},403)
 if(contrato){const {data:c}=await client.from('contratos').select('id,id_organizacao').eq('id',contrato).eq('id_organizacao',org).maybeSingle(); if(!c) return resp({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Seu usuário não possui acesso ao contrato informado.'},403)}

 const {data:cfg,error:cfgErr}=await client.from('configuracao_upload').select('*').eq('id',true).single()
 if(cfgErr||!cfg) return resp({ok:false,codigo:'CONFIGURACAO_INDISPONIVEL',titulo:'Upload temporariamente indisponível',mensagem:'Não foi possível carregar as regras de segurança para o envio do arquivo.'},503)
 const ext=(nome.split('.').pop()??'').toLowerCase()
 if(!cfg.extensoes_permitidas.includes(ext)) return resp({ok:false,codigo:'ARQUIVO_TIPO_NAO_SUPORTADO',titulo:'Formato de arquivo não aceito',mensagem:'Este tipo de arquivo não pode ser enviado ao ContaOS.',orientacao:'Escolha um dos formatos aceitos nesta etapa.'},400)
 if(!cfg.mimes_permitidos.includes(mime)) return resp({ok:false,codigo:'ARQUIVO_TIPO_NAO_SUPORTADO',titulo:'Tipo de arquivo não aceito',mensagem:'O conteúdo informado não corresponde a um tipo aceito pelo ContaOS.'},400)
 if(cfg.tamanho_maximo_bytes&&tamanho>Number(cfg.tamanho_maximo_bytes)) return resp({ok:false,codigo:'ARQUIVO_MUITO_GRANDE',titulo:'Arquivo acima do limite',mensagem:'O arquivo ultrapassa o tamanho máximo configurado para este ambiente.'},400)

 const id=crypto.randomUUID(); const path=`${org}/uploads/${id}/${seguro(nome)}`
 const {data,error}=await admin.storage.from(B).createSignedUploadUrl(path,{upsert:false})
 if(error||!data) return resp({ok:false,codigo:'ARQUIVO_UPLOAD_FALHOU',titulo:'Não foi possível preparar o envio',mensagem:'Não conseguimos gerar a autorização temporária para este arquivo.',orientacao:'Tente novamente. Se o problema continuar, procure o suporte.'},400)
 const resumivel=tamanho>=Number(cfg.limiar_upload_resumivel_bytes)
 return resp({ok:true,titulo:'Upload autorizado',mensagem:resumivel?'O arquivo deve ser enviado pelo modo retomável, adequado para arquivos grandes.':'O arquivo está autorizado para envio direto ao armazenamento.',bucket:B,path,token:data.token,signed_url:data.signedUrl,usar_upload_resumivel:resumivel,limiar_upload_resumivel_bytes:cfg.limiar_upload_resumivel_bytes??104857600})
})
