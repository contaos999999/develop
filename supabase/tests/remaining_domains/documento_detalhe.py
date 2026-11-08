"""Review operations over explicit synthetic suggestions; AI generation not claimed."""
import json,threading
from concurrent.futures import ThreadPoolExecutor
from p0_crud_global_hml import q,uid
from remaining_domains.document_fixture import contract_document,wait_document

def run(r):
    f=r.fixture;doc=contract_document(r,'detail-source');version=doc['id_versao']
    r.report['limitations']=['Suggestion rows are declared synthetic prerequisites; this proves human review, not AI suggestion generation. Own queued extraction is quarantined before synthetic suggestions; running own work must drain.'];r.save('report.json',r.report)
    isolation=r.quarantine_document_jobs(f);r.report['synthetic_precondition_queue_isolation']=isolation
    r.check('DETAIL_SYNTHETIC_QUEUE_QUIESCED',isolation['active_jobs']==0)
    r.save('report.json',r.report)
    original=json.loads(r.sql('select to_jsonb(v) from public.versoes_documento v where id='+q(version)+';',True))
    suggestions={kind:r.entity('suggestion_'+kind,uid()) for kind in ('classificacao','metadado','obrigacao','prazo')}
    for kind,id in suggestions.items():
        r.sql('insert into public.sugestoes_extracao_documento(id,id_organizacao,id_contrato,id_versao_documento,tipo,conteudo,pagina,trecho_fonte,metadados) select '+','.join(q(v) for v in [id,f['org'],f['contract'],version,kind,'Own synthetic '+kind])+",1,'Own synthetic source',"+q('{"campos":{"own_field":"synthetic"}}')+'::jsonb where exists(select 1 from public.versoes_documento where id='+q(version)+' and id_organizacao='+q(f['org'])+' and id_contrato='+q(f['contract'])+');')
    vigor={'p_id_sugestao':suggestions['obrigacao'],'p_vigencia_inicio':'2026-01-01','p_vigencia_fim':None}
    r.deny('definir_vigencia_sugestao_extracao',vigor)
    r.operation('definir_vigencia_sugestao_extracao',{**vigor,'p_vigencia_fim':'2025-12-31'},status=400,code='PT400')
    r.operation('definir_vigencia_sugestao_extracao',vigor)
    r.check('DETAIL_VIGENCY_NOOP',r.operation('definir_vigencia_sugestao_extracao',vigor)['status']=='sem_alteracao')
    for kind in ('classificacao','metadado','obrigacao','prazo'):
        payload={'p_id_sugestao':suggestions[kind],'p_aprovar':kind!='prazo','p_conteudo_revisado':'Own reviewed '+kind,'p_categoria_revisada':'reviewed-own' if kind=='classificacao' else None,'p_id_requisito_revisado':None}
        r.deny('revisar_sugestao_extracao',payload)
        if kind=='metadado':
            start=threading.Barrier(2)
            def review_once(_):
                start.wait(timeout=10)
                return r.request('/rest/v1/rpc/revisar_sugestao_extracao',payload,r.tokens['administrador'])
            with ThreadPoolExecutor(max_workers=2) as pool:
                outcomes=list(pool.map(review_once,range(2)))
            for status,data in outcomes:
                code=data.get('code') if isinstance(data,dict) else None
                r.report['receipts'].append({'operation':'revisar_sugestao_extracao','role':'administrador','http':status,'code':code if code=='P0001' else None})
            r.check('DETAIL_METADATA_CONCURRENT_SINGLE_APPEND',sorted(x[0] for x in outcomes)==[200,400] and sum(x[0]==400 and isinstance(x[1],dict) and x[1].get('code')=='P0001' for x in outcomes)==1)
            receipt=next(data for status,data in outcomes if status==200)
        else:
            receipt=r.operation('revisar_sugestao_extracao',payload)
        r.check('DETAIL_REVIEW_'+kind.upper(),receipt['status']==('rejeitada' if kind=='prazo' else 'aprovada'))
        if kind=='metadado':
            reviewed=r.entity('reviewed_metadata_version',receipt['id_versao'])
            r.check('DETAIL_METADATA_APPEND_RECEIPT',reviewed!=version and receipt['id_documento']==doc['id_documento'] and receipt['numero_versao']==2)
            r.operation('revisar_sugestao_extracao',payload,status=400,code='P0001')
            stale=r.entity('stale_metadata_suggestion',uid())
            r.sql('insert into public.sugestoes_extracao_documento(id,id_organizacao,id_contrato,id_versao_documento,tipo,conteudo) values ('+','.join(q(x) for x in [stale,f['org'],f['contract'],version,'metadado','Own stale synthetic'])+');')
            r.operation('revisar_sugestao_extracao',{**payload,'p_id_sugestao':stale},status=409,code='PT409')
            wait_document(r,receipt,receipt['id_arquivo'],'contrato')
            current=json.loads(r.sql('select to_jsonb(v) from public.versoes_documento v where id='+q(version)+';',True))
            r.check('DETAIL_METADATA_OLD_ROW_IDENTICAL',current==original)
            r.sql_check('DETAIL_METADATA_APPEND_ONLY','select count(*)=2 and max(numero_versao)=2 from public.versoes_documento where id_documento_contrato='+q(doc['id_documento'])+';')
        if kind=='obrigacao':r.entity('draft_rule',receipt['id_regra_rascunho'])
    r.operation('definir_vigencia_sugestao_extracao',vigor,status=409,code='PT409')
    r.check('DETAIL_READER_PAGES',len(r.read('paginas_documento',{'select':'id','id_versao_documento':'eq.'+version},'leitor'))>=1)
    r.check('DETAIL_TENANT_ISOLATED',r.read('fragmentos_documento',{'select':'id','id_versao_documento':'eq.'+version},'usuario_b')==[] and r.read('sugestoes_extracao_documento',{'select':'id','id_versao_documento':'eq.'+version},'usuario_b')==[])
    r.sql_check('DETAIL_SQL_REVIEW','select exists(select 1 from public.documentos_contrato where id='+q(doc['id_documento'])+" and categoria='reviewed-own') and exists(select 1 from public.versoes_documento where id="+q(reviewed)+" and metadados_extraidos->>'own_field'='synthetic' and metadados_extraidos->>'resumo_revisado'='Own reviewed metadado') and exists(select 1 from public.regras_conformidade where id="+q(r.report['entities']['draft_rule'])+" and situacao='rascunho' and not efeito_portao) and (select count(*)=4 and count(*) filter(where status='aprovada')=3 and count(*) filter(where status='rejeitada')=1 from public.sugestoes_extracao_documento where id in ("+','.join(map(q,suggestions.values()))+')) and not exists(select 1 from public.regras_conformidade where configuracao->>\'id_sugestao\'='+q(suggestions['prazo'])+');')
    r.sql_check('DETAIL_SQL_VIGENCY','select count(*)=1 and bool_and(vigencia_inicio=\'2026-01-01\' and vigencia_fim is null) from public.sugestoes_extracao_documento where id='+q(suggestions['obrigacao'])+' and id_organizacao='+q(f['org'])+' and id_contrato='+q(f['contract'])+' and id_versao_documento='+q(version)+';')
    r.sql_check('DETAIL_AUDIT','select count(*)=5 from public.eventos_auditoria where id_organizacao='+q(f['org'])+" and evento in ('VigenciaSugestaoExtracaoDefinida','SugestaoExtracaoAprovada','SugestaoExtracaoRejeitada');")
