"""Domain-isolated HML proofs. No browser/admin transfer; no documentary replay."""
import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import sys
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from p0_crud_global_hml import Runner as FixtureRunner, URL, KEY, q, uid

DOMAINS=('base_normativa','orcamento','competencias','regras_preventivas','documento_detalhe','documentos_competencia','historico','administracao','apresentacao')
PROTECTED=('supabase/tests/p0_crud_global_browser.mjs','supabase/tests/p0_crud_global_hml.py','supabase/tests/p0_crud_global_protocol.test.mjs','supabase/functions/storage-sign-upload/index.ts','supabase/functions/storage-sign-download/index.ts')
REQUIRED={
 'base_normativa':{'rpc':('salvar_fonte_normativa_v107','registrar_versao_fonte_v107','aprovar_versao_fonte_v107','definir_aplicabilidade_fonte_v107'),'checks':('NORMATIVE_REPLAY_EXACT','NORMATIVE_CAS_RACE','NORMATIVE_SQL_PERSISTENCE','NORMATIVE_AUDIT_PRESENT','NORMATIVE_READER_READ','NORMATIVE_TENANT_ISOLATED','NORMATIVE_REVOKED_SESSION_DENIED')},
 'orcamento':{'rpc':('salvar_proposta_orcamentaria_v108','registrar_versao_proposta_v108','salvar_linha_orcamentaria_v108','remover_linha_orcamentaria_v108','publicar_versao_proposta_v108','confirmar_upload_arquivo','criar_documento_contrato_completo'),'checks':('BUDGET_REPLAY_EXACT','BUDGET_SOURCE_WORKER_READY','OWN_PHYSICAL_SOURCE_UPLOADED','OWN_PHYSICAL_SOURCE_SQL','BUDGET_SQL_PERSISTENCE','BUDGET_AUDIT_PRESENT','BUDGET_READER_READ','BUDGET_TENANT_ISOLATED')},
 'competencias':{'rpc':('criar_competencia','obter_visao_geral_competencia','executar_comando_lista_v1'),'checks':('COMPETENCE_OVERVIEW_SCOPE','COMPETENCE_NO_GATE_BYPASS','COMPETENCE_READER_READ','COMPETENCE_TENANT_ISOLATED','COMPETENCE_DUPLICATE_REJECTED','COMPETENCE_INVALID_REFERENCE_REJECTED','COMPETENCE_SQL_PERSISTENCE','COMPETENCE_REAL_AUDIT','COMPETENCE_SNAPSHOT_MATERIALIZED','COMPETENCE_SNAPSHOT_IMMUTABLE','COMPETENCE_SNAPSHOT_TENANT_ISOLATED','COMPETENCE_SNAPSHOT_SQL')}
,
 'regras_preventivas':{'rpc':('salvar_fonte_normativa_v107','registrar_versao_fonte_v107','aprovar_versao_fonte_v107','aprovar_regra_preventiva'),'checks':('PREVENTIVE_DENIAL_UNCHANGED','PREVENTIVE_READER_READ','PREVENTIVE_TENANT_ISOLATED','PREVENTIVE_NO_DIRECT_PROMOTION','PREVENTIVE_SQL_APPROVAL','PREVENTIVE_AUDIT')},
 'documento_detalhe':{'rpc':('confirmar_upload_arquivo','criar_documento_contrato_completo','definir_vigencia_sugestao_extracao','revisar_sugestao_extracao'),'checks':('OWN_PHYSICAL_SOURCE_UPLOADED','OWN_PHYSICAL_SOURCE_SQL','OWN_DOCUMENT_WORKER_READY','DETAIL_SYNTHETIC_QUEUE_QUIESCED','DETAIL_METADATA_CONCURRENT_SINGLE_APPEND','DETAIL_METADATA_APPEND_RECEIPT','DETAIL_METADATA_OLD_ROW_IDENTICAL','DETAIL_METADATA_APPEND_ONLY','DETAIL_VIGENCY_NOOP','DETAIL_REVIEW_CLASSIFICACAO','DETAIL_REVIEW_METADADO','DETAIL_REVIEW_OBRIGACAO','DETAIL_REVIEW_PRAZO','DETAIL_READER_PAGES','DETAIL_TENANT_ISOLATED','DETAIL_SQL_REVIEW','DETAIL_SQL_VIGENCY','DETAIL_AUDIT')},
 'documentos_competencia':{'rpc':('criar_competencia','confirmar_upload_arquivo','criar_documento_competencia_v115','adicionar_versao_documento_competencia_v115','obter_documentos_competencia_v115'),'checks':('OWN_PHYSICAL_SOURCE_UPLOADED','OWN_PHYSICAL_SOURCE_SQL','OWN_DOCUMENT_WORKER_READY','COMP_DOC_CREATE_REPLAY','COMP_DOC_VERSION_REPLAY','COMP_DOC_READER_READ','COMP_DOC_TENANT_ISOLATED','COMP_DOC_SQL_HISTORY','COMP_DOC_OFFICIAL_READ','COMP_DOC_AUDIT')}
,
 'historico':{'rpc':('confirmar_upload_arquivo','criar_documento_contrato_completo','registrar_relatorio_historico_hml','enfileirar_ingestao_historica_hml','vincular_tratamento_historico_hml'),'checks':('HISTORY_PHYSICAL_UPLOAD','HISTORY_PHYSICAL_SQL','OWN_DOCUMENT_WORKER_READY','HISTORY_REGISTRATION_REPLAY','HISTORY_QUEUE_REPLAY','HISTORY_REAL_MARKED_FINDING','HISTORY_READER_READ','HISTORY_TENANT_ISOLATED','HISTORY_SQL_TREATMENT','HISTORY_AUDIT')},
 'administracao':{'rpc':('salvar_vinculo_usuario_adm','listar_escopo_contratos_usuario_adm'),'master_rpc':('obter_matriz_rbac_master','atualizar_matriz_rbac_master'),'edge':('admin-invite-user',),'checks':('ADMIN_EXISTING_EDGE_NO_EMAIL','ADMIN_EXISTING_EDGE_REPLAY','ADMIN_EXISTING_EDGE_CONFLICT','ADMIN_SQL_EDGE_RECEIPT','ADMIN_BINDING_REPLAY','ADMIN_SCOPED_CONTRACT','ADMIN_READER_SCOPED_READ','ADMIN_SCOPE_REVOKED_REAL_JWT','ADMIN_MATRIX_REPLAY','ADMIN_MATRIX_NO_PERMISSION_DELTA','ADMIN_SQL_BINDING','ADMIN_SQL_MATRIX_RECEIPT','ADMIN_AUDIT')},
 'apresentacao':{'covers':['parecer','apresentacao','protocolo'],'rpc':('salvar_fonte_normativa_v107','registrar_versao_fonte_v107','aprovar_versao_fonte_v107','definir_aplicabilidade_fonte_v107','executar_comando_lista_v1','criar_competencia','confirmar_upload_arquivo','criar_documento_competencia_v115','adicionar_versao_documento_competencia_v115','solicitar_analise_competencia','obter_contexto_revisao_v117','registrar_revisao_requisito_v117','avaliar_portao_conformidade','solicitar_parecer_interno','aprovar_apresentacao','registrar_apresentacao'),'master_rpc':('aprovar_parecer_interno',),'checks':('FLOW_FORMAL_SOURCE','FLOW_MANDATORY_REQUIREMENT','OWN_PHYSICAL_SOURCE_UPLOADED','OWN_PHYSICAL_SOURCE_SQL','OWN_DOCUMENT_WORKER_READY','FLOW_REAL_AI_ANALYSIS','FLOW_AI_RESULT_CONTEXT','FLOW_REVIEW_CONTEXT_CURRENT','FLOW_REAL_GATE_100','FLOW_REAL_AI_OPINION','FLOW_SQL_OPINION_APPROVAL','FLOW_STALE_CONTEXT_BLOCKED','FLOW_PROTOCOL_REPLAY','FLOW_READER_PROTOCOL','FLOW_TENANT_ISOLATED','FLOW_SQL_FROZEN_PACKAGE','FLOW_SQL_HISTORY_AUDIT')}
}
def assert_complete(report,domain):
    required=REQUIRED[domain];assert report['domain']==domain and report['global_complete'] is False
    checks=report['assertions'];receipts=report['receipts']
    assert checks and all(c.get('passed') is True for c in checks)
    assert all(any(c.get('name')==name and c.get('passed') is True for c in checks) for name in required['checks'])
    assert all(any(r.get('operation')==name and r.get('http')==200 and r.get('role')=='administrador' for r in receipts) for name in (*required['rpc'],*required.get('edge',())))
    assert all(any(r.get('operation')==name and r.get('http')==200 and r.get('role')=='master' for r in receipts) for name in required.get('master_rpc',()))
    for role in ('leitor','usuario_b','anon'):
        assert any(r.get('role')==role and r.get('http') in ((401,403) if role=='anon' else (403,)) for r in receipts)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):return None

def selected_domains(task):
    assert task['id']=='P0-CRUD-GLOBAL-HML-20261107' and task['phase']=='BUILD_CERTIFICACAO_DOMINIOS_RESTANTES'
    config=task['remaining_certification']
    assert config['project']=='gklhhhyosgasnyoxlrui' and config['mode']=='DOMAIN_ISOLATED_REAL_JWT_SQL_RECEIPTS'
    domains=config['domains_to_run']
    assert isinstance(domains,list) and domains and len(domains)==len(set(domains)) and all(d in DOMAINS for d in domains)
    assert task['database_test_fixtures_allowed'] is True and task['storage_test_fixtures_allowed'] is True
    return domains

def assert_preserved(root,task):
    proof=task['remaining_certification']['preserved_documental']
    assert proof['tested_head']=='3ef22a371c38e552f9f3c862646eee3242f02411' and proof['run']==42502405227 and proof['artifact']==13625479020
    assert proof['sha256']=='aa14586205ad8f133c46e9e2e188c828b95e11f2e82bd9cbc321b6b8337bf8ba' and proof['global_complete'] is False
    assert set(proof['protected_sha256'])==set(PROTECTED)
    for file in PROTECTED:
        original=subprocess.check_output(['git','show',proof['tested_head']+':'+file])
        assert hashlib.sha256(original).hexdigest()==proof['protected_sha256'][file]
        assert hashlib.sha256((root/file).read_bytes()).hexdigest()==proof['protected_sha256'][file],'Protected documentary dependency changed: '+file

def validate_target(url,upload=False,org=None,nonce=None):
    u=urllib.parse.urlsplit(url)
    assert u.scheme=='https' and u.netloc=='gklhhhyosgasnyoxlrui.supabase.co' and not u.username and not u.password and not u.fragment
    if upload:
        prefix='/storage/v1/object/upload/sign/contaos-documentos/'+org+'/uploads/'
        assert u.path.startswith(prefix) and '/crudg-'+nonce+'-' in u.path and '..' not in u.path and '%' not in u.path and chr(92) not in u.path
        assert set(urllib.parse.parse_qs(u.query))=={'token'}
    else:
        assert u.path.startswith(('/auth/v1/','/rest/v1/')) or u.path in ('/functions/v1/storage-sign-upload','/functions/v1/storage-sign-download','/functions/v1/admin-invite-user')
    return u

class Runner(FixtureRunner):
    def __init__(self,env,domain):
        task=json.loads(Path('docs/tasks/active-task.json').read_text())
        assert domain in selected_domains(task)
        assert_preserved(Path('.'),task)
        assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==env['TESTED_HEAD'],'Tested HEAD mismatch'
        super().__init__(env)
        self.domain=domain;self.material_enabled=True
        self.opener=urllib.request.build_opener(NoRedirect())
        self.report.update(schema='contaos.remaining-domain.hml.v1',domain=domain,state='RUNNING',global_complete=False,stage='PREPARE',receipts=[])
        self.tokens={};self.fixture=None
    def request(self,path,data=None,token=None,admin=False,method=None):
        url=URL+path;validate_target(url)
        assert not admin or path.startswith('/auth/v1/admin/users')
        headers={'apikey':self.admin if admin else KEY,'Content-Type':'application/json'}
        if admin or token:headers['Authorization']='Bearer '+(self.admin if admin else token)
        req=urllib.request.Request(url,data=None if data is None else json.dumps(data).encode(),headers=headers,method=method)
        return self.send(req)
    def send(self,req):
        if urllib.parse.urlsplit(req.full_url).path.startswith('/storage/'):
            validate_target(req.full_url,upload=True,org=self.fixture['org'],nonce=self.fixture['nonce'])
        else:validate_target(req.full_url)
        try:
            with self.opener.open(req,timeout=30) as response:
                raw=response.read(2_000_001);assert len(raw)<=2_000_000
                return response.status,json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            try:body=json.loads(error.read(20000))
            except (ValueError,UnicodeError):body={}
            return error.code,body
        except Exception:raise RuntimeError('Bounded own HML transport failed') from None
    def setup(self):
        names=sorted(set(REQUIRED[self.domain]['rpc'])|set(REQUIRED[self.domain].get('master_rpc',()))|{'exigir_permissao_rbac','rbac_permite','sessao_usuario_ativa','usuario_tem_acesso_contrato','usuario_possui_perfil'})
        metadata=self.sql("select coalesce(json_agg(x),'[]'::json) from (select n.nspname schema,p.proname name,pg_get_function_identity_arguments(p.oid) args,md5(p.prosrc) body_md5,p.prosecdef definer,p.proconfig config,pg_get_userbyid(p.proowner) owner,p.proacl::text acl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','privado') and p.proname in ("+','.join(q(n) for n in names)+') order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) x;',True)
        catalog=json.loads(metadata);assert catalog and all(any(c['name']==name for c in catalog) for name in names)
        self.report['dependency_catalog']=catalog
        self.report['dependency_catalog_sha256']=hashlib.sha256(json.dumps(catalog,sort_keys=True).encode()).hexdigest()
        self.fixture=self.prepare()
        for user in self.fixture['users']:
            st,data=self.request('/auth/v1/token?grant_type=password',{'email':user['email'],'password':user['password']})
            self.check('JWT_LOGIN_'+user['profile'].upper(),st==200 and isinstance(data,dict) and isinstance(data.get('access_token'),str),st)
            self.tokens[user['profile']]=data['access_token']
        self.report['dependency_sha256']={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in ['supabase/tests/p0_crud_global_remaining_hml.py','supabase/tests/remaining_domains/'+self.domain+'.py']}
        if self.domain in ('documento_detalhe','documentos_competencia','historico','apresentacao'):
            p='supabase/tests/remaining_domains/document_fixture.py';self.report['dependency_sha256'][p]=hashlib.sha256(Path(p).read_bytes()).hexdigest()
        if self.domain=='historico':
            p='supabase/tests/remaining_domains/history_quarantine.py';self.report['dependency_sha256'][p]=hashlib.sha256(Path(p).read_bytes()).hexdigest()
        self.save('report.json',self.report)
    def operation(self,name,payload,role='administrador',status=200,code=None):
        assert re.fullmatch('[a-z][a-z0-9_]{1,90}',name)
        self.report['stage']=name.upper();self.save('report.json',self.report)
        st,data=self.request('/rest/v1/rpc/'+name,payload,self.tokens.get(role))
        actual=data.get('code') if isinstance(data,dict) else None
        self.report['receipts'].append({'operation':name,'role':role,'http':st,'code':actual if isinstance(actual,str) and re.fullmatch('[A-Z0-9_]{1,30}',actual) else None})
        self.check(name.upper()+'_'+role.upper(),st==status and (code is None or actual==code),st)
        return data
    def deny(self,name,payload):
        for role in ('leitor','usuario_b'):
            self.operation(name,payload,role,status=403,code='42501')
        st,_=self.request('/rest/v1/rpc/'+name,payload)
        self.report['receipts'].append({'operation':name,'role':'anon','http':st})
        self.check('UNAUTHENTICATED_OPERATION_DENIED',st in (401,403),st)
    def read(self,table,query,role='administrador'):
        assert re.fullmatch('[a-z_]{1,80}',table)
        st,data=self.request('/rest/v1/'+table+'?'+urllib.parse.urlencode(query),token=self.tokens[role],method='GET')
        self.check('READ_'+table.upper()+'_'+role.upper(),st in (200,206) and isinstance(data,list),st)
        return data
    def sql_check(self,name,query):
        self.report['stage']=name;self.save('report.json',self.report)
        self.check(name,self.sql(query,True)=='t')
    def entity(self,key,value):
        assert str(__import__('uuid').UUID(value))==value
        self.report.setdefault('entities',{})[key]=value;self.save('report.json',self.report)
        return value
    def upload(self,label):
        f=self.fixture;assert re.fullmatch('[a-z0-9-]{1,40}',label)
        payload=('ContaOS own remaining '+f['nonce']+' '+label+'. No personal data.\n').encode()
        name='crudg-'+f['nonce']+'-'+label+'.txt';sha=hashlib.sha256(payload).hexdigest()
        intent={'name':name,'sha256':sha,'size':len(payload),'state':'INTENT'}
        f.setdefault('signed_uploads',[]).append(intent);self.save('fixture.json',f)
        st,signed=self.request('/functions/v1/storage-sign-upload',{'id_organizacao':f['org'],'id_contrato':f['contract'],'nome_arquivo':name,'mime':'text/plain','tamanho':len(payload)},self.tokens['administrador'])
        self.check('OWN_SOURCE_SIGN_UPLOAD',st==200 and isinstance(signed,dict) and signed.get('ok') is True,st)
        path=signed['path'];assert signed['bucket']=='contaos-documentos' and path.startswith(f['org']+'/uploads/') and path.endswith('/'+name)
        url=signed['signed_url'];u=validate_target(url,upload=True,org=f['org'],nonce=f['nonce'])
        assert u.path=='/storage/v1/object/upload/sign/contaos-documentos/'+path
        intent.update(path=path,state='SIGNED');self.save('fixture.json',f)
        req=urllib.request.Request(url,data=payload,method='PUT',headers={'apikey':KEY,'Content-Type':'text/plain','x-upsert':'false'})
        st,_=self.send(req);self.check('OWN_PHYSICAL_SOURCE_UPLOADED',st in (200,201),st)
        file=self.operation('confirmar_upload_arquivo',{'p_id_organizacao':f['org'],'p_id_contrato':f['contract'],'p_path':path,'p_nome_original':name,'p_mime':'text/plain','p_tamanho':len(payload),'p_sha256':sha,'p_origem':'upload_usuario'})
        intent.update(file=file,state='CONFIRMED');self.save('fixture.json',f)
        self.sql_check('OWN_PHYSICAL_SOURCE_SQL',"select exists(select 1 from public.arquivos a join storage.objects o on o.bucket_id=a.bucket and o.name=a.path where a.id="+q(file)+' and a.id_organizacao='+q(f['org'])+' and a.id_contrato='+q(f['contract'])+' and a.sha256='+q(sha)+' and a.tamanho='+str(len(payload))+');')
        return file
    def quarantine_document_jobs(self,f,max_wait_seconds=300):
        if self.domain!='historico':return super().quarantine_document_jobs(f,max_wait_seconds)
        from remaining_domains.history_quarantine import quarantine_document_jobs
        return quarantine_document_jobs(self,f,max_wait_seconds)
    def recover_document_uploads(self,f):
        # Independent own upload recovery; source files need not be document versions.
        assert f['scope']=='P0-CRUD-GLOBAL-HML' and re.fullmatch('[0-9a-f]{32}',f['nonce'])
        assert f['prefix']=='0000 CRUDG '+f['nonce']+' '
        intents=f.get('signed_uploads',[]);assert len(intents)<=8
        files=json.loads(self.sql("select coalesce(json_agg(a),'[]'::json) from (select id,nome_original,sha256,tamanho from public.arquivos where id_organizacao="+q(f['org'])+' and id_contrato='+q(f['contract'])+' and nome_original like '+q('crudg-'+f['nonce']+'-%')+' limit 9) a;',True))
        objects=json.loads(self.sql("select coalesce(json_agg(o),'[]'::json) from (select name from storage.objects where bucket_id='contaos-documentos' and name like "+q(f['org']+'/uploads/%/crudg-'+f['nonce']+'-%')+' limit 9) o;',True))
        assert len(files)<=8 and len(objects)<=8
        for row in files:
            match=[i for i in intents if i['name']==row['nome_original']];assert len(match)==1
            assert row['sha256']==match[0]['sha256'] and int(row['tamanho'])==match[0]['size']
        for row in objects:assert any(row['name'].endswith('/'+i['name']) for i in intents)
        self.report['source_receipts']=files;self.save('report.json',self.report)
        return {'preserved_uploads':len(files),'preserved_objects':len(objects)}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--domain',choices=DOMAINS,required=True);parser.add_argument('--cleanup',action='store_true');args=parser.parse_args()
    runner=Runner(os.environ,args.domain)
    if args.cleanup:
        if (runner.root/'report.json').exists():runner.report=json.loads((runner.root/'report.json').read_text())
        runner.cleanup();return 0
    failed=False
    try:
        runner.setup();importlib.import_module('remaining_domains.'+args.domain).run(runner)
        assert_complete(runner.report,args.domain)
        runner.report['state']='PASS_DOMAIN';runner.report['completed_domains']=REQUIRED[args.domain].get('covers',[args.domain])
    except Exception as error:
        failed=True;runner.report['state']='FAIL';runner.report['failure_class']=type(error).__name__
    finally:
        try:runner.cleanup()
        except Exception:failed=True;runner.report['state']='CLEANUP_FAILED'
        runner.save('report.json',runner.report)
    print('REMAINING_DOMAIN_'+('FAIL' if failed else 'PASS')+'; sanitized own evidence recorded')
    return 1 if failed else 0
if __name__=='__main__':sys.exit(main())
