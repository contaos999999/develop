import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const ANON=Deno.env.get('SUPABASE_ANON_KEY')!
const resp=(b:unknown,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8'}})
function dataHoraBR(d:Date){return new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).format(d).replace(',','')}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST') return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta função apenas para solicitar autorização de download.'},405)
 const authorization=req.headers.get('authorization')??''
 if(!authorization) return resp({ok:false,codigo:'AUTH_NAO_AUTENTICADO',titulo:'Sessão necessária',mensagem:'Para continuar, faça login novamente.'},401)
 let body:any={}; try{body=await req.json()}catch{return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Revise as informações',mensagem:'Não foi possível ler a solicitação.'},400)}
 const id=String(body.id_arquivo??''); if(!id) return resp({ok:false,codigo:'CAMPO_OBRIGATORIO',titulo:'Informação obrigatória',mensagem:'Informe o arquivo que deseja baixar.'},400)
 const client=createClient(URL,ANON,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}})
 const {data:arq,error:ea}=await client.from('arquivos').select('id,bucket,path,nome_original').eq('id',id).maybeSingle()
 if(ea||!arq) return resp({ok:false,codigo:'REGISTRO_NAO_ENCONTRADO',titulo:'Arquivo não encontrado',mensagem:'O arquivo não está disponível para o seu usuário.'},404)
 const segundos=Math.min(Math.max(Number(body.validade_segundos??600),60),3600)
 const {data,error}=await client.storage.from(arq.bucket).createSignedUrl(arq.path,segundos,{download:arq.nome_original})
 if(error||!data) return resp({ok:false,codigo:'ARQUIVO_UPLOAD_FALHOU',titulo:'Não foi possível preparar o download',mensagem:'Não conseguimos gerar o acesso temporário ao arquivo.',orientacao:'Tente novamente em alguns instantes.'},400)
 return resp({ok:true,titulo:'Download autorizado',mensagem:'O link temporário foi gerado com segurança.',nome_arquivo:arq.nome_original,signed_url:data.signedUrl,valido_ate:dataHoraBR(new Date(Date.now()+segundos*1000)),timezone:'Horário de Brasília'})
})
