"""Own physical source, draft-only edits/removal, publication and immutable history."""
from p0_crud_global_hml import q,uid

def run(r):
    f=r.fixture;org=f['org'];rpc='salvar_proposta_orcamentaria_v108'
    cmd={'p_id_organizacao':org,'p_id_contrato':f['contract'],'p_id_proposta':None,'p_titulo':f['prefix']+'Budget','p_versao_esperada':None,'p_chave_idempotencia':uid()}
    r.deny(rpc,cmd)
    first=r.operation(rpc,cmd);proposal=r.entity('proposal',first['proposta']['id'])
    r.check('BUDGET_REPLAY_EXACT',r.operation(rpc,cmd)==first)
    edit={**cmd,'p_id_proposta':proposal,'p_titulo':f['prefix']+'Edited budget','p_versao_esperada':1,'p_chave_idempotencia':uid()}
    r.operation(rpc,edit);r.operation(rpc,{**edit,'p_chave_idempotencia':uid()},status=409,code='PT409')
    file=r.upload('budget-source');r.entity('source_file',file)
    version={'p_id_organizacao':org,'p_id_proposta':proposal,'p_vigencia_inicio':'2026-01-01','p_vigencia_fim':None,'p_id_arquivo_origem':file,'p_chave_idempotencia':uid()}
    v1=r.operation('registrar_versao_proposta_v108',version)['versao'];vid=r.entity('version1',v1['id'])
    line={'p_id_organizacao':org,'p_id_versao_proposta':vid,'p_id_linha':None,'p_codigo':'OWN','p_grupo':'Pessoal','p_rubrica':'Own staff','p_subrubrica':None,'p_descricao':None,'p_valor_mensal':100,'p_valor_anual':1200,'p_permite_remanejamento':False,'p_limite_remanejamento_percentual':None,'p_observacoes':None,'p_versao_esperada':None,'p_chave_idempotencia':uid()}
    saved=r.operation('salvar_linha_orcamentaria_v108',line);row=saved['linha'];r.entity('line',row['id'])
    editline={**line,'p_id_linha':row['id'],'p_valor_mensal':200,'p_valor_anual':2400,'p_versao_esperada':row['versao_registro'],'p_chave_idempotencia':uid()}
    saved=r.operation('salvar_linha_orcamentaria_v108',editline)
    r.operation('salvar_linha_orcamentaria_v108',{**editline,'p_chave_idempotencia':uid()},status=409,code='PT409')
    temp=r.operation('salvar_linha_orcamentaria_v108',{**line,'p_codigo':'TEMP','p_chave_idempotencia':uid()})['linha']
    r.operation('remover_linha_orcamentaria_v108',{'p_id_organizacao':org,'p_id_versao_proposta':vid,'p_id_linha':temp['id'],'p_versao_esperada':temp['versao_registro'],'p_chave_idempotencia':uid()})
    current=r.read('versoes_proposta',{'select':'id,hash','id':'eq.'+vid})[0]
    publish={'p_id_organizacao':org,'p_id_versao':vid,'p_hash_esperado':current['hash'],'p_fundamento':'Own synthetic authorized budget review','p_chave_idempotencia':uid()}
    r.deny('publicar_versao_proposta_v108',publish)
    r.operation('publicar_versao_proposta_v108',{**publish,'p_hash_esperado':'0'*64,'p_chave_idempotencia':uid()},status=409,code='PT409')
    r.operation('publicar_versao_proposta_v108',publish)
    r.operation('salvar_linha_orcamentaria_v108',{**editline,'p_versao_esperada':saved['linha']['versao_registro'],'p_chave_idempotencia':uid()},status=409,code='PT409')
    v2=r.operation('registrar_versao_proposta_v108',{**version,'p_vigencia_inicio':'2026-07-01','p_chave_idempotencia':uid()})['versao'];r.entity('version2',v2['id'])
    r.check('BUDGET_READER_READ',len(r.read('propostas_orcamentarias',{'select':'id','id':'eq.'+proposal},'leitor'))==1)
    r.check('BUDGET_TENANT_ISOLATED',r.read('propostas_orcamentarias',{'select':'id','id':'eq.'+proposal},'usuario_b')==[])
    r.sql_check('BUDGET_SQL_PERSISTENCE','select (select count(*) from public.versoes_proposta where id_proposta='+q(proposal)+')=2 and exists(select 1 from public.versoes_proposta where id='+q(vid)+" and situacao='publicada' and aprovado_em is not null) and exists(select 1 from public.versoes_proposta where id="+q(v2['id'])+" and situacao='rascunho') and (select count(*) from public.linhas_orcamentarias where id_versao_proposta="+q(vid)+')=1 and exists(select 1 from public.linhas_orcamentarias where id='+q(row['id'])+' and valor_mensal_previsto=200 and valor_anual_previsto=2400);')
    r.sql_check('BUDGET_AUDIT_PRESENT','select count(*)>=8 from public.eventos_auditoria where id_organizacao='+q(org)+" and evento like 'V108%';")
