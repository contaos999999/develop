"""Human approval over explicit candidate fixture and real formal source."""
import json
from p0_crud_global_hml import q,uid

def run(r):
    f=r.fixture;org=f['org'];contract=f['contract']
    create={'p_id_organizacao':org,'p_id_contrato':contract,'p_id_fonte':None,'p_tipo':'lei','p_titulo':f['prefix']+'Preventive formal source','p_referencia':'Own synthetic formal prerequisite','p_descricao':None,'p_situacao':'rascunho','p_versao_esperada':None,'p_chave_idempotencia':uid()}
    r.deny('salvar_fonte_normativa_v107',create)
    source=r.operation('salvar_fonte_normativa_v107',create)['fonte']['id'];r.entity('source',source)
    version=r.operation('registrar_versao_fonte_v107',{'p_id_organizacao':org,'p_id_fonte':source,'p_inicio_vigencia':'2026-01-01','p_fim_vigencia':None,'p_id_arquivo':None,'p_conteudo_texto':'Own independent formal source '+f['nonce'],'p_metadados':{},'p_chave_idempotencia':uid()})['versao'];r.entity('formal_version',version['id'])
    r.operation('aprovar_versao_fonte_v107',{'p_id_organizacao':org,'p_id_versao':version['id'],'p_hash_esperado':version['hash'],'p_fundamento':'Own formal review for synthetic candidate','p_chave_idempotencia':uid()})
    r.report['limitations']=['Candidate rows are explicit synthetic preconditions; this proves approval, not automatic candidate generation. Legacy approval errors use HTTP400/P0001; unchanged SQL state is independently checked.'];r.save('report.json',r.report)
    candidate=r.entity('candidate',uid());missing=r.entity('missing_source_candidate',uid())
    for id,formal in ((candidate,version['id']),(missing,None)):
        r.sql('insert into public.regras_preventivas(id,id_organizacao,id_contrato,codigo_regra,descricao,efeito,criticidade,escopo_aplicacao,vigencia_inicio,id_fonte_formal_versao) select '+','.join(q(v) if v is not None else 'null' for v in [id,org,contract,'OWN-'+id,'Own synthetic preventive candidate','alerta','media','contrato','2026-01-01',formal])+' where exists(select 1 from public.contratos where id='+q(contract)+' and id_organizacao='+q(org)+');')
    payload={'p_id_regra_preventiva':candidate,'p_parecer':'Own authorized human review'}
    for role in ('leitor','usuario_b'):
        r.operation('aprovar_regra_preventiva',payload,role,status=400,code='P0001')
    r.sql_check('PREVENTIVE_DENIAL_UNCHANGED','select count(*)=1 and bool_and(situacao=\'candidata\' and aprovada_por is null and aprovada_em is null) from public.regras_preventivas where id='+q(candidate)+';')
    r.operation('aprovar_regra_preventiva',{**payload,'p_id_regra_preventiva':missing},status=400,code='P0001')
    review=r.entity('review',r.operation('aprovar_regra_preventiva',payload))
    r.operation('aprovar_regra_preventiva',payload,status=400,code='P0001')
    r.check('PREVENTIVE_READER_READ',len(r.read('regras_preventivas',{'select':'id','id':'eq.'+candidate},'leitor'))==1)
    r.check('PREVENTIVE_TENANT_ISOLATED',r.read('regras_preventivas',{'select':'id','id':'eq.'+candidate},'usuario_b')==[])
    # Direct authenticated mutation must not activate a synthetic candidate.
    st,data=r.request('/rest/v1/regras_preventivas?id=eq.'+missing,{'situacao':'ativa'},r.tokens['administrador'],method='PATCH')
    r.check('PREVENTIVE_NO_DIRECT_PROMOTION',st in (200,204,403))
    r.sql_check('PREVENTIVE_SQL_APPROVAL','select exists(select 1 from public.regras_preventivas where id='+q(candidate)+" and situacao='ativa' and aprovada_por="+q(next(u['id'] for u in f['users'] if u['profile']=='administrador'))+' and aprovada_em is not null and id_fonte_formal_versao='+q(version['id'])+') and exists(select 1 from public.revisoes_regras_preventivas where id='+q(review)+' and id_regra='+q(candidate)+" and decisao='aprovada') and exists(select 1 from public.regras_preventivas where id="+q(missing)+" and situacao='candidata' and aprovada_em is null);")
    r.sql_check('PREVENTIVE_AUDIT','select count(*)=1 from public.eventos_auditoria where id_organizacao='+q(org)+' and id_entidade='+q(candidate)+" and evento='RegraPreventivaAprovada';")
