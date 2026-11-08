"""First creation and real authorization, never writes critical status directly."""
import hashlib,json
from p0_crud_global_hml import q,uid

def run(r):
    f=r.fixture
    state={'list':None,'version':None,'revision':None}
    def command(action,values):
        data=r.operation('executar_comando_lista_v1',{'p_id_organizacao':f['org'],'p_id_contrato':f['contract'],'p_id_lista':state['list'],'p_versao_esperada':state['revision'],'p_acao':action,'p_payload':values,'p_motivo':'Own competency snapshot precondition','p_request_id':uid()})
        state.update(list=data['lista']['id'],revision=data['lista']['versao_registro'])
        return data
    created=command('criar_lista',{'nome':f['prefix']+'Snapshot list','vigencia_inicio':'2026-01-01'})
    state['version']=created['id_versao']
    item=command('salvar_item',{'id_versao':state['version'],'codigo':'OWN-SNAPSHOT','descricao':'Own immutable snapshot requirement','obrigatorio':False,'aplicavel':True,'impeditivo':False})['id_item']
    command('publicar_versao',{'id_versao':state['version']})
    payload={'p_id_contrato':f['contract'],'p_competencia_referencia':'2026-01-01','p_periodo_inicio':None,'p_periodo_fim':None,'p_data_limite':None}
    r.deny('criar_competencia',payload)
    competence=r.entity('competence',r.operation('criar_competencia',payload))
    overview=r.operation('obter_visao_geral_competencia',{'p_id_competencia':competence})
    c=overview['competencia'];r.check('COMPETENCE_OVERVIEW_SCOPE',c['id']==competence and c['id_contrato']==f['contract'] and c['id_organizacao']==f['org'] and c['situacao']=='rascunho')
    r.check('COMPETENCE_NO_GATE_BYPASS',overview['allowed_actions']['apresentar'] is False)
    snapshot_query={'select':'id,id_organizacao,id_contrato,origem_id,origem_versao,codigo,descricao,hash_snapshot','id_competencia':'eq.'+competence,'order':'id'}
    snapshot=r.read('requisitos_competencia',snapshot_query)
    r.check('COMPETENCE_SNAPSHOT_MATERIALIZED',len(snapshot)==1 and snapshot[0]['origem_id']==item and snapshot[0]['origem_versao']=='1' and snapshot[0]['codigo']=='OWN-SNAPSHOT' and snapshot[0]['id_organizacao']==f['org'] and snapshot[0]['id_contrato']==f['contract'] and len(snapshot[0]['hash_snapshot'])==64)
    old_hash=hashlib.sha256(json.dumps(snapshot,sort_keys=True).encode()).hexdigest()
    next_version=command('criar_versao',{'id_versao_origem':state['version'],'vigencia_inicio':'2026-02-01'})['id_versao']
    clones=r.read('itens_lista',{'select':'id','id_versao_lista':'eq.'+next_version})
    assert len(clones)==1
    command('salvar_item',{'id_versao':next_version,'id_item':clones[0]['id'],'descricao':'Own draft replacement differs'})
    current=r.read('requisitos_competencia',snapshot_query)
    r.check('COMPETENCE_SNAPSHOT_IMMUTABLE',hashlib.sha256(json.dumps(current,sort_keys=True).encode()).hexdigest()==old_hash)
    r.check('COMPETENCE_SNAPSHOT_TENANT_ISOLATED',r.read('requisitos_competencia',snapshot_query,'usuario_b')==[])
    r.sql_check('COMPETENCE_SNAPSHOT_SQL','select count(*)=1 and bool_and(origem_id='+q(item)+" and origem_versao='1' and codigo='OWN-SNAPSHOT' and descricao='Own immutable snapshot requirement' and hash_snapshot~'^[0-9a-f]{64}$') from public.requisitos_competencia where id_competencia="+q(competence)+' and id_organizacao='+q(f['org'])+' and id_contrato='+q(f['contract'])+';')

    r.operation('obter_visao_geral_competencia',{'p_id_competencia':competence},'usuario_b',status=403,code='42501')
    r.check('COMPETENCE_READER_READ',len(r.read('competencias',{'select':'id','id':'eq.'+competence},'leitor'))==1)
    r.check('COMPETENCE_TENANT_ISOLATED',r.read('competencias',{'select':'id','id':'eq.'+competence},'usuario_b')==[])
    st,body=r.request('/rest/v1/rpc/criar_competencia',payload,r.tokens['administrador'])
    r.check('COMPETENCE_DUPLICATE_REJECTED',st==409 and isinstance(body,dict) and body.get('code')=='23505',st)
    st,body=r.request('/rest/v1/rpc/criar_competencia',{**payload,'p_competencia_referencia':'2026-02-02'},r.tokens['administrador'])
    r.check('COMPETENCE_INVALID_REFERENCE_REJECTED',st==400 and isinstance(body,dict) and body.get('code')=='P0001',st)
    r.sql_check('COMPETENCE_SQL_PERSISTENCE','select count(*)=1 and bool_and(id='+q(competence)+' and situacao=\'rascunho\' and periodo_inicio=\'2026-01-01\' and periodo_fim=\'2026-01-31\') from public.competencias where id_organizacao='+q(f['org'])+' and id_contrato='+q(f['contract'])+';')
    r.sql_check('COMPETENCE_REAL_AUDIT','select count(*)=1 from public.eventos_auditoria where id_organizacao='+q(f['org'])+' and id_entidade='+q(competence)+" and evento='CompetenciaCriada';")
