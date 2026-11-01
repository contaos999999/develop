import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? ''
const OPENAI_MODEL_OCR = Deno.env.get('OPENAI_MODEL_OCR') ?? 'gpt-6-luna'
const sb = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } })

class AppError extends Error { constructor(public codigo:string, message:string){ super(message) } }
const amigavel = (codigo:string) => ({
  OPENAI_CHAVE_AUSENTE:'A inteligência de leitura ainda não está configurada. A equipe técnica foi informada.',
  OPENAI_AUTENTICACAO:'A conexão com a OpenAI precisa ser revisada pela equipe técnica.',
  OPENAI_LIMITE:'A leitura inteligente está temporariamente ocupada. O ContaOS tentará novamente automaticamente.',
  OCR_ARQUIVO_GRANDE:'O arquivo ultrapassa o limite de processamento inteligente. Divida o documento em partes menores e tente novamente.',
  OCR_FORMATO_NAO_SUPORTADO:'Este formato não pode ser lido pelo OCR do ContaOS.',
  OCR_RESPOSTA_INVALIDA:'A leitura automática não conseguiu interpretar o documento com segurança. O arquivo será mantido para nova tentativa.',
  OCR_FALHOU:'Não foi possível concluir a leitura automática do documento. O ContaOS tentará novamente automaticamente.'
}[codigo] ?? 'Não foi possível concluir a leitura automática do documento. O ContaOS tentará novamente automaticamente.')

function toBase64(bytes:Uint8Array){ let bin=''; const step=0x8000; for(let i=0;i<bytes.length;i+=step) bin += String.fromCharCode(...bytes.subarray(i,Math.min(i+step,bytes.length))); return btoa(bin) }
function ext(nome:string){ return (nome.split('.').pop() ?? '').toLowerCase() }
function fragmentar(texto:string,tamanho=1400,sobreposicao=180){ const s=texto.replace(/\r/g,'').replace(/[ \t]+/g,' ').replace(/\n{3,}/g,'\n\n').trim(); const out:string[]=[]; let i=0; while(i<s.length){ let f=Math.min(i+tamanho,s.length); if(f<s.length){ const c=s.lastIndexOf('\n',f); if(c>i+500) f=c } out.push(s.slice(i,f).trim()); if(f>=s.length) break; i=Math.max(f-sobreposicao,i+1) } return out.filter(Boolean) }
function outputText(j:any){ return (j?.output ?? []).flatMap((o:any)=>o?.content ?? []).filter((c:any)=>c?.type==='output_text').map((c:any)=>c?.text ?? '').join('\n').trim() }

async function marcarProcessamento(v:any,status:string,resultado:any={},erro_codigo:string|null=null,erro_detalhe:string|null=null){
  const { data: existente } = await sb.from('processamentos_documento').select('id').eq('id_versao_documento',v.id).eq('etapa','ocr').maybeSingle()
  const payload:any={status,resultado,erro_codigo,erro_detalhe,atualizado_em:new Date().toISOString()}
  if(status==='processando') payload.iniciado_em=new Date().toISOString()
  if(['concluido','falhou','cancelado'].includes(status)) payload.concluido_em=new Date().toISOString()
  if(existente?.id) await sb.from('processamentos_documento').update(payload).eq('id',existente.id)
  else await sb.from('processamentos_documento').insert({id_organizacao:v.id_organizacao,id_contrato:v.id_contrato,id_versao_documento:v.id,etapa:'ocr',...payload})
}

async function chamarOpenAI(nome:string,mime:string,bytes:Uint8Array){
  if(!OPENAI_API_KEY) throw new AppError('OPENAI_CHAVE_AUSENTE','OPENAI_API_KEY ausente')
  if(bytes.byteLength >= 50*1024*1024) throw new AppError('OCR_ARQUIVO_GRANDE','Arquivo >= 50 MB')
  const b64=toBase64(bytes); const e=ext(nome)
  let arquivo:any
  if(e==='pdf' || mime==='application/pdf') arquivo={type:'input_file',filename:nome,file_data:`data:application/pdf;base64,${b64}`,detail:'high'}
  else if(['png','jpg','jpeg','webp'].includes(e) || (mime ?? '').startsWith('image/')) arquivo={type:'input_image',image_url:`data:${mime || 'image/jpeg'};base64,${b64}`,detail:'high'}
  else throw new AppError('OCR_FORMATO_NAO_SUPORTADO',`Formato ${e}`)

  const schema={type:'object',properties:{idioma:{type:'string'},paginas:{type:'array',items:{type:'object',properties:{pagina:{type:'integer'},texto:{type:'string'},confianca:{type:'number'},observacoes:{type:'array',items:{type:'string'}}},required:['pagina','texto','confianca','observacoes'],additionalProperties:false}}},required:['idioma','paginas'],additionalProperties:false}
  const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${OPENAI_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({model:OPENAI_MODEL_OCR,input:[{role:'user',content:[arquivo,{type:'input_text',text:'Você é o OCR do ContaOS. Transcreva fielmente todo o texto legível do documento, página por página, preservando números, datas, valores, CNPJ/CPF, cabeçalhos, rodapés, tabelas em texto e quebras relevantes. Não invente conteúdo. Se algo estiver ilegível, registre [ILEGÍVEL]. Retorne somente a estrutura solicitada.'}]}],text:{format:{type:'json_schema',name:'ocr_contaos',strict:true,schema}},store:false})})
  if(!r.ok){ const t=await r.text(); if(r.status===401||r.status===403) throw new AppError('OPENAI_AUTENTICACAO',t.slice(0,500)); if(r.status===429) throw new AppError('OPENAI_LIMITE',t.slice(0,500)); throw new AppError('OCR_FALHOU',`OpenAI ${r.status}: ${t.slice(0,500)}`) }
  const j=await r.json(); const txt=outputText(j); if(!txt) throw new AppError('OCR_RESPOSTA_INVALIDA','Resposta sem output_text')
  let parsed:any; try{ parsed=JSON.parse(txt) }catch{ throw new AppError('OCR_RESPOSTA_INVALIDA',txt.slice(0,500)) }
  if(!Array.isArray(parsed.paginas)||parsed.paginas.length===0) throw new AppError('OCR_RESPOSTA_INVALIDA','Sem páginas')
  return {resultado:parsed,resposta_id:j.id ?? null,modelo:j.model ?? OPENAI_MODEL_OCR,uso:j.usage ?? {}}
}

async function processar(payload:any){
  const idVersao=payload.id_versao_documento ?? payload.entidade_id
  if(!idVersao) throw new AppError('OCR_FALHOU','Versão documental não informada')
  const { data:v,error:ev }=await sb.from('versoes_documento').select('*').eq('id',idVersao).single(); if(ev||!v) throw new AppError('OCR_FALHOU','Versão documental não encontrada')
  const { data:a,error:ea }=await sb.from('arquivos').select('*').eq('id',v.id_arquivo).single(); if(ea||!a) throw new AppError('OCR_FALHOU','Arquivo não encontrado')
  await marcarProcessamento(v,'processando',{codigo:'OCR_PROCESSANDO',titulo:'Leitura em andamento',mensagem:'O ContaOS está lendo o documento com inteligência artificial.'})
  const { data:blob,error:ed }=await sb.storage.from(a.bucket).download(a.path); if(ed||!blob) throw new AppError('OCR_FALHOU','Falha no download do Storage')
  const bytes=new Uint8Array(await blob.arrayBuffer()); const ai=await chamarOpenAI(a.nome_original,a.mime,bytes)
  const paginas=(ai.resultado.paginas as any[]).map((p:any,i:number)=>({id_organizacao:v.id_organizacao,id_contrato:v.id_contrato,id_versao_documento:v.id,numero_pagina:Number(p.pagina||i+1),texto_extraido:String(p.texto??''),metadados:{origem:'openai_ocr',modelo:ai.modelo,confianca:Number(p.confianca??0),observacoes:p.observacoes??[],idioma:ai.resultado.idioma??'pt-BR',resposta_openai_id:ai.resposta_id}}))
  await sb.from('paginas_documento').delete().eq('id_versao_documento',v.id); await sb.from('fragmentos_documento').delete().eq('id_versao_documento',v.id)
  const { error:ep }=await sb.from('paginas_documento').insert(paginas); if(ep) throw new AppError('OCR_FALHOU',ep.message)
  const frags:any[]=[]; let idx=0; for(const p of paginas){ for(const trecho of fragmentar(p.texto_extraido)){ frags.push({id_organizacao:v.id_organizacao,id_contrato:v.id_contrato,id_versao_documento:v.id,pagina_inicio:p.numero_pagina,pagina_fim:p.numero_pagina,indice_fragmento:idx++,texto:trecho,metadados:{origem:'openai_ocr',modelo:ai.modelo,idioma:ai.resultado.idioma??'pt-BR'}}) } }
  if(frags.length){ const {data:ins,error:ef}=await sb.from('fragmentos_documento').insert(frags).select('id'); if(ef) throw new AppError('OCR_FALHOU',ef.message); for(const f of ins??[]) await sb.rpc('worker_enfileirar_job',{p_fila:'embeddings',p_id_organizacao:v.id_organizacao,p_id_contrato:v.id_contrato,p_entidade_tipo:'fragmento_documento',p_entidade_id:f.id,p_payload:{entidade_tipo:'fragmento_documento',entidade_id:f.id},p_chave_idempotencia:`embed:fragmento:${f.id}`}) }
  await sb.rpc('worker_enfileirar_job',{p_fila:'ai',p_id_organizacao:v.id_organizacao,p_id_contrato:v.id_contrato,p_entidade_tipo:'extrair_documento',p_entidade_id:v.id,p_payload:{entidade_tipo:'extrair_documento',id_versao_documento:v.id},p_chave_idempotencia:`extrair-documento:${v.id}:${a.sha256}`})
  await marcarProcessamento(v,'concluido',{codigo:'OCR_CONCLUIDO',titulo:'Leitura concluída',mensagem:'O documento foi lido com sucesso e seguirá para análise.',paginas:paginas.length,fragmentos:frags.length,provedor:'openai',modelo:ai.modelo,uso:ai.uso})
  return {id_versao_documento:v.id,paginas:paginas.length,fragmentos:frags.length,modelo:ai.modelo}
}

Deno.serve(async(req:Request)=>{
  if(req.method!=='POST') return Response.json({ok:false,codigo:'METODO_INVALIDO',titulo:'Ação não permitida',mensagem:'Este processador aceita somente chamadas internas do ContaOS.'},{status:405})
  const token=req.headers.get('x-contaos-internal-token')??''; const {data:valido}=await sb.rpc('validar_token_interno',{p_token:token}); if(valido!==true) return Response.json({ok:false,codigo:'AUTH_ACESSO_NEGADO',titulo:'Acesso não permitido',mensagem:'Esta operação interna não está autorizada.'},{status:401})
  let body:any={}; try{body=await req.json()}catch{} const max=Math.min(Math.max(Number(body.max_jobs??1),1),3); const resultados:any[]=[]
  for(let i=0;i<max;i++){
    const {data:job,error}=await sb.rpc('worker_pull_job',{p_fila:'ocr',p_visibility_seconds:300}); if(error) return Response.json({ok:false,codigo:'OCR_FALHOU',titulo:'Leitura temporariamente indisponível',mensagem:amigavel('OCR_FALHOU')},{status:500}); if(!job) break
    try{ const r=await processar(job.payload??{}); await sb.rpc('worker_finalizar_job',{p_fila:'ocr',p_msg_id:Number(job.msg_id),p_sucesso:true,p_erro_codigo:null,p_erro_detalhe:null,p_max_tentativas:5}); resultados.push({ok:true,msg_id:job.msg_id,...r}) }
    catch(e){ const a=e instanceof AppError?e:new AppError('OCR_FALHOU',String(e)); await sb.rpc('worker_finalizar_job',{p_fila:'ocr',p_msg_id:Number(job.msg_id),p_sucesso:false,p_erro_codigo:a.codigo,p_erro_detalhe:a.message,p_max_tentativas:5}); resultados.push({ok:false,msg_id:job.msg_id,codigo:a.codigo,titulo:'Leitura não concluída',mensagem:amigavel(a.codigo)}) }
  }
  return Response.json({ok:true,fila:'ocr',provedor:'openai',modelo:OPENAI_MODEL_OCR,processados:resultados.length,resultados},{headers:{'content-type':'application/json; charset=utf-8'}})
})
