"""Own marked historical source through normal documents/history workers and treatment RPC."""
import hashlib,json,time,urllib.request
from p0_crud_global_hml import q,uid,KEY

def upload_marked(r):
    from p0_crud_global_remaining_hml import validate_target
    f=r.fixture;name='crudg-'+f['nonce']+'-historical-source.txt'
    payload=('Own synthetic historical report '+f['nonce']+'\nApontamento 1: Ausência de comprovante sintético, exige resposta e desfecho próprios.\n').encode();sha=hashlib.sha256(payload).hexdigest()
    intent={'name':name,'sha256':sha,'size':len(payload),'state':'INTENT'};f.setdefault('signed_uploads',[]).append(intent);r.save('fixture.json',f)
    st,signed=r.request('/functions/v1/storage-sign-upload',{'id_organizacao':f['org'],'id_contrato':f['contract'],'nome_arquivo':name,'mime':'text/plain','tamanho':len(payload)},r.tokens['administrador'])
    r.check('HISTORY_SIGNED_OWN_SOURCE',st==200 and isinstance(signed,dict) and signed.get('ok') is True,st)
    path=signed['path'];assert signed['bucket']=='contaos-documentos' and path.startswith(f['org']+'/uploads/') and path.endswith('/'+name)
    url=signed['signed_url'];u=validate_target(url,upload=True,org=f['org'],nonce=f['nonce']);assert u.path=='/storage/v1/object/upload/sign/contaos-documentos/'+path
    intent.update(path=path,state='SIGNED');r.save('fixture.json',f)
    st,_=r.send(urllib.request.Request(url,data=payload,method='PUT',headers={'apikey':KEY,'Content-Type':'text/plain','x-upsert':'false'}))
    r.check('HISTORY_PHYSICAL_UPLOAD',st in (200,201),st)
    file=r.operation('confirmar_upload_arquivo',{'p_id_organizacao':f['org'],'p_id_contrato':f['contract'],'p_path':path,'p_nome_original':name,'p_mime':'text/plain','p_tamanho':len(payload),'p_sha256':sha,'p_origem':'upload_usuario'})
    intent.update(file=file,state='CONFIRMED');r.save('fixture.json',f)
    r.sql_check('HISTORY_PHYSICAL_SQL','select exists(select 1 from public.arquivos a join storage.objects o on o.bucket_id=a.bucket and o.name=a.path where a.id='+q(file)+' and a.id_organizacao='+q(f['org'])+' and a.id_contrato='+q(f['contract'])+' and a.sha256='+q(sha)+' and a.tamanho='+str(len(payload))+');')
    return file

def run(r):
    from remaining_domains.document_fixture import wait_document
    f=r.fixture;file=r.entity('source_file',upload_marked(r))
    document=r.operation('criar_documento_contrato_completo',{'p_id_contrato':f['contract'],'p_tipo':'relatorio_contratante','p_titulo':f['prefix']+'Historical report','p_categoria':'historico','p_vigencia_inicio':'2025-01-01','p_vigencia_fim':None,'p_observacoes':'Own synthetic marked historical precondition','p_id_arquivo':file,'p_chave_idempotencia':uid()})
    wait_document(r,document,file,'contrato')
    register={'p_id_arquivo':file,'p_competencia':'2025-01-01','p_tipo':'relatorio_contratante'}
    r.deny('registrar_relatorio_historico_hml',register)
    report=r.entity('historical_report',r.operation('registrar_relatorio_historico_hml',register))
    r.check('HISTORY_REGISTRATION_REPLAY',r.operation('registrar_relatorio_historico_hml',register)==report)
    enqueue={'p_id_relatorio':report,'p_id_versao_documento':document['id_versao']}
    r.deny('enfileirar_ingestao_historica_hml',enqueue)
    job=r.entity('historical_job',r.operation('enfileirar_ingestao_historica_hml',enqueue))
    r.check('HISTORY_QUEUE_REPLAY',r.operation('enfileirar_ingestao_historica_hml',enqueue)==job)
    deadline=time.monotonic()+300
    while True:
        state=json.loads(r.sql("select json_build_object('owned',count(*)=1,'ready',coalesce(bool_and(e.status='concluido' and h.status_processamento='concluido'),false),'failed',coalesce(bool_or(e.status in ('falhou','cancelado') or h.status_processamento='falhou'),false)) from public.execucoes_assincronas e join public.relatorios_historicos_contratante h on h.id=e.entidade_id and h.id_organizacao=e.id_organizacao and h.id_contrato=e.id_contrato where e.id="+q(job)+" and e.fila='historico' and e.entidade_tipo='relatorio_historico' and h.id="+q(report)+' and h.id_organizacao='+q(f['org'])+' and h.id_contrato='+q(f['contract'])+';',True))
        assert state['owned'] and not state['failed']
        if state['ready']:break
        assert time.monotonic()<deadline,'Normal historical worker timed out'
        time.sleep(2)
    findings=r.read('apontamentos_historicos',{'select':'id,item,fonte_pagina,fonte_trecho','id_relatorio':'eq.'+report})
    r.check('HISTORY_REAL_MARKED_FINDING',len(findings)==1 and findings[0]['item']=='1' and findings[0]['fonte_pagina']==1 and 'Ausência de comprovante sintético' in findings[0]['fonte_trecho'])
    finding=r.entity('historical_finding',findings[0]['id'])
    treatment={'p_id_apontamento':finding,'p_resposta':'Own synthetic response with review','p_desfecho':'Regularizado sinteticamente','p_fundamento':'Own fixture resolution evidence'}
    r.deny('vincular_tratamento_historico_hml',treatment)
    r.operation('vincular_tratamento_historico_hml',{**treatment,'p_resposta':None,'p_desfecho':None},status=400,code='P0001')
    result=r.operation('vincular_tratamento_historico_hml',treatment);response=r.entity('historical_response',result['id_resposta']);outcome=r.entity('historical_outcome',result['id_desfecho'])
    r.check('HISTORY_READER_READ',len(r.read('relatorios_historicos_contratante',{'select':'id','id':'eq.'+report},'leitor'))==1)
    r.check('HISTORY_TENANT_ISOLATED',r.read('apontamentos_historicos',{'select':'id','id_relatorio':'eq.'+report},'usuario_b')==[])
    r.sql_check('HISTORY_SQL_TREATMENT','select exists(select 1 from public.respostas_historicas where id='+q(response)+' and id_apontamento='+q(finding)+" and texto='Own synthetic response with review') and exists(select 1 from public.desfechos_historicos where id="+q(outcome)+' and id_apontamento='+q(finding)+" and resultado='Regularizado sinteticamente' and fundamento='Own fixture resolution evidence') and (select count(*)=1 from public.apontamentos_historicos where id_relatorio="+q(report)+');')
    r.sql_check('HISTORY_AUDIT','select count(*)=3 from public.eventos_auditoria where id_organizacao='+q(f['org'])+" and evento in ('HistoricoImportacaoRegistrada','IngestaoHistoricaEnfileirada','TratamentoHistoricoVinculado');")
