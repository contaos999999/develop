import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
const URL=Deno.env.get('SUPABASE_URL')!
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST') return Response.json({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Este processador aceita somente chamadas internas do ContaOS.'},{status:405})
 const token=req.headers.get('x-contaos-internal-token')??''
 if(!token) return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Esta operação interna não está autorizada.'},{status:401})
 let body:any={}; try{body=await req.json()}catch{}
 const res=await fetch(`${URL}/functions/v1/contaos-worker`,{method:'POST',headers:{'content-type':'application/json','x-contaos-internal-token':token},body:JSON.stringify({queue:'webhooks',max_jobs:Math.min(Math.max(Number(body.max_jobs??3),1),10)})})
 const txt=await res.text(); return new Response(txt,{status:res.status,headers:{'content-type':'application/json; charset=utf-8'}})
})
