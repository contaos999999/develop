"""Local-only SQL/race negative controls for historical queue quarantine."""
import os,json,uuid,subprocess
from p0_crud_global_hml import Runner as FixtureRunner,q,uid,validate_local_restore_url
from remaining_domains.history_quarantine import quarantine_document_jobs
class LocalRunner(FixtureRunner):
    quarantine_document_jobs=quarantine_document_jobs

def main():
    # No Auth, HML or production access: the explicit URL guard runs before any SQL.
    db=os.environ.get('CONTAOS_LOCAL_QUARANTINE_DB_URL','');validate_local_restore_url(db)
    runner=object.__new__(LocalRunner);runner.db=db;runner.report={}
    nonce=uuid.uuid4().hex;f={'scope':'P0-CRUD-GLOBAL-HML','nonce':nonce,'prefix':'0000 CRUDG '+nonce+' '}
    scope=[]
    for label in ('A','B','FOREIGN'):
        org,contractor,contract=uid(),uid(),uid();scope.append((org,contract))
        name=f['prefix']+label if label!='FOREIGN' else 'LOCAL FOREIGN '+nonce
        runner.sql('begin;insert into public.organizacoes(id,razao_social) values('+q(org)+','+q(name)+');insert into public.contratantes(id,id_organizacao,razao_social) values('+q(contractor)+','+q(org)+",'Local quarantine contractor');insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values("+q(contract)+','+q(org)+','+q(contractor)+','+q('LOCAL-'+nonce+'-'+label)+",'Local quarantine proof','2026-01-01');commit;")
    org,contract=scope[0];file_id,doc,version=uid(),uid(),uid();sha='0'*64
    runner.sql('begin;insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,mime,tamanho,sha256) values('+q(file_id)+','+q(org)+','+q(contract)+','+q(org+'/'+contract+'/local.txt')+",'local-quarantine.txt','text/plain',1,"+q(sha)+');insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo) values('+q(doc)+','+q(org)+','+q(contract)+",'contrato','Local quarantine document');insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash) values("+q(version)+','+q(org)+','+q(contract)+','+q(doc)+',1,'+q(file_id)+','+q(sha)+');insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values('+q(org)+','+q(contract)+','+q(version)+",'documents','concluido'),("+q(org)+','+q(contract)+','+q(version)+",'ocr','concluido');commit;")
    def job(tenant,contract_id,queue='historico'):
        # Local synthetic queue fixture only. The generic enqueuer deliberately
        # excludes historico; its dedicated producer uses pgmq plus its own row.
        if queue=='historico':
            return runner.sql("with message as(select pgmq.send('historico',jsonb_build_object('id_organizacao',"+q(tenant)+",'id_contrato',"+q(contract_id)+")) id) insert into public.execucoes_assincronas(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,message_id) select "+q(tenant)+','+q(contract_id)+",'historico','versao_documento',"+q(version)+',id from message returning id;',True)
        return runner.sql('select privado.enfileirar_job('+q(queue)+','+q(tenant)+','+q(contract_id)+",'versao_documento',"+q(version)+",'{}'::jsonb,null);",True)
    pending=job(org,contract);complete=job(org,contract,'ocr');foreign=job(*scope[2])
    runner.sql("select pgmq.delete('ocr',message_id) from public.execucoes_assincronas where id="+q(complete)+";update public.execucoes_assincronas set status='concluido' where id="+q(complete)+';')
    result=runner.quarantine_document_jobs(f,max_wait_seconds=0)
    assert result['active_jobs']==0 and result['cancelled_jobs']==1
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(pending)+';',True)=='cancelado'
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(complete)+';',True)=='concluido'
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(foreign)+';',True)=='enfileirado'
    assert runner.sql("select status from public.processamentos_documento where id_versao_documento="+q(version)+" and etapa='documents';",True)=='concluido'
    assert runner.sql("select status from public.processamentos_documento where id_versao_documento="+q(version)+" and etapa='ocr';",True)=='concluido'
    orphan=int(runner.sql("select pgmq.send('historico',jsonb_build_object('id_organizacao',"+q(org)+",'id_contrato',"+q(contract)+"));",True))
    try:runner.quarantine_document_jobs(f,max_wait_seconds=0)
    except RuntimeError:pass
    else:raise AssertionError('Orphan queue message was falsely called clean')
    runner.sql("select pgmq.delete('historico',"+str(orphan)+');')
    active=job(org,contract);runner.sql("update public.execucoes_assincronas set status='processando' where id="+q(active)+';')
    try:runner.quarantine_document_jobs(f,max_wait_seconds=0)
    except RuntimeError:pass
    else:raise AssertionError('Running own worker was falsely called clean')
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(active)+';',True)=='processando'
    # Real TOCTOU race: cleanup reads queued work, then a worker locks it before cancellation.
    import time
    racing=job(org,contract);original_sql=runner.sql;started=False;worker=None;blocked=0
    def race_sql(source,fetch=False):
        nonlocal started,worker,blocked
        if 'DOCUMENT_QUARANTINE_PENDING' in source and 'from pgmq.q_historico message' in source and not started:
            started=True;app='local_document_race_'+nonce
            worker_sql="set application_name="+q(app)+";begin;do $worker$ begin perform 1 from pgmq.q_historico message join public.execucoes_assincronas e on e.message_id=message.msg_id where e.id="+q(racing)+" for update of message,e;update public.execucoes_assincronas set status='processando' where id="+q(racing)+";end $worker$;select pg_sleep(1);commit;"
            worker=subprocess.Popen(['psql',db,'-X','-qAt','-v','ON_ERROR_STOP=1','-c',worker_sql],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            ready=False
            for _ in range(100):
                if original_sql("select exists(select 1 from pg_stat_activity where application_name="+q(app)+" and wait_event='PgSleep');",True)=='t':ready=True;break
                if worker.poll() is not None:break
                time.sleep(.02)
            assert ready,'Local worker did not acquire the real lock'
            before=time.monotonic();result=original_sql(source,fetch);blocked=time.monotonic()-before
            return result
        return original_sql(source,fetch)
    runner.sql=race_sql
    try:
        try:runner.quarantine_document_jobs(f,max_wait_seconds=0)
        except RuntimeError:pass
        else:raise AssertionError('Racing worker was falsely called clean')
        assert worker is not None
        _,_=worker.communicate(timeout=5);assert worker.returncode==0 and blocked>=.4,'Real lock race not demonstrated'
    finally:
        runner.sql=original_sql
        if worker is not None and worker.poll() is None:worker.kill();worker.communicate(timeout=5)
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(racing)+';',True)=='processando'
    # Teardown is local-only; these are synthetic negative-control messages, never HML jobs.
    runner.sql("select pgmq.delete('historico',message_id) from public.execucoes_assincronas where id in ("+q(active)+','+q(foreign)+','+q(racing)+");update public.execucoes_assincronas set status='cancelado' where id in ("+q(active)+','+q(foreign)+','+q(racing)+');')
    print('HISTORY_QUARANTINE_LOCAL_SQL_PASS')
if __name__=='__main__':main()
