"""Own Auth Admin fixtures and SQL confirmation; never transfers admin/DB to browser."""
import json, os, secrets, subprocess, sys, uuid, urllib.request, urllib.error, urllib.parse
from pathlib import Path
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
KEY='sb_publishable_sHKZ-UiYCbkEFMqR1QbHMA_iCSLL8Am'
ALLOWED=('PATH','HOME','RUNNER_TEMP','TMPDIR','LANG','TZ','CI','XDG_CACHE_HOME','CONTAOS_TEST_PRIVATE_DIR','CONTAOS_FRONTEND_DIR','CONTAOS_AXE_SOURCE_PATH','CONTAOS_PLAYWRIGHT_MODULE','TESTED_HEAD','FRONTEND_HEAD')
def browser_environment(env): return {k:env[k] for k in ALLOWED if k in env}
def q(value): return "'"+str(value).replace("'","''")+"'"
def uid(): return str(uuid.uuid4())
def document_quarantine_actions(rows, orgs, contracts):
    result={'cancel':[],'active':[]}
    for row in rows:
        assert row['id_organizacao'] in orgs and contracts.get(row['id_contrato'])==row['id_organizacao'],'Foreign job scope'
        assert row['fila'] in ('documents','ocr','ai','embeddings'),'Unexpected document queue'
        assert str(uuid.UUID(row['id']))==row['id'],'Invalid own job identity'
        assert type(row['message_id']) is int and row['message_id']>0,'Invalid own message identity'
        assert row['status'] in ('enfileirado','processando','concluido','falhou','cancelado'),'Unexpected job status'
        if row['status']=='processando':result['active'].append(row['id'])
        elif row['status'] in ('enfileirado','falhou'):result['cancel'].append(row['id'])
    return result
def validate_local_restore_url(raw):
    target=urllib.parse.urlsplit(raw)
    assert (target.scheme,target.hostname,target.port,target.username,target.password,target.path)==('postgresql','127.0.0.1',54322,'postgres','postgres','/postgres') and not target.query and not target.fragment,'Local restore only'
def public_record(name, passed, http=None):
    import re
    assert re.fullmatch('[A-Z0-9_]{1,100}',name) and type(passed) is bool
    assert http is None or type(http) is int and 100<=http<=599
    return dict(name=name,passed=passed,http=http)
class Runner:
    def __init__(self, env):
        self.env=env; self.root=Path(env['CONTAOS_TEST_PRIVATE_DIR']).resolve()
        assert str(self.root).startswith(str(Path(env['RUNNER_TEMP']).resolve())+'/')
        self.root.mkdir(mode=0o700,parents=True,exist_ok=True);os.chmod(self.root,0o700)
        self.db=env['DATABASE_URL'];u=urllib.parse.urlsplit(self.db)
        assert u.username=='postgres.gklhhhyosgasnyoxlrui' and u.hostname.endswith('.pooler.supabase.com')
        self.admin=env.get('AUTH_ADMIN_KEY','');assert self.admin,'Auth Admin API required'
        self.batch=json.loads(Path('docs/tasks/active-task.json').read_text())['crud_global_proof']['batch']
        assert self.batch in ('CADASTROS_LISTAS','AUDITORIA')
        self.report={'schema':'contaos.crud-global.hml.v1','backend_head':env['TESTED_HEAD'],'frontend_head':env['FRONTEND_HEAD'],'state':'RUNNING','batch':self.batch,'global_complete':False,'assertions':[]}
    def save(self,name,data):
        assert name in ('fixture.json','report.json','cleanup.json')
        p=self.root/name;p.write_text(json.dumps(data,indent=2)+'\n');os.chmod(p,0o600)
        if name=='fixture.json':
            self.report['recovery']={'scope':data['scope'],'nonce':data['nonce'],'prefix':data['prefix'],'users':[{k:u[k] for k in ('id','intent_id','creation_state') if k in u} for u in data['users']]}
            self.save('report.json',self.report)
    def sql(self,source,fetch=False):
        p=subprocess.run(['psql',self.db,'-X','-qAt','-v','ON_ERROR_STOP=1'],input=source,capture_output=True,text=True,timeout=45)
        if p.returncode:raise RuntimeError('Own fixture database operation failed; private details withheld')
        return p.stdout.strip() if fetch else None
    def request(self,path,data=None,token=None,admin=False,method=None):
        assert path.startswith('/auth/v1/') or path.startswith('/rest/v1/')
        headers={'apikey':self.admin if admin else KEY,'Content-Type':'application/json'}
        if admin or token:headers['Authorization']='Bearer '+(self.admin if admin else token)
        req=urllib.request.Request(URL+path,data=None if data is None else json.dumps(data).encode(),headers=headers,method=method)
        try:
            with urllib.request.urlopen(req,timeout=30) as r:
                raw=r.read();return r.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            try:return e.code,json.loads(e.read())
            except ValueError:return e.code,{}
        except Exception:return 0,{}
    def check(self,name,passed,http=None):
        self.report['assertions'].append(public_record(name,passed,http));self.save('report.json',self.report)
        if not passed:raise RuntimeError('CRUD proof assertion failed: '+name)
    def prepare(self):
        assert not (self.root/'fixture.json').exists(),'Refuse fixture reuse'
        nonce=uuid.uuid4().hex
        f={'batch':self.batch,'scope':'P0-CRUD-GLOBAL-HML','nonce':nonce,'prefix':'0000 CRUDG '+nonce+' ','org':uid(),'org_b':uid(),'contractor':uid(),'contractor_b':uid(),'contract':uid(),'contract_b':uid(),'users':[],'created':{}}
        self.save('fixture.json',f)
        for role in (('master','administrador','leitor','usuario_b','auditor','juridico_conformidade') if self.batch=='AUDITORIA' else ('master','administrador','leitor','usuario_b')):
            u={'profile':role,'intent_id':uid(),'email':'crudg-'+uid()+'@example.invalid','password':secrets.token_urlsafe(40)+'Aa1!','creation_state':'pending'}
            f['users'].append(u);self.save('fixture.json',f)
            st,data=self.request('/auth/v1/admin/users',{'email':u['email'],'password':u['password'],'email_confirm':True,'app_metadata':{'synthetic':True,'scope':f['scope'],'fixture_request_id':u['intent_id'],'crud_nonce':nonce}},admin=True)
            if 400<=st<500:u['creation_state']='rejected';self.save('fixture.json',f)
            self.check('AUTH_CREATE_'+role.upper(),st in (200,201) and isinstance(data,dict) and bool(data.get('id')),st)
            u.update(id=data['id'],creation_state='created');self.save('fixture.json',f)
        sql=['begin;']
        for suffix in ('','_b'):
            label='B' if suffix else 'A';org=f['org'+suffix];ct=f['contract'+suffix];cr=f['contractor'+suffix]
            sql += [f"insert into public.organizacoes(id,razao_social) values({q(org)},{q(f['prefix']+label)});",f"insert into public.contratantes(id,id_organizacao,razao_social) values({q(cr)},{q(org)},{q(f['prefix']+'contractor '+label)});",f"insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values({q(ct)},{q(org)},{q(cr)},{q('CRUDG-'+nonce+'-'+label)},'Own synthetic CRUD proof','2026-01-01');"]
        for u in f['users']:
            if u['profile']=='master':sql.append(f"insert into privado.administradores_master(id_usuario,motivo) values({q(u['id'])},'Own synthetic CRUD global proof');")
            else:
                org=f['org_b'] if u['profile']=='usuario_b' else f['org'];profile='administrador' if u['profile']=='usuario_b' else u['profile']
                sql.append(f"insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos) values({q(org)},{q(u['id'])},{q(profile)},true);")
        sql.append('commit;');self.sql('\n'.join(sql));return f
    def verify(self):
        f=json.loads((self.root/'fixture.json').read_text());created=f['created']
        if self.batch=='AUDITORIA':
            reads=f.get('audit_reads',[]);assert reads,'Browser audit reads missing'
            for read in reads:
                ids=read['ids'];assert ids,'Expected own audit events'
                self.check('AUDIT_ROWS_PERSISTED_OWN_TENANT',self.sql('select count(*)='+str(len(ids))+' from public.eventos_auditoria where id_organizacao='+q(read['org'])+' and id in ('+','.join(map(q,ids))+');',True)=='t')
            for command in f.get('commands',[]):
                self.check('AUDIT_REAL_COMMAND_PERSISTED',self.sql("select exists(select 1 from public.eventos_auditoria where id_organizacao="+q(f['org'])+" and metadados->>'request_id'="+q(command['request_id'])+');',True)=='t')
            self.check('AUDIT_REAL_EVENTS_FOR_PAGINATION',len(f.get('commands',[]))>=26)
            return
        for name in ('organization','contractor','contract','list'):
            assert name in created,'Browser receipt missing'
        self.check('ORG_PERSISTED',self.sql('select exists(select 1 from public.organizacoes where id='+q(created['organization'])+' and razao_social like '+q(f['prefix']+'%')+' and nome_fantasia='+q(f['prefix']+'edited')+" and situacao='suspensa');",True)=='t')
        self.check('CONTRACTOR_PERSISTED',self.sql('select exists(select 1 from public.contratantes where id='+q(created['contractor'])+' and id_organizacao='+q(f['org'])+' and nome_fantasia='+q(f['prefix']+'contractor-edited')+" and situacao='ativo');",True)=='t')
        self.check('CONTRACT_LIFECYCLE_PERSISTED',self.sql('select exists(select 1 from public.contratos where id='+q(created['contract'])+' and id_organizacao='+q(f['org'])+" and situacao='encerrado' and objeto='Own synthetic edited contract');",True)=='t')
        self.check('LIST_RECOVERY_PERSISTED',self.sql('select exists(select 1 from public.listas_verificacao where id='+q(created['list'])+' and id_contrato='+q(f['contract'])+' and nome='+q(f['prefix']+'recovered')+');',True)=='t')
        self.check('LIST_ITEM_EDIT_PERSISTED',self.sql('select exists(select 1 from public.itens_lista i join public.versoes_lista v on v.id=i.id_versao_lista where v.id_lista='+q(created['list'])+" and v.numero_versao=1 and i.codigo='OWN1' and i.descricao='Own optional item edited' and not i.obrigatorio);",True)=='t')
        self.check('LIST_TEMP_ITEM_REMOVED',self.sql('select not exists(select 1 from public.itens_lista i join public.versoes_lista v on v.id=i.id_versao_lista where v.id_lista='+q(created['list'])+" and i.codigo='TMP');",True)=='t')
        self.check('LIST_VERSION_LIFECYCLE',self.sql("select count(*)=2 and bool_and(case when numero_versao=1 then situacao='publicada' and vigencia_inicio='2026-01-01' and vigencia_fim='2026-06-30' and aprovado_em is not null when numero_versao=2 then situacao='substituida' and aprovado_em is null else false end) from public.versoes_lista where id_lista="+q(created['list'])+';',True)=='t')
        for command in f.get('commands',[]):
            self.check('COMMAND_AUDIT_AND_RECEIPT',self.sql("select exists(select 1 from public.eventos_auditoria where metadados->>'request_id'="+q(command['request_id'])+') and exists(select 1 from public.comandos_idempotentes where chave='+q(command['request_id'])+" and status='concluido');",True)=='t')
        self.check('OWN_AUDIT_PRESENT',int(self.sql('select count(*) from public.eventos_auditoria where id_organizacao='+q(f['org'])+';',True))>0)
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
        queue_count_sql='/* DOCUMENT_ACTIVE_QUEUE_MESSAGES */ select '+ '+'.join('(select count(*) from '+table+" where message->>'id_organizacao' in ("+osql+") or message->>'id_contrato' in ("+csql+'))' for table in ('pgmq.q_documents','pgmq.q_ocr','pgmq.q_ai','pgmq.q_embeddings'))+';'
        deadline=time.monotonic()+max_wait_seconds
        while True:
            rows=json.loads(self.sql("/* DOCUMENT_OWN_JOBS */ select coalesce(json_agg(j),'[]'::json) from (select id,id_organizacao,id_contrato,fila,status,message_id from public.execucoes_assincronas where id_organizacao in ("+osql+') or id_contrato in ('+csql+') order by id limit 1001) j;',True))
            assert len(rows)<=1000,'Own document jobs exceeded safe bound'
            actions=document_quarantine_actions(rows,orgs,contracts)
            if not actions['cancel'] and not actions['active']:
                processing=self.sql("/* DOCUMENT_ACTIVE_PROCESSINGS */ select count(*) from public.processamentos_documento where id_organizacao in ("+osql+") and status in ('pendente','processando');",True)
                if processing=='0' and self.sql(queue_count_sql,True)=='0':return {'active_jobs':0,'cancelled_jobs':sum(x['status']=='cancelado' for x in rows)}
            if actions['cancel']:
                ids=','.join(map(q,actions['cancel']))
                # Identifiers come exclusively from this constant mapping, never from a request.
                for queue,table in (('documents','pgmq.q_documents'),('ocr','pgmq.q_ocr'),('ai','pgmq.q_ai'),('embeddings','pgmq.q_embeddings')):
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
                remaining=document_quarantine_actions(final,orgs,contracts)
                if not remaining['cancel'] and not remaining['active']:
                    processing=self.sql("/* DOCUMENT_ACTIVE_PROCESSINGS */ select count(*) from public.processamentos_documento where id_organizacao in ("+osql+") and status in ('pendente','processando');",True)
                    if processing=='0' and self.sql(queue_count_sql,True)=='0':return {'active_jobs':0,'cancelled_jobs':sum(x['status']=='cancelado' for x in final)}
            if time.monotonic()>=deadline:raise RuntimeError('Own document work still active; quarantine incomplete')
            time.sleep(1)
    def cleanup(self):
        p=self.root/'fixture.json'
        if not p.exists():
            recovery=self.report.get('recovery')
            if not recovery:return
            self.save('fixture.json',recovery)
        f=json.loads(p.read_text());owned=[];unresolved=False
        for u in f['users']:
            ids=self.sql("select id from auth.users where raw_app_meta_data->>'fixture_request_id'="+q(u['intent_id'])+" and raw_app_meta_data->>'crud_nonce'="+q(f['nonce'])+" and raw_app_meta_data->>'scope'="+q(f['scope'])+';',True).splitlines()
            if len(ids)!=1:
                if u['creation_state']!='rejected':unresolved=True
                continue
            own=ids[0];owned.append(own);u['id']=own;self.save('fixture.json',f)
        # Recover UI-created organizations by a high-entropy own nonce, not untrusted receipts.
        orgs=self.sql('select id from public.organizacoes where razao_social like '+q(f['prefix']+'%')+';',True).splitlines()
        if owned:
            joined=','.join(map(q,owned));self.sql('begin;update privado.administradores_master set ativo=false where id_usuario in ('+joined+');update public.vinculos_usuarios set ativo=false where id_usuario in ('+joined+');commit;')
            for own in owned:
                st,_=self.request('/auth/v1/admin/users/'+own,{'ban_duration':'876000h'},admin=True,method='PUT')
                if st!=200:raise RuntimeError('Own Auth quarantine failed')
            self.sql('delete from auth.sessions where user_id in ('+joined+');')
            clean=self.sql('select not exists(select 1 from auth.sessions where user_id in ('+joined+')) and not exists(select 1 from privado.administradores_master where ativo and id_usuario in ('+joined+')) and not exists(select 1 from public.vinculos_usuarios where ativo and id_usuario in ('+joined+'));',True)
            assert clean=='t','Own identities not fully quarantined'
        if orgs:
            joined=','.join(map(q,orgs));self.sql("update public.organizacoes set situacao='inativa' where id in ("+joined+');')
            assert self.sql("select not exists(select 1 from public.organizacoes where situacao<>'inativa' and id in ("+joined+'));',True)=='t'
        if unresolved:raise RuntimeError('Ambiguous own Auth creation; known identities quarantined')
        result={'state':'QUARENTENA_VERIFICADA','own_users':len(owned),'own_organizations':len(orgs)};self.save('cleanup.json',result);self.report['cleanup']=result;self.save('report.json',self.report)
def self_test():
    import tempfile
    assert browser_environment({'PATH':'/bin','DATABASE_URL':'PRIVATE_CANARY','AUTH_ADMIN_KEY':'PRIVATE_CANARY','GH_TOKEN':'PRIVATE_CANARY'})=={'PATH':'/bin'}
    assert public_record('READ_SCOPE',True,200)=={'name':'READ_SCOPE','passed':True,'http':200}
    rejected=False
    try:public_record('secret@example.invalid',True)
    except AssertionError:rejected=True
    assert rejected,'unsafe public record accepted'
    r=object.__new__(Runner);r.report={'assertions':[]};calls=[]
    with tempfile.TemporaryDirectory() as d:
        r.root=Path(d);f={'scope':'P0-CRUD-GLOBAL-HML','nonce':'own-nonce','prefix':'own-prefix ','users':[{'intent_id':'own-intent','creation_state':'pending'}]};r.save('fixture.json',f)
        def fake_sql(source,fetch=False):
            calls.append(source)
            if source.startswith('select id from auth.users'):
                assert 'own-intent' in source and 'own-nonce' in source;return '11111111-1111-4111-8111-111111111111'
            if source.startswith('select id from public.organizacoes'):return '22222222-2222-4222-8222-222222222222'
            return 't' if fetch else None
        def fake_request(path,data=None,token=None,admin=False,method=None):
            assert path.endswith('11111111-1111-4111-8111-111111111111') and admin and method=='PUT';calls.append('BAN');return 200,{}
        r.sql=fake_sql;r.request=fake_request;r.cleanup()
        assert 'BAN' in calls and any('delete from auth.sessions' in x for x in calls)
        assert json.loads((r.root/'cleanup.json').read_text())['state']=='QUARENTENA_VERIFICADA'
        assert not any('insert into auth.users' in x.lower() for x in calls)
    print('CRUD_GLOBAL_PROTOCOL_PASS')
def local_document_quarantine_proof():
    # No Auth, HML or production access: the explicit URL guard runs before any SQL.
    db=os.environ.get('CONTAOS_LOCAL_QUARANTINE_DB_URL','');validate_local_restore_url(db)
    runner=object.__new__(Runner);runner.db=db;runner.report={}
    nonce=uuid.uuid4().hex;f={'scope':'P0-CRUD-GLOBAL-HML','nonce':nonce,'prefix':'0000 CRUDG '+nonce+' '}
    scope=[]
    for label in ('A','B','FOREIGN'):
        org,contractor,contract=uid(),uid(),uid();scope.append((org,contract))
        name=f['prefix']+label if label!='FOREIGN' else 'LOCAL FOREIGN '+nonce
        runner.sql('begin;insert into public.organizacoes(id,razao_social) values('+q(org)+','+q(name)+');insert into public.contratantes(id,id_organizacao,razao_social) values('+q(contractor)+','+q(org)+",'Local quarantine contractor');insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio) values("+q(contract)+','+q(org)+','+q(contractor)+','+q('LOCAL-'+nonce+'-'+label)+",'Local quarantine proof','2026-01-01');commit;")
    org,contract=scope[0];file_id,doc,version=uid(),uid(),uid();sha='0'*64
    runner.sql('begin;insert into public.arquivos(id,id_organizacao,id_contrato,path,nome_original,mime,tamanho,sha256) values('+q(file_id)+','+q(org)+','+q(contract)+','+q(org+'/'+contract+'/local.txt')+",'local-quarantine.txt','text/plain',1,"+q(sha)+');insert into public.documentos_contrato(id,id_organizacao,id_contrato,tipo,titulo) values('+q(doc)+','+q(org)+','+q(contract)+",'contrato','Local quarantine document');insert into public.versoes_documento(id,id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash) values("+q(version)+','+q(org)+','+q(contract)+','+q(doc)+',1,'+q(file_id)+','+q(sha)+');insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values('+q(org)+','+q(contract)+','+q(version)+",'documents','pendente'),("+q(org)+','+q(contract)+','+q(version)+",'ocr','concluido');commit;")
    def job(tenant,contract_id,queue='documents'):
        return runner.sql('select privado.enfileirar_job('+q(queue)+','+q(tenant)+','+q(contract_id)+",'versao_documento',"+q(version)+",'{}'::jsonb,null);",True)
    pending=job(org,contract);complete=job(org,contract,'ocr');foreign=job(*scope[2])
    runner.sql("select pgmq.delete('ocr',message_id) from public.execucoes_assincronas where id="+q(complete)+";update public.execucoes_assincronas set status='concluido' where id="+q(complete)+';')
    result=runner.quarantine_document_jobs(f,max_wait_seconds=0)
    assert result['active_jobs']==0 and result['cancelled_jobs']==1
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(pending)+';',True)=='cancelado'
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(complete)+';',True)=='concluido'
    assert runner.sql("select status from public.execucoes_assincronas where id="+q(foreign)+';',True)=='enfileirado'
    assert runner.sql("select status from public.processamentos_documento where id_versao_documento="+q(version)+" and etapa='documents';",True)=='cancelado'
    assert runner.sql("select status from public.processamentos_documento where id_versao_documento="+q(version)+" and etapa='ocr';",True)=='concluido'
    orphan=int(runner.sql("select pgmq.send('documents',jsonb_build_object('id_organizacao',"+q(org)+",'id_contrato',"+q(contract)+"));",True))
    try:runner.quarantine_document_jobs(f,max_wait_seconds=0)
    except RuntimeError:pass
    else:raise AssertionError('Orphan queue message was falsely called clean')
    runner.sql("select pgmq.delete('documents',"+str(orphan)+');')
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
        if 'DOCUMENT_QUARANTINE_PENDING' in source and not started:
            started=True;app='local_document_race_'+nonce
            worker_sql="set application_name="+q(app)+";begin;do $worker$ begin perform 1 from pgmq.q_documents message join public.execucoes_assincronas e on e.message_id=message.msg_id where e.id="+q(racing)+" for update of message,e;update public.execucoes_assincronas set status='processando' where id="+q(racing)+";end $worker$;select pg_sleep(1);commit;"
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
    runner.sql("select pgmq.delete('documents',message_id) from public.execucoes_assincronas where id in ("+q(active)+','+q(foreign)+','+q(racing)+");update public.execucoes_assincronas set status='cancelado' where id in ("+q(active)+','+q(foreign)+','+q(racing)+');')
    print('DOCUMENT_QUARANTINE_LOCAL_SQL_PASS')
def main():
    if '--self-test' in sys.argv:self_test();return 0
    if '--local-document-quarantine-proof' in sys.argv:local_document_quarantine_proof();return 0
    r=Runner(os.environ)
    if '--cleanup' in sys.argv:
        if (r.root/'report.json').exists():r.report=json.loads((r.root/'report.json').read_text())
        r.cleanup();return 0
    failed=False
    try:
        r.prepare()
        p=subprocess.run(['node','supabase/tests/p0_crud_global_browser.mjs'],env=browser_environment(os.environ),capture_output=True,text=True,timeout=1200)
        r.check('REAL_BROWSER_BATCH',p.returncode==0)
        r.verify();r.report['state']='PASS_BATCH';r.report['completed_domains']=['auditoria'] if r.batch=='AUDITORIA' else ['organizacoes','contratantes','contratos','listas'];r.report['unverified_domains']=['regras_preventivas','base_normativa','orcamento','documentos_contrato','documento_detalhe','competencias','documentos_competencia','analise_revisao','parecer','apresentacao','protocolo','historico','administracao','auditoria']
        if r.batch=='AUDITORIA':r.report['unverified_domains'].remove('auditoria');r.report['prior_pass_domains']=['organizacoes','contratantes','contratos','listas']
    except Exception as e:
        failed=True;r.report['state']='FAIL';r.report['failure_class']=type(e).__name__
    finally:
        try:r.cleanup()
        except Exception:failed=True;r.report['state']='CLEANUP_FAILED'
        r.save('report.json',r.report)
    print('CRUD_GLOBAL_BATCH_'+('FAIL' if failed else 'PASS')+'; sanitized report and own quarantine recorded')
    return 1 if failed else 0
if __name__=='__main__':sys.exit(main())
