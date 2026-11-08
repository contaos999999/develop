import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const ANON=Deno.env.get('SUPABASE_ANON_KEY')!
const LIMITE_JSON=8*1024
const ORIGENS_CORS=['http://127.0.0.1:4173','https://scope-and-approval-keeper.lovable.app','https://contaos-41-hml.vercel.app']
const HEADERS_CORS=['authorization','x-client-info','apikey','content-type']
function cabecalhosCors(origem:string|null,preflight=false){
 return {'cache-control':'no-store','x-content-type-options':'nosniff','vary':preflight?'Origin, Access-Control-Request-Method, Access-Control-Request-Headers':'Origin',...(origem?{'access-control-allow-origin':origem}:{})}
}
function dataHoraBR(d:Date){return new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).format(d).replace(',','')}
function nomeDownloadSeguro(v:unknown){
 const original=String(v??'arquivo').normalize('NFKC')
 const limpo=original.replace(/[^\p{L}\p{N} ._()\[\]-]+/gu,'_').replace(/\s+/g,' ').replace(/^\.+/,'').trim().slice(0,160).trim()
 return limpo||'arquivo'
}
async function lerJsonLimitado(req:Request,limite:number){
 const informado=Number(req.headers.get('content-length')??0)
 if(Number.isFinite(informado)&&informado>limite) throw new Error('PAYLOAD_GRANDE')
 if(!req.body) return {}
 const reader=req.body.getReader(); const partes:Uint8Array[]=[]; let total=0
 try{
  while(true){const {done,value}=await reader.read(); if(done) break; total+=value.byteLength; if(total>limite){try{await reader.cancel()}catch{}; throw new Error('PAYLOAD_GRANDE')} partes.push(value)}
 }finally{try{reader.releaseLock()}catch{}}
 const bytes=new Uint8Array(total); let pos=0; for(const parte of partes){bytes.set(parte,pos);pos+=parte.byteLength}
 return JSON.parse(new TextDecoder().decode(bytes))
}
Deno.serve(async(req:Request)=>{
 const origem=req.headers.get('origin')
 const origemPermitida=ORIGENS_CORS.includes(origem??'')
 const resp=(b:unknown,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8',...cabecalhosCors(origemPermitida?origem:null)}})
 if(req.method==='OPTIONS'&&origem!==null){
  const solicitados=req.headers.get('access-control-request-headers')
  const headersPermitidos=solicitados===null||solicitados.split(',').every(h=>HEADERS_CORS.includes(h.trim().toLowerCase()))
  const valido=origemPermitida&&req.headers.get('access-control-request-method')==='POST'&&headersPermitidos
  return new Response(null,{status:valido?204:403,headers:{...cabecalhosCors(valido?origem:null,true),...(valido?{'access-control-allow-methods':'POST, OPTIONS','access-control-allow-headers':HEADERS_CORS.join(', ')}:{})}})
 }
 if(req.method!=='POST') return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta função apenas para solicitar autorização de download.'},405)
 if(origem!==null&&!origemPermitida) return resp({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'A origem da solicitação não é permitida.'},403)
 const authorization=req.headers.get('authorization')??''
 if(!authorization) return resp({ok:false,codigo:'AUTH_NAO_AUTENTICADO',titulo:'Sessão necessária',mensagem:'Para continuar, faça login novamente.'},401)
 let body:any={}
 try{body=await lerJsonLimitado(req,LIMITE_JSON)}catch(e){
  if(e instanceof Error&&e.message==='PAYLOAD_GRANDE') return resp({ok:false,codigo:'REQUISICAO_MUITO_GRANDE',titulo:'Solicitação acima do limite',mensagem:'Os dados enviados para preparar o download ultrapassam o limite permitido.'},413)
  return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Revise as informações',mensagem:'Não foi possível ler a solicitação.'},400)
 }
 const id=String(body.id_arquivo??''); if(!id) return resp({ok:false,codigo:'CAMPO_OBRIGATORIO',titulo:'Informação obrigatória',mensagem:'Informe o arquivo que deseja baixar.'},400)
 const client=createClient(URL,ANON,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}})
 const {data:arq,error:ea}=await client.from('arquivos').select('id,bucket,path,nome_original').eq('id',id).maybeSingle()
 if(ea||!arq) return resp({ok:false,codigo:'REGISTRO_NAO_ENCONTRADO',titulo:'Arquivo não encontrado',mensagem:'O arquivo não está disponível para o seu usuário.'},404)
 const segundos=Math.min(Math.max(Number(body.validade_segundos??600),60),3600)
 const nomeSeguro=nomeDownloadSeguro(arq.nome_original)
 const {data,error}=await client.storage.from(arq.bucket).createSignedUrl(arq.path,segundos,{download:nomeSeguro})
 if(error||!data) return resp({ok:false,codigo:'ARQUIVO_UPLOAD_FALHOU',titulo:'Não foi possível preparar o download',mensagem:'Não conseguimos gerar o acesso temporário ao arquivo.',orientacao:'Tente novamente em alguns instantes.'},400)
 return resp({ok:true,titulo:'Download autorizado',mensagem:'O link temporário foi gerado com segurança.',nome_arquivo:nomeSeguro,signed_url:data.signedUrl,valido_ate:dataHoraBR(new Date(Date.now()+segundos*1000)),timezone:'Horário de Brasília'})
})
