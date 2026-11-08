"""Separate five-queue quarantine. Protected documentary harness remains unchanged."""
import json,uuid
from p0_crud_global_hml import q

def remaining_quarantine_actions(rows, orgs, contracts):
    result={'cancel':[],'active':[]}
    for row in rows:
        assert row['id_organizacao'] in orgs and contracts.get(row['id_contrato'])==row['id_organizacao'],'Foreign job scope'
        assert row['fila'] in ('documents','ocr','ai','embeddings','historico'),'Unexpected document queue'
        assert str(uuid.UUID(row['id']))==row['id'],'Invalid own job identity'
        assert type(row['message_id']) is int and row['message_id']>0,'Invalid own message identity'
        assert row['status'] in ('enfileirado','processando','concluido','falhou','cancelado'),'Unexpected job status'
        if row['status']=='processando':result['active'].append(row['id'])
        elif row['status'] in ('enfileirado','falhou'):result['cancel'].append(row['id'])
    return result

def quarantine_document_jobs(self, f, max_wait_seconds=300):
    import re,time
    assert f['scope']=='P0-CRUD-GLOBAL-HML' and re.fullmatch('[0-9a-f]{32}',f['nonce'])
    assert f['prefix']=='0000 CRUDG '+f['nonce']+' '
    assert type(max_wait_seconds) is int and 0<=max_wait_seconds<=300
    own="o.razao_social in ("+q(f['prefix']+'A')+','+q(f['prefix']+'B')+')'
    scope=json.loads(self.sql("/* DOCUMENT_OWN_SCOPE */ select json_build_object('orgs',array(select o.id from public.organizacoes o where "+own+"),'contracts',coalesce((select json_agg(json_build_object('id',c.id,'id_organizacao',c.id_organizacao)) from public.contratos c join public.organizacoes o on o.id=c.id_organizacao where "+own+"),'[]'::json));",True))
    orgs=set(scope['orgs']);contracts={x['id']:x['id_organizacao'] for x in scope['contracts']}
    for value in [*orgs,*contracts]:assert str(uuid.UUID(value))==value
    assert all(value in orgs for value in contracts.values())
    if not orgs:return {'active_jobs':0,'cancelled_jobs':0}
    osql=','.join(map(q,orgs));csql=','.join(map(q,contracts)) or 'null'
    queue_count_sql='/* DOCUMENT_ACTIVE_QUEUE_MESSAGES */ select '+ '+'.join('(select count(*) from '+table+" where message->>'id_organizacao' in ("+osql+") or message->>'id_contrato' in ("+csql+'))' for table in ('pgmq.q_documents','pgmq.q_ocr','pgmq.q_ai','pgmq.q_embeddings','pgmq.q_historico'))+';'
    deadline=time.monotonic()+max_wait_seconds
    while True:
        rows=json.loads(self.sql("/* DOCUMENT_OWN_JOBS */ select coalesce(json_agg(j),'[]'::json) from (select id,id_organizacao,id_contrato,fila,status,message_id from public.execucoes_assincronas where id_organizacao in ("+osql+') or id_contrato in ('+csql+') order by id limit 1001) j;',True))
        assert len(rows)<=1000,'Own document jobs exceeded safe bound'
        actions=remaining_quarantine_actions(rows,orgs,contracts)
        if not actions['cancel'] and not actions['active']:
            processing=self.sql("/* DOCUMENT_ACTIVE_PROCESSINGS */ select count(*) from public.processamentos_documento where id_organizacao in ("+osql+") and status in ('pendente','processando');",True)
            if processing=='0' and self.sql(queue_count_sql,True)=='0':return {'active_jobs':0,'cancelled_jobs':sum(x['status']=='cancelado' for x in rows)}
        if actions['cancel']:
            ids=','.join(map(q,actions['cancel']))
            # Identifiers come exclusively from this constant mapping, never from a request.
            for queue,table in (('documents','pgmq.q_documents'),('ocr','pgmq.q_ocr'),('ai','pgmq.q_ai'),('embeddings','pgmq.q_embeddings'),('historico','pgmq.q_historico')):
                self.sql("""/* DOCUMENT_QUARANTINE_PENDING */ do $own_quarantine$
                declare own_job record;
                begin
                  for own_job in select e.id,e.message_id,e.id_organizacao,e.id_contrato,e.entidade_tipo,e.entidade_id
                    from """+table+""" message join public.execucoes_assincronas e on e.message_id=message.msg_id
                    where e.fila="""+q(queue)+""" and e.id in ("""+ids+""")
                      and e.id_organizacao in ("""+osql+""") and e.id_contrato in ("""+csql+""")
                      and message.message->>'id_organizacao'=e.id_organizacao::text
                      and message.message->>'id_contrato'=e.id_contrato::text
                      and e.status in ('enfileirado','falhou')
                    for update of message,e
                  loop
                    perform pgmq.delete("""+q(queue)+""",own_job.message_id);
                    update public.execucoes_assincronas set status='cancelado',erro_codigo='FIXTURE_QUARANTINE',concluido_em=now() where id=own_job.id and status in ('enfileirado','falhou');
                    if own_job.entidade_tipo='versao_documento' then
                      update public.processamentos_documento set status='cancelado',erro_codigo='FIXTURE_QUARANTINE',concluido_em=now()
                        where id_organizacao=own_job.id_organizacao and id_contrato=own_job.id_contrato and id_versao_documento=own_job.entidade_id
                          and etapa="""+q(queue)+""" and status in ('pendente','falhou');
                    end if;
                  end loop;
                end $own_quarantine$;""")
            # Re-read even at timeout: a concurrent child must not be reported clean.
            final=json.loads(self.sql("/* DOCUMENT_OWN_JOBS */ select coalesce(json_agg(j),'[]'::json) from (select id,id_organizacao,id_contrato,fila,status,message_id from public.execucoes_assincronas where id_organizacao in ("+osql+') or id_contrato in ('+csql+') order by id limit 1001) j;',True))
            assert len(final)<=1000
            remaining=remaining_quarantine_actions(final,orgs,contracts)
            if not remaining['cancel'] and not remaining['active']:
                processing=self.sql("/* DOCUMENT_ACTIVE_PROCESSINGS */ select count(*) from public.processamentos_documento where id_organizacao in ("+osql+") and status in ('pendente','processando');",True)
                if processing=='0' and self.sql(queue_count_sql,True)=='0':return {'active_jobs':0,'cancelled_jobs':sum(x['status']=='cancelado' for x in final)}
        if time.monotonic()>=deadline:raise RuntimeError('Own document work still active; quarantine incomplete')
        time.sleep(1)
