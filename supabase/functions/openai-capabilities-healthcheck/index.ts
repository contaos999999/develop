import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const KEY=Deno.env.get('OPENAI_API_KEY')??''
const MODEL='gpt-6-luna'
const OPENAI_TIMEOUT_MS=10_000
const sb=createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}})
const png='iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKUlEQVR4nO3NMQEAAAjDMMC/52ECvlRA00nqs3m9AwAAAAAAAAAAgMMWx/EDPS4YA2MAAAAASUVORK5CYII='
async function call(body:any){
 try{
  const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${KEY}`,'Content-Type':'application/json'},body:JSON.stringify({...body,store:false}),signal:AbortSignal.timeout(OPENAI_TIMEOUT_MS)})
  if(r.ok){const j=await r.json();return{ok:true,status:r.status,model:j.model??body.model,id:j.id??null}}
  const t=await r.text();return{ok:false,status:r.status,model:body.model,erro:t.slice(0,900)}
 }catch(e){
  const timeout=e instanceof Error&&(e.name==='TimeoutError'||e.name==='AbortError')
  return{ok:false,status:timeout?504:0,model:body.model,erro:timeout?'Tempo limite da validação externa excedido.':'Falha de rede durante a validação externa.'}
 }
}
Deno.serve(async(req:Request)=>{if(req.method!=='POST')return Response.json({ok:false,codigo:'METODO_INVALIDO',mensagem:'Este endpoint aceita somente validações internas do ContaOS.'},{status:405});const token=req.headers.get('x-contaos-internal-token')??'';const{data:v}=await sb.rpc('validar_token_interno',{p_token:token});if(v!==true)return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO',mensagem:'Esta validação interna não está autorizada.'},{status:401});if(!KEY)return Response.json({ok:false,codigo:'OPENAI_CHAVE_AUSENTE',mensagem:'A chave da OpenAI ainda não está disponível no ambiente.'},{status:503});
 const fmt={type:'json_schema',name:'teste_contaos',strict:true,schema:{type:'object',properties:{resultado:{type:'string'}},required:['resultado'],additionalProperties:false}}
 const analise=await call({model:MODEL,input:[{role:'user',content:[{type:'input_text',text:'Retorne resultado OK.'}]}],text:{format:fmt},max_output_tokens:32})
 const ocr=await call({model:MODEL,input:[{role:'user',content:[{type:'input_image',image_url:`data:image/png;base64,${png}`,detail:'high'},{type:'input_text',text:'Observe a imagem e retorne resultado OK. Não invente texto.'}]}],text:{format:fmt},max_output_tokens:32})
 return Response.json({ok:analise.ok&&ocr.ok,modelo_operacional:MODEL,analise,ocr},{headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'}})
})
