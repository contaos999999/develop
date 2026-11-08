"""Own administrative binding lifecycle and Master matrix CAS without permission delta."""
import re
from p0_crud_global_hml import q,uid

def lookup_existing_user(r,user):
    f=r.fixture
    payload={'id_organizacao':f['org'],'email':user['email'],'nome':f['prefix']+'Existing own account','chave_idempotencia':uid()}
    def call(role,expected):
        st,data=r.request('/functions/v1/admin-invite-user',payload,r.tokens.get(role))
        code=data.get('codigo') if isinstance(data,dict) else None
        r.report['receipts'].append({'operation':'admin-invite-user','role':role,'http':st,'code':code if isinstance(code,str) and re.fullmatch('[A-Z0-9_]{1,50}',code) else None})
        r.check('ADMIN_EXISTING_EDGE_'+role.upper(),st==expected,st)
        return data
    for role in ('leitor','usuario_b'):
        r.check('ADMIN_EXISTING_EDGE_RBAC_DENIED',call(role,403).get('codigo')=='AUTH_ACESSO_NEGADO')
    call('anon',401)
    result=call('administrador',200)
    r.check('ADMIN_EXISTING_EDGE_NO_EMAIL',result.get('ok') is True and result.get('codigo')=='USUARIO_EXISTENTE' and result.get('convite_enviado') is False and result['usuario']['id_usuario']==user['id'])
    r.check('ADMIN_EXISTING_EDGE_REPLAY',call('administrador',200)==result)
    payload['nome']=f['prefix']+'Different payload';response=call('administrador',409)
    r.check('ADMIN_EXISTING_EDGE_CONFLICT',response['codigo']=='CONFLITO_IDEMPOTENCIA')
    r.sql_check('ADMIN_SQL_EDGE_RECEIPT','select count(*)=1 and bool_and(status=\'concluido\' and resposta->>\'codigo\'=\'USUARIO_EXISTENTE\' and resposta#>>\'{usuario,id_usuario}\'='+q(user['id'])+' and resposta->>\'convite_enviado\'=\'false\') from public.comandos_idempotentes where id_organizacao='+q(f['org'])+" and comando='adm01.convidar_usuario' and chave="+q(payload['chave_idempotencia'])+';')

def run(r):
    f=r.fixture;reader=next(u for u in f['users'] if u['profile']=='leitor');user=reader['id'];org=f['org']
    lookup_existing_user(r,reader)
    existing=r.read('vinculos_usuarios',{'select':'id,versao_registro','id_usuario':'eq.'+user,'id_organizacao':'eq.'+org})[0]
    payload={'p_id_organizacao':org,'p_id_usuario':user,'p_email':reader['email'],'p_perfil':'leitor','p_escopo_todos_contratos':False,'p_ativo':True,'p_ids_contratos_ativar':[f['contract']],'p_ids_contratos_revogar':[],'p_versao_esperada':existing['versao_registro'],'p_chave_idempotencia':uid()}
    r.deny('salvar_vinculo_usuario_adm',payload)
    first=r.operation('salvar_vinculo_usuario_adm',payload);link=r.entity('binding',first['vinculo']['id'])
    r.check('ADMIN_BINDING_REPLAY',r.operation('salvar_vinculo_usuario_adm',payload)==first)
    r.operation('salvar_vinculo_usuario_adm',{**payload,'p_ativo':False},status=409,code='PT409')
    r.operation('salvar_vinculo_usuario_adm',{**payload,'p_chave_idempotencia':uid()},status=409,code='PT409')
    scope={'p_id_organizacao':org,'p_id_usuario':user,'p_pagina':1,'p_tamanho_pagina':25,'p_busca':None}
    r.deny('listar_escopo_contratos_usuario_adm',scope)
    listing=r.operation('listar_escopo_contratos_usuario_adm',scope)
    r.check('ADMIN_SCOPED_CONTRACT',listing['total']==1 and listing['itens'][0]['id']==f['contract'] and listing['itens'][0]['selecionado'] is True and listing['itens'][0]['acesso_efetivo'] is True)
    r.check('ADMIN_READER_SCOPED_READ',len(r.read('contratos',{'select':'id','id':'eq.'+f['contract']},'leitor'))==1)
    revoke={**payload,'p_ids_contratos_ativar':[],'p_ids_contratos_revogar':[f['contract']],'p_versao_esperada':first['vinculo']['versao_registro'],'p_chave_idempotencia':uid()}
    revoked=r.operation('salvar_vinculo_usuario_adm',revoke)
    r.check('ADMIN_SCOPE_REVOKED_REAL_JWT',r.read('contratos',{'select':'id','id':'eq.'+f['contract']},'leitor')==[])
    disable={**revoke,'p_ativo':False,'p_versao_esperada':revoked['vinculo']['versao_registro'],'p_chave_idempotencia':uid()}
    r.operation('salvar_vinculo_usuario_adm',disable)
    r.operation('listar_escopo_contratos_usuario_adm',scope,'leitor',status=403,code='42501')
    matrix=r.operation('obter_matriz_rbac_master',{},'master');entry=matrix['permissoes'][0]
    # Deliberately writes the CURRENT value under version CAS. No permission is granted or revoked.
    command={'p_versao_esperada':matrix['versao'],'p_request_id':uid(),'p_alteracoes':[entry]}
    for role in ('administrador','leitor','usuario_b'):
        r.operation('atualizar_matriz_rbac_master',command,role,status=403,code='42501')
    result=r.operation('atualizar_matriz_rbac_master',command,'master')
    r.check('ADMIN_MATRIX_REPLAY',r.operation('atualizar_matriz_rbac_master',command,'master')==result)
    r.operation('atualizar_matriz_rbac_master',{**command,'p_request_id':uid()},'master',status=409,code='PT409')
    current=r.operation('obter_matriz_rbac_master',{},'master')
    r.check('ADMIN_MATRIX_NO_PERMISSION_DELTA',current['versao']==matrix['versao']+1 and current['permissoes']==matrix['permissoes'])
    r.sql_check('ADMIN_SQL_BINDING','select exists(select 1 from public.vinculos_usuarios where id='+q(link)+' and id_usuario='+q(user)+' and id_organizacao='+q(org)+" and perfil='leitor' and not ativo and not escopo_todos_contratos and fim_em is not null) and not exists(select 1 from public.vinculos_usuario_contratos where id_vinculo_usuario="+q(link)+' and ativo);')
    r.sql_check('ADMIN_SQL_MATRIX_RECEIPT','select exists(select 1 from privado.rbac_comandos where request_id='+q(command['p_request_id'])+' and id_usuario='+q(next(u['id'] for u in f['users'] if u['profile']=='master'))+') and exists(select 1 from public.eventos_auditoria where id_entidade='+q(command['p_request_id'])+" and evento='MatrizRbacAtualizada');")
    r.sql_check('ADMIN_AUDIT','select count(*)=3 from public.eventos_auditoria where id_organizacao='+q(org)+' and id_entidade='+q(link)+" and evento='VinculoUsuarioAdministrativoSalvo';")
    r.report['limitations']=['SMTP invitation delivery is not claimed. This test uses only existing own identities; no invitation is sent to a third party. Matrix permission values are unchanged; only version CAS/audit/no-op save are exercised.'];r.save('report.json',r.report)
