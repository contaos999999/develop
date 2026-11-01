import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL=Deno.env.get('SUPABASE_URL')
const KEY=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const sb=createClient(URL,KEY,{auth:{persistSession:false,autoRefreshToken:false}})
const resp=(b,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'}})
async function hash(v){const h=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v??''));return Array.from(new Uint8Array(h)).map(b=>b.toString(16).padStart(2,'0')).join('')}
function dataHoraBR(v){if(!v)return null;return new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).format(new Date(v)).replace(',','')}
Deno.serve(async(req)=>{
 if(req.method!=='POST')return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta página apenas para consultar um pacote de evidências.'},405)
 let body={};try{body=await req.json()}catch{return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Link inválido',mensagem:'Não foi possível validar este acesso.'},400)}
 const token=String(body.token??'').trim();if(!token)return resp({ok:false,codigo:'TOKEN_INVALIDO',titulo:'Acesso não reconhecido',mensagem:'Este link de acesso não é válido ou não está mais disponível.'},401)
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
   if(arq){const {data:signed}=await sb.storage.from(arq.bucket).createSignedUrl(arq.path,600,{download:arq.nome_original});if(signed)download={nome_arquivo:arq.nome_original,url:signed.signedUrl,valido_por_segundos:600}}
 }
 return resp({ok:true,titulo:'Pacote de evidências',mensagem:'Acesso temporário validado com segurança.',pacote:{id:pacote.id,hash:pacote.hash,escopo:pacote.escopo,congelado_em:dataHoraBR(pacote.congelado_em),expira_em:dataHoraBR(validacao.expira_em),timezone:'Horário de Brasília'},itens:itens??[],download,acessos_restantes:validacao.acessos_restantes})
})
