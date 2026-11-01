import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const KEY=Deno.env.get('OPENAI_API_KEY')??''
const sb=createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}})
const png='iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKUlEQVR4nO3NMQEAAAjDMMC/52ECvlRA00nqs3m9AwAAAAAAAAAAgMMWx/EDPS4YA2MAAAAASUVORK5CYII='
async function call(body:any){const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${KEY}`,'Content-Type':'application/json'},body:JSON.stringify({...body,store:false})});if(r.ok){const j=await r.json();return{ok:true,status:r.status,model:j.model??body.model,id:j.id??null}}const t=await r.text();return{ok:false,status:r.status,model:body.model,erro:t.slice(0,900)}}
Deno.serve(async(req:Request)=>{if(req.method!=='POST')return Response.json({ok:false},{status:405});const token=req.headers.get('x-contaos-internal-token')??'';const{data:v}=await sb.rpc('validar_token_interno',{p_token:token});if(v!==true)return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO'},{status:401});if(!KEY)return Response.json({ok:false,codigo:'OPENAI_CHAVE_AUSENTE'},{status:503});
 const fmt={type:'json_schema',name:'teste_contaos',strict:true,schema:{type:'object',properties:{resultado:{type:'string'}},required:['resultado'],additionalProperties:false}}
 const analise=await call({model:'gpt-6.1-sol',input:[{role:'user',content:[{type:'input_text',text:'Retorne resultado OK.'}]}],text:{format:fmt},max_output_tokens:32})
 const ocr=await call({model:'gpt-6-luna',input:[{role:'user',content:[{type:'input_image',image_url:`data:image/png;base64,${png}`,detail:'high'},{type:'input_text',text:'Observe a imagem e retorne resultado OK. Não invente texto.'}]}],text:{format:fmt},max_output_tokens:32})
 return Response.json({ok:analise.ok&&ocr.ok,analise,ocr})
})
