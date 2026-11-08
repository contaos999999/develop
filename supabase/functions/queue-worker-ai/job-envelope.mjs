// worker_pull_job returns metadata outside, and the canonical entity inside payload.
const anchors=Object.freeze({extrair_documento:'id_versao_documento',execucao_analise:'id_execucao',gerar_parecer_interno:'id_competencia',extrair_diligencia:'id_parecer_contratante',revalidar_apontamento:'id_apontamento',minuta_contestacao:'id_apontamento',aprendizado_desfecho:'id_desfecho'});
const uuid=value=>typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
export function normalizeAIJob(job){
 if(!object(job)||!object(job.payload)||!Number.isSafeInteger(job.msg_id)||job.msg_id<=0||!Number.isSafeInteger(job.read_ct)||job.read_ct<=0||!uuid(job.id_execucao))throw new Error('AI_JOB_ENVELOPE_INVALID');
 const p=job.payload;const type=p.entidade_tipo;
 if(typeof type!=='string'||!Object.hasOwn(anchors,type)||!uuid(p.entidade_id)||!uuid(p.id_organizacao)||(p.id_contrato!==null&&!uuid(p.id_contrato)))throw new Error('AI_JOB_ENTITY_INVALID');
 for(const key of ['entidade_tipo','entidade_id','id_organizacao','id_contrato'])if(Object.hasOwn(job,key)&&job[key]!==p[key])throw new Error('AI_JOB_ENVELOPE_CONFLICT');
 const anchor=anchors[type];if(Object.hasOwn(p,anchor)&&p[anchor]!==p.entidade_id)throw new Error('AI_JOB_TARGET_CONFLICT');
 for(const [key,value] of Object.entries(p))if(key.startsWith('id_')&&value!==null&&!uuid(value))throw new Error('AI_JOB_ID_INVALID');
 if(type==='aprendizado_desfecho'&&!uuid(p.id_precedente))throw new Error('AI_JOB_PRECEDENT_INVALID');
 // Outer id_execucao is the asynchronous job. Payload id_execucao is the analysis.
 return {...job,entidade_tipo:type,entidade_id:p.entidade_id,id_organizacao:p.id_organizacao,id_contrato:p.id_contrato,payload:{...p}};
}
