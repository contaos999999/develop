// Real PostgreSQL evaluation of exact migration predicates; synthetic inputs only.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const {PGlite}=await import(process.env.CONTAOS_PGLITE_MODULE);
const source=readFileSync('supabase/migrations/20261108114652_p0_null_pagination_guard.sql','utf8');
const db=new PGlite();let count=0;
try {
 for(const [name,params,defaults,maxima] of [
  ['privado.obter_documentos_competencia_v115',['p_documentos_offset','p_documentos_limite','p_requisitos_offset','p_requisitos_limite'],[0,25,0,25],[0,100,0,100]],
  ['public.obter_analise_competencia_v116',['p_resultados_offset','p_resultados_limite','p_execucoes_offset','p_execucoes_limite','p_apontamentos_offset','p_apontamentos_limite'],[0,25,0,10,0,25],[0,100,0,50,0,100]]
 ]) {
  const start=source.indexOf('CREATE OR REPLACE FUNCTION '+name+'(');
  const body=source.slice(start,source.indexOf('$function$',source.indexOf('AS $function$',start)+13));
  const predicate=body.match(/if (p_(?:documentos|resultados)_offset is null[\s\S]*?) then/i)?.[1];
  assert(predicate,name);
  let sql=predicate;
  params.forEach((param,i)=>{sql=sql.replace(new RegExp('\\b'+param+'\\b','g'),'$'+(i+1)+'::integer');});
  const check=async(values,expected,label)=>{const actual=(await db.query('select ('+sql+') as rejected',values)).rows[0].rejected;assert.equal(actual,expected,name+': '+label);count++;};
  await check(defaults,false,'defaults');await check(maxima,false,'maximum');
  for(let i=0;i<params.length;i++){
   const values=[...defaults];values[i]=null;await check(values,true,'null '+params[i]);
   const invalid=[...defaults];invalid[i]=i%2===0?-1:0;await check(invalid,true,'lower bound '+params[i]);
   if(i%2){invalid[i]=maxima[i]+1;await check(invalid,true,'upper bound '+params[i]);}
  }
 }
} finally {await db.close();}
console.log('LOCAL_NULL_PAGINATION_CASES='+count+'; HML=NOT_CHANGED');
