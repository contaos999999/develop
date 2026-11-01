import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const KEY=Deno.env.get('OPENAI_API_KEY')??''
const sb=createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}})
async function testar(model:string){
  const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${KEY}`,'Content-Type':'application/json'},body:JSON.stringify({model,input:'Responda apenas: OK',max_output_tokens:8,store:false})})
  if(r.ok){const j=await r.json();return{ok:true,model:j.model??model,id:j.id??null}}
  const t=await r.text();return{ok:false,model,status:r.status,erro:t.slice(0,700)}
}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST')return Response.json({ok:false},{status:405})
 const token=req.headers.get('x-contaos-internal-token')??'';const{data:v}=await sb.rpc('validar_token_interno',{p_token:token});if(v!==true)return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO'},{status:401})
 if(!KEY)return Response.json({ok:false,codigo:'OPENAI_CHAVE_AUSENTE'},{status:503})
 const modelos=['gpt-6-luna','gpt-6.1-sol'];const resultados=[];for(const m of modelos)resultados.push(await testar(m));return Response.json({ok:resultados.every(x=>x.ok),resultados})
})
