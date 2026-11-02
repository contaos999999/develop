import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL=Deno.env.get('SUPABASE_URL')
const KEY=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const sb=createClient(URL,KEY,{auth:{persistSession:false,autoRefreshToken:false}})
const MAX_BODY_BYTES=4096
const TOKEN_RE=/^ev_[a-f0-9]{64}$/
const resp=(b,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}})
async function hash(v){const h=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v??''));return Array.from(new Uint8Array(h)).map(b=>b.toString(16).padStart(2,'0')).join('')}
function dataHoraBR(v){if(!v)return null;return new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).format(new Date(v)).replace(',','')}
function nomeDownloadSeguro(v){const original=String(v??'arquivo').normalize('NFKC');const limpo=original.replace(/[^\p{L}\p{N} ._()\[\]-]+/gu,'_').replace(/\s+/g,' ').replace(/^\.+/,'').trim().slice(0,160).trim();return limpo||'arquivo'}
async function jsonLimitado(req){
 const tipo=(req.headers.get('content-type')??'').toLowerCase()
 if(!tipo.startsWith('application/json'))throw new Error('content-type')
 const declarado=Number(req.headers.get('content-length')??0)
 if(Number.isFinite(declarado)&&declarado>MAX_BODY_BYTES)throw new Error('body-too-large')
 if(!req.body)return {}
 const reader=req.body.getReader();const chunks=[];let total=0
 try{
  while(true){const {value,done}=await reader.read();if(done)break;if(!value?.length)continue;total+=value.length;if(total>MAX_BODY_BYTES){try{await reader.cancel('payload acima do limite')}catch{};throw new Error('body-too-large')}chunks.push(value)}
 }finally{try{reader.releaseLock()}catch{}}
 const bytes=new Uint8Array(total);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length}
 return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes))
}
Deno.serve(async(req)=>{
 if(req.method!=='POST')return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta página apenas para consultar um pacote de evidências.'},405)
 let body={};try{body=await jsonLimitado(req)}catch{return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Link inválido',mensagem:'Não foi possível validar este acesso.'},400)}
 const token=String(body.token??'').trim();if(!TOKEN_RE.test(token))return resp({ok:false,codigo:'TOKEN_INVALIDO',titulo:'Acesso não reconhecido',mensagem:'Este link de acesso não é válido ou não está mais disponível.'},401)
 const ip=(req.headers.get('x-forwarded-for')??'').split(',')[0].trim();const ua=req.headers.get('user-agent')??''
 const {data:validacao,error}=await sb.rpc('validar_acesso_temporario_pacote',{p_token:token,p_ip_hash:ip?await hash(ip):null,p_user_agent_hash:ua?await hash(ua):null})
 if(error)return resp({ok:false,codigo:'GERAL_ERRO_INESPERADO',titulo:'Não foi possível validar o acesso',mensagem:'Ocorreu um problema ao validar este link. Tente novamente em alguns instantes.'},500)
 if(!validacao?.permitido)return resp({ok:false,...validacao},403)
 const {data:pacote,error:ep}=await sb.from('pacotes_evidencias').select('id,id_organizacao,id_contrato,escopo,hash,status,expira_em,congelado_em,id_arquivo_exportacao').eq('id',validacao.id_pacote).single()
 if(ep||!pacote)return resp({ok:false,codigo:'PACOTE_INDISPONIVEL',titulo:'Pacote indisponível',mensagem:'O pacote de evidências não está disponível neste momento.'},404)
 const {data:itens}=await sb.from('itens_pacote_evidencias').select('entidade_tipo,entidade_id,versao_id,hash,metadados,ordem').eq('id_pacote',pacote.id).order('ordem')
 let download=null
 if(pacote.id_arquivo_exportacao){
   const {data:arq}=await sb.from('arquivos').select('bucket,path,nome_original').eq('id',pacote.id_arquivo_exportacao).maybeSingle()
   if(arq){const nomeSeguro=nomeDownloadSeguro(arq.nome_original);const {data:signed}=await sb.storage.from(arq.bucket).createSignedUrl(arq.path,600,{download:nomeSeguro});if(signed)download={nome_arquivo:nomeSeguro,url:signed.signedUrl,valido_por_segundos:600}}
 }
 return resp({ok:true,titulo:'Pacote de evidências',mensagem:'Acesso temporário validado com segurança.',pacote:{id:pacote.id,hash:pacote.hash,escopo:pacote.escopo,congelado_em:dataHoraBR(pacote.congelado_em),expira_em:dataHoraBR(validacao.expira_em),timezone:'Horário de Brasília'},itens:itens??[],download,acessos_restantes:validacao.acessos_restantes})
})
