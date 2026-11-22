import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
const url=Deno.env.get('SUPABASE_URL')!
const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}})
const send=(body:unknown,status=200)=>Response.json(body,{status,headers:{'cache-control':'no-store'}})
Deno.serve(async(req)=>{
 if(req.method!=='POST')return send({ok:false,codigo:'METODO_INVALIDO'},405)
 const token=req.headers.get('x-contaos-internal-token')??''
 const {data:valido}=await db.rpc('validar_token_interno',{p_token:token})
 if(valido!==true)return send({ok:false,codigo:'ACESSO_NEGADO'},403)
 const {data:job,error:pullError}=await db.rpc('worker_pull_historico_hml')
 if(pullError)return send({ok:false,codigo:'FILA_INDISPONIVEL'},503)
 if(!job)return send({ok:true,processados:0})
 const msgId=job.msg_id;const p=job.payload??{}
 try{
  const {data:r,error:re}=await db.from('relatorios_historicos_contratante').select('id,id_organizacao,id_contrato,id_arquivo').eq('id',p.id_relatorio).single()
  const {data:v,error:ve}=await db.from('versoes_documento').select('id,id_organizacao,id_contrato,id_arquivo').eq('id',p.id_versao_documento).single()
  if(re||ve||!r||!v||r.id_arquivo!==v.id_arquivo||r.id_contrato!==v.id_contrato||r.id_organizacao!==v.id_organizacao)throw Error('VINCULO_INVALIDO')
  const {data:processamento}=await db.from('processamentos_documento').select('status').eq('id_versao_documento',v.id).eq('status','concluido').limit(1)
  if(!processamento?.length)throw Error('DOCUMENTO_NAO_PROCESSADO')
  const {data:paginas,error:pe}=await db.from('paginas_documento').select('numero_pagina,texto_extraido').eq('id_versao_documento',v.id).order('numero_pagina')
  if(pe||!paginas?.length)throw Error('TEXTO_NAO_DISPONIVEL')
  const itens:{id_organizacao:string,id_contrato:string,id_relatorio:string,problema:string,item:string,fonte_pagina:number,fonte_trecho:string}[]=[]
  for(const pg of paginas){
   const linhas=String(pg.texto_extraido??'').split(/\r?\n/).map(s=>s.trim()).filter(Boolean)
   for(const linha of linhas){
    const match=linha.match(/^(?:apontamento|constata[cç][aã]o|n[aã]o conformidade|item)\s*(?:n[ºo.]?\s*)?(\d+[.\d]*)\s*[:.)-]\s*(.{15,})$/i)
    if(match&&itens.length<300)itens.push({id_organizacao:r.id_organizacao,id_contrato:r.id_contrato,id_relatorio:r.id,problema:match[2].slice(0,5000),item:match[1],fonte_pagina:pg.numero_pagina,fonte_trecho:linha.slice(0,1200)})
   }
  }
  // Do not manufacture findings when the document lacks verifiable item markers.
  const {data:existing,error:ee}=await db.from('apontamentos_historicos').select('id,item,fonte_pagina,problema').eq('id_relatorio',r.id)
  if(ee)throw Error('CONSULTA_APONTAMENTOS_FALHOU')
  const old=new Set((existing??[]).map(x=>`${x.item}:${x.fonte_pagina}:${x.problema}`))
  const novos=itens.filter(x=>!old.has(`${x.item}:${x.fonte_pagina}:${x.problema}`))
  if(novos.length){const {error:ie}=await db.from('apontamentos_historicos').insert(novos);if(ie)throw Error('INSERCAO_APONTAMENTOS_FALHOU')}
  const {error:ue}=await db.from('relatorios_historicos_contratante').update({status_processamento:'concluido'}).eq('id',r.id)
  if(ue)throw Error('STATUS_HISTORICO_FALHOU')
  const {error:fe}=await db.rpc('worker_finalizar_historico_hml',{p_msg_id:msgId,p_sucesso:true})
  if(fe)throw Error('FINALIZACAO_FILA_FALHOU')
  return send({ok:true,processados:1,apontamentos_novos:novos.length,revisao_humana_necessaria:true})
 }catch(err){
  const codigo=String(err instanceof Error?err.message:err).slice(0,120)
  await db.from('relatorios_historicos_contratante').update({status_processamento:'falhou'}).eq('id',p.id_relatorio)
  await db.rpc('worker_finalizar_historico_hml',{p_msg_id:msgId,p_sucesso:false,p_erro:codigo})
  return send({ok:false,codigo:'HISTORICO_PROCESSAMENTO_FALHOU',detalhe:codigo},500)
 }
})