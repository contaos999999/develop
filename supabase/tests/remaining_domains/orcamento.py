"""Own physical source, draft-only edits/removal, publication and immutable history."""
import json
import time
from p0_crud_global_hml import q,uid

def approve_source(r,file,timeout=300,pause=time.sleep):
    """Register this budget's own source; wait for the normal document worker only."""
    f=r.fixture
    receipt=r.operation('criar_documento_contrato_completo',{'p_id_contrato':f['contract'],'p_tipo':'proposta_orcamentaria','p_titulo':f['prefix']+'Budget source','p_categoria':'orcamento','p_vigencia_inicio':'2026-01-01','p_vigencia_fim':None,'p_observacoes':'Own synthetic budget prerequisite','p_id_arquivo':file,'p_chave_idempotencia':uid()})
    document=r.entity('source_document',receipt['id_documento']);version=r.entity('source_document_version',receipt['id_versao']);job=r.entity('source_document_job',receipt['id_job'])
    query="select json_build_object('owned',count(*)=1,'ready',coalesce(bool_and(a.status_seguranca='aprovado' and p.status='concluido' and e.status='concluido' and exists(select 1 from public.paginas_documento where id_versao_documento=v.id) and exists(select 1 from public.fragmentos_documento where id_versao_documento=v.id)),false),'failed',coalesce(bool_or(a.status_seguranca in ('bloqueado','quarentena') or p.status in ('falhou','cancelado') or e.status in ('falhou','cancelado')),false)) from public.arquivos a join public.versoes_documento v on v.id_arquivo=a.id and v.id_organizacao=a.id_organizacao and v.id_contrato=a.id_contrato join public.documentos_contrato d on d.id=v.id_documento_contrato and d.id_contrato=a.id_contrato and d.id_organizacao=a.id_organizacao join public.processamentos_documento p on p.id_versao_documento=v.id and p.etapa='documents' join public.execucoes_assincronas e on e.entidade_id=v.id and e.entidade_tipo='versao_documento' and e.fila='documents' and e.id_organizacao=a.id_organizacao and e.id_contrato=a.id_contrato where a.id="+q(file)+' and a.id_organizacao='+q(f['org'])+' and a.id_contrato='+q(f['contract'])+' and d.id='+q(document)+' and v.id='+q(version)+' and e.id='+q(job)+' and v.hash=a.sha256;'
    deadline=time.monotonic()+timeout
    while True:
        result=json.loads(r.sql(query,True))
        assert set(result)=={'owned','ready','failed'} and all(type(x) is bool for x in result.values())
        assert result['owned'] and not result['failed'],'Own budget source processing failed'
        if result['ready']:break
        assert time.monotonic()<deadline,'Own budget source worker timed out'
        pause(2)
    r.check('BUDGET_SOURCE_WORKER_READY',True)

def run(r):
    f=r.fixture;org=f['org'];rpc='salvar_proposta_orcamentaria_v108'
    cmd={'p_id_organizacao':org,'p_id_contrato':f['contract'],'p_id_proposta':None,'p_titulo':f['prefix']+'Budget','p_versao_esperada':None,'p_chave_idempotencia':uid()}
    r.deny(rpc,cmd)
    first=r.operation(rpc,cmd);proposal=r.entity('proposal',first['proposta']['id'])
    r.check('BUDGET_REPLAY_EXACT',r.operation(rpc,cmd)==first)
    edit={**cmd,'p_id_proposta':proposal,'p_titulo':f['prefix']+'Edited budget','p_versao_esperada':1,'p_chave_idempotencia':uid()}
    r.operation(rpc,edit);r.operation(rpc,{**edit,'p_chave_idempotencia':uid()},status=409,code='PT409')
    file=r.upload('budget-source');r.entity('source_file',file)
    approve_source(r,file)
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
