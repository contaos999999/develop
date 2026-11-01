import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL=Deno.env.get('SUPABASE_URL')!
const SERVICE=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const sb=createClient(URL,SERVICE,{auth:{persistSession:false,autoRefreshToken:false}})

async function gzipBase64(text:string){
  const input=new TextEncoder().encode(text)
  const stream=new Blob([input]).stream().pipeThrough(new CompressionStream('gzip'))
  const compressed=new Uint8Array(await new Response(stream).arrayBuffer())
  let binary=''
  const chunk=0x8000
  for(let i=0;i<compressed.length;i+=chunk){
    binary+=String.fromCharCode(...compressed.subarray(i,Math.min(i+chunk,compressed.length)))
  }
  return {base64:btoa(binary),bytes:compressed.byteLength}
}

Deno.serve(async(req:Request)=>{
  if(req.method!=='POST') return Response.json({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Este endpoint aceita somente chamadas internas do ContaOS.'},{status:405})
  const token=req.headers.get('x-contaos-internal-token')??''
  const {data:valido}=await sb.rpc('validar_token_interno',{p_token:token})
  if(valido!==true) return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Esta operação interna não está autorizada.'},{status:401})
  let body:any={}; try{body=await req.json()}catch{}
  const {data:sql,error}=await sb.rpc('worker_exportar_historico_migrations')
  if(error||!sql) return Response.json({ok:false,codigo:'EXPORTACAO_FALHOU',titulo:'Histórico não exportado',mensagem:'Não foi possível gerar o histórico de migrations do HML.'},{status:500})
  const texto=String(sql)
  const bytes=new TextEncoder().encode(texto)
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(b=>b.toString(16).padStart(2,'0')).join('')
  if(body?.modo==='gzip_base64'){
    const gz=await gzipBase64(texto)
    return Response.json({ok:true,codigo:'HISTORICO_COMPACTADO',titulo:'Histórico compactado',mensagem:'O histórico exato de migrations do HML foi compactado para versionamento.',arquivo:'contaos-hml-full-history.sql.gz',bytes_originais:bytes.byteLength,bytes_comprimidos:gz.bytes,sha256_sql:hash,conteudo_base64:gz.base64})
  }
  const path='system/migrations/contaos-hml-full-history.sql'
  const {error:up}=await sb.storage.from('contaos-documentos').upload(path,bytes,{contentType:'text/plain; charset=utf-8',upsert:true})
  if(up) return Response.json({ok:false,codigo:'EXPORTACAO_FALHOU',titulo:'Histórico não exportado',mensagem:'Não foi possível gravar o histórico de migrations no armazenamento.'},{status:500})
  const {data:signed,error:se}=await sb.storage.from('contaos-documentos').createSignedUrl(path,1800,{download:'contaos-hml-full-history.sql'})
  if(se||!signed) return Response.json({ok:false,codigo:'EXPORTACAO_FALHOU',titulo:'Link temporário não gerado',mensagem:'O histórico foi gerado, mas não foi possível criar o acesso temporário.'},{status:500})
  return Response.json({ok:true,codigo:'HISTORICO_EXPORTADO',titulo:'Histórico exportado',mensagem:'O histórico exato de migrations do HML foi exportado com sucesso.',arquivo:'contaos-hml-full-history.sql',bytes:bytes.byteLength,sha256:hash,signed_url:signed.signedUrl,valido_por_segundos:1800})
})
