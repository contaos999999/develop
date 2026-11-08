"""One dependent flow proves analysis -> opinion -> approval -> stale fence -> protocol.
No critical state or AI result is written through SQL. Human review is an authorized
synthetic test decision supported by its own physical page, not a legal opinion.
"""
import json,time
from p0_crud_global_hml import q,uid
from remaining_domains.document_fixture import competence,wait_document

def wait_sql(r,query,label,timeout=360,pause=time.sleep):
    end=time.monotonic()+timeout
    while True:
        state=json.loads(r.sql(query,True))
        assert set(state)=={'owned','ready','failed'} and all(type(v) is bool for v in state.values())
        assert state['owned'] and not state['failed'],label+' failed'
        if state['ready']:break
        assert time.monotonic()<end,label+' timeout'
        pause(2)
    r.check(label,True)

def analyze_review_opinion(r,c,req,version,round):
    f=r.fixture
    payload={'p_id_competencia':c,'p_tipo':'completa'}
    r.deny('solicitar_analise_competencia',payload)
    execution=r.entity('analysis_'+str(round),r.operation('solicitar_analise_competencia',payload))
    wait_sql(r,"select json_build_object('owned',count(*)=1,'ready',coalesce(bool_and(a.status='concluida' and e.status='concluido' and a.provedor='openai' and length(a.modelo)>0 and exists(select 1 from public.retornos_modelo where id_execucao_analise=a.id and status='concluido')),false),'failed',coalesce(bool_or(a.status='falhou' or e.status in ('falhou','cancelado')),false)) from public.execucoes_analise a join public.execucoes_assincronas e on e.entidade_tipo='execucao_analise' and e.entidade_id=a.id and e.id_organizacao=a.id_organizacao and e.id_contrato=a.id_contrato and e.fila='ai' where a.id="+q(execution)+' and a.id_competencia='+q(c)+' and a.id_organizacao='+q(f['org'])+' and a.id_contrato='+q(f['contract'])+';','FLOW_REAL_AI_ANALYSIS')
    context=r.operation('obter_contexto_revisao_v117',{'p_id_competencia':c,'p_id_requisito':req})
    r.check('FLOW_REVIEW_CONTEXT_CURRENT',context['pode_revisar'] is True and context['id_execucao_esperada']==execution)
    review={'p_id_competencia':c,'p_id_requisito':req,'p_id_execucao_esperada':context['id_execucao_esperada'],'p_id_resultado_esperado':context['id_resultado_esperado'],'p_hash_esperado':context['hash_esperado'],'p_resultado':'conforme','p_justificativa':'Own required synthetic text document is physically present and its page is verified.','p_fundamento':'Authorized synthetic fixture review, no real-party compliance certification.','p_evidencias':[{'id_versao_documento':version,'pagina':1,'trecho':'ContaOS own remaining'}],'p_request_id':uid()}
    r.deny('registrar_revisao_requisito_v117',review)
    r.operation('registrar_revisao_requisito_v117',review)
    gate=r.operation('avaliar_portao_conformidade',{'p_id_competencia':c})
    r.check('FLOW_REAL_GATE_100',gate['total']==1 and gate['conformes_ou_na_validos']==1 and gate['liberado'] is True and float(gate['percentual'])==100 and gate['nao_conformidades_bloqueantes']==0)
    opinion_payload={'p_id_competencia':c};r.deny('solicitar_parecer_interno',opinion_payload)
    job=r.entity('opinion_job_'+str(round),r.operation('solicitar_parecer_interno',opinion_payload))
    wait_sql(r,"select json_build_object('owned',count(*)=1,'ready',coalesce(bool_and(e.status='concluido' and exists(select 1 from public.pareceres_internos p where p.id_competencia="+q(c)+" and p.id_organizacao=e.id_organizacao and p.id_contrato=e.id_contrato and p.status='rascunho' and p.autor is null and length(p.texto)>0 and length(p.hash)=64 and p.criado_em>=e.criado_em)),false),'failed',coalesce(bool_or(e.status in ('falhou','cancelado')),false)) from public.execucoes_assincronas e where e.id="+q(job)+" and e.fila='ai' and e.entidade_tipo='gerar_parecer_interno' and e.entidade_id="+q(c)+' and e.id_organizacao='+q(f['org'])+' and e.id_contrato='+q(f['contract'])+';','FLOW_REAL_AI_OPINION')
    opinions=r.read('pareceres_internos',{'select':'id,versao,status,hash','id_competencia':'eq.'+c,'status':'eq.rascunho','order':'versao.desc','limit':1})
    assert len(opinions)==1;opinion=r.entity('opinion_'+str(round),opinions[0]['id'])
    approval={'p_id_parecer':opinion,'p_aprovar':True,'p_fundamento':'Independent own Master approval of synthetic draft'}
    r.deny('aprovar_parecer_interno',approval)
    r.operation('aprovar_parecer_interno',approval,'master')
    r.sql_check('FLOW_SQL_OPINION_APPROVAL','select exists(select 1 from public.pareceres_internos where id='+q(opinion)+" and status='aprovado' and autor is null and aprovado_por="+q(next(u['id'] for u in f['users'] if u['profile']=='master'))+' and aprovado_em is not null);')
    return opinion

def run(r):
    f=r.fixture;state={'id':None,'version':None,'revision':None}
    def command(action,payload):
        result=r.operation('executar_comando_lista_v1',{'p_id_organizacao':f['org'],'p_id_contrato':f['contract'],'p_id_lista':state['id'],'p_versao_esperada':state['revision'],'p_acao':action,'p_payload':payload,'p_motivo':'Own mandatory physical-document flow prerequisite','p_request_id':uid()})
        state.update(id=result['lista']['id'],revision=result['lista']['versao_registro']);return result
    state['version']=command('criar_lista',{'nome':f['prefix']+'Mandatory document gate','vigencia_inicio':'2026-01-01'})['id_versao']
    command('salvar_item',{'id_versao':state['version'],'codigo':'OWN-PHYSICAL','descricao':'Verificar existência de documento sintético próprio com texto legível na página1.','obrigatorio':True,'aplicavel':True,'impeditivo':True,'regra_validacao':{'documento':{'obrigatorio':True,'tipos':['outro']}}})
    command('publicar_versao',{'id_versao':state['version']});c=competence(r)
    reqs=r.read('requisitos_competencia',{'select':'id,obrigatorio,aplicavel,efeito_portao','id_competencia':'eq.'+c})
    r.check('FLOW_MANDATORY_REQUIREMENT',len(reqs)==1 and all(reqs[0][k] is True for k in ('obrigatorio','aplicavel','efeito_portao')));req=r.entity('requirement',reqs[0]['id'])
    blocked={'p_id_competencia':c};r.operation('solicitar_parecer_interno',blocked,status=400,code='P0001')
    r.operation('aprovar_apresentacao',{**blocked,'p_fundamento':'Must remain blocked before treatment'},status=400,code='P0001')
    file=r.upload('presentation-v1');create={'p_id_competencia':c,'p_tipo':'outro','p_titulo':f['prefix']+'Presentation evidence','p_categoria':'own','p_id_requisito':req,'p_id_arquivo':file,'p_chave_idempotencia':uid()}
    doc=r.operation('criar_documento_competencia_v115',create);wait_document(r,doc,file,'competencia')
    first=analyze_review_opinion(r,c,req,doc['id_versao'],1)
    approve={'p_id_competencia':c,'p_fundamento':'Own authorization after real analysis, review and independent opinion approval'}
    r.deny('aprovar_apresentacao',approve);r.operation('aprovar_apresentacao',approve)
    second_file=r.upload('presentation-v2');second=r.operation('adicionar_versao_documento_competencia_v115',{'p_id_documento':doc['id_documento'],'p_id_arquivo':second_file,'p_motivo':'Own material change for stale-context negative control','p_chave_idempotencia':uid()});wait_document(r,second,second_file,'competencia')
    protocol={'p_id_competencia':c,'p_idempotency_key':uid(),'p_protocolo':'OWN-'+f['nonce'],'p_forma_apresentacao':'protocolo_sintetico_hml','p_id_comprovante_arquivo':second_file}
    r.deny('registrar_apresentacao',protocol)
    r.operation('registrar_apresentacao',protocol,status=400,code='P0001')
    r.sql_check('FLOW_STALE_CONTEXT_BLOCKED','select not exists(select 1 from public.apresentacoes_contratante where id_competencia='+q(c)+') and exists(select 1 from public.aprovacoes where id_competencia='+q(c)+" and tipo='apresentacao' and hash_contexto is distinct from privado.hash_contexto_competencia("+q(c)+'));')
    final=analyze_review_opinion(r,c,req,second['id_versao'],2)
    r.operation('aprovar_apresentacao',approve)
    presentation=r.entity('presentation',r.operation('registrar_apresentacao',protocol))
    r.check('FLOW_PROTOCOL_REPLAY',r.operation('registrar_apresentacao',protocol)==presentation)
    r.check('FLOW_READER_PROTOCOL',len(r.read('apresentacoes_contratante',{'select':'id,protocolo','id':'eq.'+presentation},'leitor'))==1)
    r.check('FLOW_TENANT_ISOLATED',r.read('apresentacoes_contratante',{'select':'id','id_competencia':'eq.'+c},'usuario_b')==[] and r.read('pareceres_internos',{'select':'id','id_competencia':'eq.'+c},'usuario_b')==[])
    r.sql_check('FLOW_SQL_FROZEN_PACKAGE','select exists(select 1 from public.apresentacoes_contratante a join public.pacotes_competencia p on p.id=a.id_pacote join public.competencias c on c.id=a.id_competencia where a.id='+q(presentation)+' and a.protocolo='+q(protocol['p_protocolo'])+' and a.id_comprovante_arquivo='+q(second_file)+" and p.status='apresentado' and p.congelado_em is not null and length(p.hash_pacote)=64 and c.situacao='aguardando_contratante' and (select count(*)=1 and bool_and(i.versao_id="+q(second['id_versao'])+' and i.hash=v.hash) from public.itens_pacote_competencia i join public.versoes_documento v on v.id=i.versao_id where i.id_pacote=p.id));')
    r.sql_check('FLOW_SQL_HISTORY_AUDIT','select (select count(*) from public.execucoes_analise where id_competencia='+q(c)+" and tipo='completa' and status='concluida')>=2 and exists(select 1 from public.pareceres_internos where id="+q(final)+" and status='aprovado') and exists(select 1 from public.eventos_auditoria where id_organizacao="+q(f['org'])+' and id_entidade='+q(presentation)+" and evento='ApresentacaoRegistrada');")
    r.report['limitations']=['Synthetic own compliance scenario only. Real AI analysis and opinion worker, physical pages and authorized human-review RPC are required. No real-party legal/compliance certification.'];r.save('report.json',r.report)
