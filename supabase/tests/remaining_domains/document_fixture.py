"""Own domain prerequisites. Normal worker only; no approved status writes."""
import json,time
from p0_crud_global_hml import q,uid

def competence(r,reference='2026-01-01'):
    return r.entity('competence',r.operation('criar_competencia',{'p_id_contrato':r.fixture['contract'],'p_competencia_referencia':reference,'p_periodo_inicio':None,'p_periodo_fim':None,'p_data_limite':None}))

def wait_document(r,receipt,file,kind,timeout=300,pause=time.sleep):
    assert kind in ('contrato','competencia');f=r.fixture
    document=receipt['id_documento'];version=receipt['id_versao'];job=receipt['id_job']
    r.entity('document_'+kind,document);r.entity('version_'+kind,version);r.entity('job_'+kind,job)
    table='documentos_'+kind;column='id_documento_'+kind
    query="select json_build_object('owned',count(*)=1,'ready',coalesce(bool_and(a.status_seguranca='aprovado' and p.status='concluido' and e.status='concluido' and exists(select 1 from public.paginas_documento where id_versao_documento=v.id) and exists(select 1 from public.fragmentos_documento where id_versao_documento=v.id)),false),'failed',coalesce(bool_or(a.status_seguranca in ('bloqueado','quarentena') or p.status in ('falhou','cancelado') or e.status in ('falhou','cancelado')),false)) from public.arquivos a join public.versoes_documento v on v.id_arquivo=a.id and v.id_organizacao=a.id_organizacao and v.id_contrato=a.id_contrato join public."+table+' d on d.id=v.'+column+" and d.id_organizacao=a.id_organizacao and d.id_contrato=a.id_contrato join public.processamentos_documento p on p.id_versao_documento=v.id and p.etapa='documents' join public.execucoes_assincronas e on e.id="+q(job)+" and e.fila='documents' and e.entidade_tipo='versao_documento' and e.entidade_id=v.id and e.id_organizacao=a.id_organizacao and e.id_contrato=a.id_contrato where a.id="+q(file)+' and d.id='+q(document)+' and v.id='+q(version)+' and a.id_organizacao='+q(f['org'])+' and a.id_contrato='+q(f['contract'])+' and v.hash=a.sha256;'
    deadline=time.monotonic()+timeout
    while True:
        state=json.loads(r.sql(query,True));assert set(state)=={'owned','ready','failed'} and all(type(x) is bool for x in state.values())
        assert state['owned'] and not state['failed'],'Own normal document worker failed'
        if state['ready']:break
        assert time.monotonic()<deadline,'Own normal document worker timeout'
        pause(2)
    r.check('OWN_DOCUMENT_WORKER_READY',True)
    return receipt

def contract_document(r,label):
    f=r.fixture;file=r.upload(label)
    payload={'p_id_contrato':f['contract'],'p_tipo':'outro','p_titulo':f['prefix']+label,'p_categoria':'original','p_vigencia_inicio':'2026-01-01','p_vigencia_fim':None,'p_observacoes':'Own prerequisite, no certification of AI generation','p_id_arquivo':file,'p_chave_idempotencia':uid()}
    receipt=r.operation('criar_documento_contrato_completo',payload)
    return wait_document(r,receipt,file,'contrato')
