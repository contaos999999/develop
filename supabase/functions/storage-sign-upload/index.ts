import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const URL=Deno.env.get('SUPABASE_URL')!
const ANON=Deno.env.get('SUPABASE_ANON_KEY')!
const B='contaos-documentos'
const resp=(b:unknown,s=200)=>Response.json(b,{status:s,headers:{'content-type':'application/json; charset=utf-8'}})
const seguro=(n:string)=>n.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9._-]+/g,'-').replace(/-+/g,'-').slice(-180) || 'arquivo'
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST') return resp({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Use esta função apenas para solicitar autorização de upload.'},405)
 const authorization=req.headers.get('authorization')??''
 if(!authorization) return resp({ok:false,codigo:'AUTH_NAO_AUTENTICADO',titulo:'Sessão necessária',mensagem:'Para continuar, faça login novamente.'},401)
 let body:any={}; try{body=await req.json()}catch{return resp({ok:false,codigo:'DADOS_INVALIDOS',titulo:'Revise as informações',mensagem:'Não foi possível ler os dados do arquivo.'},400)}
 const org=String(body.id_organizacao??''); const contrato=body.id_contrato?String(body.id_contrato):null; const nome=String(body.nome_arquivo??''); const mime=String(body.mime??''); const tamanho=Number(body.tamanho??0)
 if(!org||!nome||!mime||!Number.isFinite(tamanho)||tamanho<0) return resp({ok:false,codigo:'CAMPO_OBRIGATORIO',titulo:'Informações incompletas',mensagem:'Informe organização, nome, tipo e tamanho do arquivo antes de continuar.'},400)
 const client=createClient(URL,ANON,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}})
 const {data:orgOk}=await client.from('organizacoes').select('id').eq('id',org).maybeSingle()
 if(!orgOk) return resp({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Seu usuário não possui acesso à organização informada.'},403)
 if(contrato){const {data:c}=await client.from('contratos').select('id').eq('id',contrato).maybeSingle(); if(!c) return resp({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Seu usuário não possui acesso ao contrato informado.'},403)}
 const {data:cfg}=await client.from('configuracao_upload').select('*').eq('id',true).single()
 const ext=(nome.split('.').pop()??'').toLowerCase()
 if(cfg&&!cfg.extensoes_permitidas.includes(ext)) return resp({ok:false,codigo:'ARQUIVO_TIPO_NAO_SUPORTADO',titulo:'Formato de arquivo não aceito',mensagem:'Este tipo de arquivo não pode ser enviado ao ContaOS.',orientacao:'Escolha um dos formatos aceitos nesta etapa.'},400)
 if(cfg&&!cfg.mimes_permitidos.includes(mime.toLowerCase())) return resp({ok:false,codigo:'ARQUIVO_TIPO_NAO_SUPORTADO',titulo:'Tipo de arquivo não aceito',mensagem:'O conteúdo informado não corresponde a um tipo aceito pelo ContaOS.'},400)
 if(cfg?.tamanho_maximo_bytes&&tamanho>Number(cfg.tamanho_maximo_bytes)) return resp({ok:false,codigo:'ARQUIVO_MUITO_GRANDE',titulo:'Arquivo acima do limite',mensagem:'O arquivo ultrapassa o tamanho máximo configurado para este ambiente.'},400)
 const id=crypto.randomUUID(); const path=`${org}/uploads/${id}/${seguro(nome)}`
 const {data,error}=await client.storage.from(B).createSignedUploadUrl(path,{upsert:false})
 if(error||!data) return resp({ok:false,codigo:'ARQUIVO_UPLOAD_FALHOU',titulo:'Não foi possível preparar o envio',mensagem:'Não conseguimos gerar a autorização temporária para este arquivo.',orientacao:'Tente novamente. Se o problema continuar, procure o suporte.'},400)
 const resumivel=cfg? tamanho>=Number(cfg.limiar_upload_resumivel_bytes):false
 return resp({ok:true,titulo:'Upload autorizado',mensagem:resumivel?'O arquivo deve ser enviado pelo modo retomável, adequado para arquivos grandes.':'O arquivo está autorizado para envio direto ao armazenamento.',bucket:B,path,token:data.token,signed_url:data.signedUrl,usar_upload_resumivel:resumivel,limiar_upload_resumivel_bytes:cfg?.limiar_upload_resumivel_bytes??104857600})
})
