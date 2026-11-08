"""Real normative lifecycle, append-only history, CAS and tenant/role checks."""
from concurrent.futures import ThreadPoolExecutor
from p0_crud_global_hml import q,uid

def run(r):
    f=r.fixture;org,contract=f['org'],f['contract'];rpc='salvar_fonte_normativa_v107'
    create={'p_id_organizacao':org,'p_id_contrato':contract,'p_id_fonte':None,'p_tipo':'lei','p_titulo':f['prefix']+'Norma','p_referencia':'Own synthetic source','p_descricao':None,'p_situacao':'rascunho','p_versao_esperada':None,'p_chave_idempotencia':uid()}
    first=r.operation(rpc,create);source=r.entity('source',first['fonte']['id'])
    r.check('NORMATIVE_REPLAY_EXACT',r.operation(rpc,create)==first)
    r.operation(rpc,{**create,'p_titulo':'Different own payload'},status=409,code='PT409')
    edit={**create,'p_id_fonte':source,'p_titulo':f['prefix']+'Updated','p_versao_esperada':1,'p_chave_idempotencia':uid()}
    changed=r.operation(rpc,edit);r.check('NORMATIVE_UPDATE_VERSION',changed['fonte']['versao_registro']==2)
    r.operation(rpc,{**edit,'p_chave_idempotencia':uid()},status=409,code='PT409')
    commands=[{**edit,'p_versao_esperada':2,'p_titulo':f['prefix']+'Race '+str(i),'p_chave_idempotencia':uid()} for i in range(2)]
    with ThreadPoolExecutor(max_workers=2) as pool:
        result=list(pool.map(lambda p:r.request('/rest/v1/rpc/'+rpc,p,r.tokens['administrador']),commands))
    r.report['concurrency']=[{'http':s,'code':d.get('code') if isinstance(d,dict) else None} for s,d in result]
    r.check('NORMATIVE_CAS_RACE',sorted(s for s,_ in result)==[200,409] and all(s!=409 or d.get('code')=='PT409' for s,d in result))
    version={'p_id_organizacao':org,'p_id_fonte':source,'p_inicio_vigencia':'2026-01-01','p_fim_vigencia':None,'p_id_arquivo':None,'p_conteudo_texto':'Own synthetic formal text '+f['nonce'],'p_metadados':{},'p_chave_idempotencia':uid()}
    v1=r.operation('registrar_versao_fonte_v107',version)['versao'];vid=r.entity('version1',v1['id'])
    approve={'p_id_organizacao':org,'p_id_versao':vid,'p_hash_esperado':v1['hash'],'p_fundamento':'Own synthetic authorized review','p_chave_idempotencia':uid()}
    r.deny('aprovar_versao_fonte_v107',approve)
    r.operation('aprovar_versao_fonte_v107',{**approve,'p_hash_esperado':'0'*64,'p_chave_idempotencia':uid()},status=409,code='PT409')
    approved=r.operation('aprovar_versao_fonte_v107',approve)
    r.check('NORMATIVE_APPROVAL_REPLAY',r.operation('aprovar_versao_fonte_v107',approve)==approved)
    apply={'p_id_organizacao':org,'p_id_contrato':contract,'p_id_versao':vid,'p_aplicavel':True,'p_fundamento':'Own contract scope','p_atualizado_em_esperado':None,'p_chave_idempotencia':uid()}
    r.operation('definir_aplicabilidade_fonte_v107',apply)
    r.operation('definir_aplicabilidade_fonte_v107',{**apply,'p_aplicavel':False,'p_chave_idempotencia':uid()},status=409,code='PT409')
    v2=r.operation('registrar_versao_fonte_v107',{**version,'p_inicio_vigencia':'2027-01-01','p_conteudo_texto':'Own replacement formal text','p_chave_idempotencia':uid()})['versao'];r.entity('version2',v2['id'])
    r.check('NORMATIVE_READER_READ',len(r.read('fontes_normativas',{'select':'id','id':'eq.'+source},'leitor'))==1)
    r.check('NORMATIVE_TENANT_ISOLATED',r.read('fontes_normativas',{'select':'id','id':'eq.'+source},'usuario_b')==[])
    r.sql_check('NORMATIVE_SQL_PERSISTENCE','select exists(select 1 from public.fontes_normativas where id='+q(source)+' and id_organizacao='+q(org)+' and id_contrato='+q(contract)+' and versao_registro=3) and (select count(*) from public.versoes_fontes_normativas where id_fonte='+q(source)+')=2 and exists(select 1 from public.versoes_fontes_normativas where id='+q(vid)+' and hash='+q(v1['hash'])+' and aprovado_em is not null) and exists(select 1 from public.aplicabilidades_fonte where id_fonte_versao='+q(vid)+' and id_contrato='+q(contract)+' and aplicavel and aprovado_em is not null);')
    r.sql_check('NORMATIVE_AUDIT_PRESENT','select count(*)>=7 from public.eventos_auditoria where id_organizacao='+q(org)+" and evento like 'V107%';")
    admin=next(u for u in f['users'] if u['profile']=='administrador')
    r.sql('update public.vinculos_usuarios set ativo=false where id_organizacao='+q(org)+' and id_usuario='+q(admin['id'])+';')
    st,_=r.request('/auth/v1/user',token=r.tokens['administrador'],method='GET');r.check('NORMATIVE_REVOKED_JWT_STILL_VALID',st==200,st)
    r.operation(rpc,create,status=403,code='42501');r.check('NORMATIVE_REVOKED_SESSION_DENIED',True)
