"""HML-only API boundary proof. Never prints credentials, response bodies or queue rows."""
import argparse,json,os,re,secrets,subprocess,sys,uuid,urllib.request,urllib.error,urllib.parse
from pathlib import Path
URL='https://gklhhhyosgasnyoxlrui.supabase.co'
KEY='sb_publishable_sHKZ-UiYCbkEFMqR1QbHMA_iCSLL8Am'
SCOPE='CONTAOS_WORKER_API_BOUNDARY'
TRUSTED_LOGINS=('authenticator','pgbouncer','postgres','supabase_admin','supabase_auth_admin','supabase_etl_admin','supabase_functions_admin','supabase_read_only_user','supabase_replication_admin','supabase_storage_admin')
class BoundaryError(Exception):pass
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise BoundaryError('REDIRECT_DENIED')
def api_denied(status,body):return type(status) is int and status==406 and isinstance(body,dict) and body.get('code')=='PGRST106'
def metadata_valid(data,stage):
    base={'application_logins_closed':True,'trusted_logins_only':True,'destination_is_hml':True,'token_present':True,'cron_active':True}
    if stage not in ('preinstall','postinstall'):return False
    ready=stage=='postinstall';expected={**base,'extension_present':ready,'extension_ready':ready,'scheduler_access':ready}
    return isinstance(data,dict) and set(data)==set(expected) and all(type(data[k]) is bool and data[k] is v for k,v in expected.items())
def own_record(user,nonce,intent,email,expected_id=None):
    if not isinstance(user,dict):return False
    try:valid_id=str(uuid.UUID(user.get('id','')))==user['id']
    except (ValueError,TypeError,AttributeError,KeyError):return False
    meta=user.get('app_metadata')
    return valid_id and (expected_id is None or user['id']==expected_id) and user.get('email')==email and isinstance(meta,dict) and meta.get('scope')==SCOPE and meta.get('boundary_nonce')==nonce and meta.get('fixture_request_id')==intent

def metadata_sql():
    allowed=','.join("'"+x+"'" for x in TRUSTED_LOGINS)
    return """select json_build_object(
      'extension_present',exists(select 1 from pg_extension where extname='pg_net'),
      'extension_ready',exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pg_net' and n.nspname='extensions'),
      'scheduler_access',coalesce(has_schema_privilege('postgres',(select oid from pg_namespace where nspname='net'),'USAGE') and has_function_privilege('postgres',to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)'),'EXECUTE'),false),
      'application_logins_closed',(select count(*)=2 and bool_and(not rolcanlogin) from pg_roles where rolname in ('anon','authenticated')),
      'trusted_logins_only',not exists(select 1 from pg_roles where rolcanlogin and rolname not in ("""+allowed+""")),
      'destination_is_hml',(select count(*)=1 and bool_and(decrypted_secret='https://gklhhhyosgasnyoxlrui.supabase.co') from vault.decrypted_secrets where name='contaos_project_url'),
      'token_present',(select count(*)=1 and bool_and(length(decrypted_secret)>0) from vault.decrypted_secrets where name='contaos_internal_worker_token'),
      'cron_active',exists(select 1 from cron.job where jobname='contaos-workers-rapidos' and active));"""
class Probe:
    def __init__(self,env,stage,report):
        if env.get('GITHUB_ACTIONS')!='true' or env.get('GITHUB_REPOSITORY')!='contaos999999/develop':raise BoundaryError('CANONICAL_RUNNER_REQUIRED')
        self.head=env.get('EXPECTED_SOURCE_SHA','')
        if not re.fullmatch('[0-9a-f]{40}',self.head):raise BoundaryError('SOURCE_REQUIRED')
        if subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()!=self.head:raise BoundaryError('SOURCE_MISMATCH')
        if stage not in ('preinstall','postinstall'):raise BoundaryError('INVALID_STAGE')
        task=json.loads(Path('docs/tasks/active-task.json').read_text())
        approval=task.get('document_worker_runtime_gate',{}).get('api_boundary_complement',{})
        if approval.get('gate_pr')!=158 or approval.get('new_build_authorized') is not True:raise BoundaryError('APPROVED_BOUNDARY_GATE_REQUIRED')
        self.db=env.get('DATABASE_URL','');u=urllib.parse.urlsplit(self.db)
        if u.scheme not in ('postgres','postgresql') or u.username!='postgres.gklhhhyosgasnyoxlrui' or not (u.hostname or '').endswith('.pooler.supabase.com'):raise BoundaryError('WRONG_DATABASE')
        self.admin=env.get('AUTH_ADMIN_KEY','')
        if not self.admin:raise BoundaryError('AUTH_ADMIN_REQUIRED')
        self.stage=stage;self.report_path=Path(report).resolve();root=Path(env['RUNNER_TEMP']).resolve()
        if not self.report_path.is_relative_to(root) or not self.report_path.name.endswith('-report.json'):raise BoundaryError('PRIVATE_REPORT_PATH_REQUIRED')
        self.report_path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
        self.nonce=uuid.uuid4().hex;self.intent=str(uuid.uuid4());self.email='worker-boundary-'+self.nonce+'@example.invalid'
        self.user_id=None;self.creation_attempted=False;self.create_outcome="not_started"
        self.report={'schema':'contaos.worker-api-boundary.v1','head':self.head,'stage':stage,'state':'RUNNING','assertions':[],'cleanup':'NOT_REQUIRED','recovery':{'scope':SCOPE,'nonce':self.nonce,'intent_id':self.intent}}
        self.opener=urllib.request.build_opener(NoRedirect())
    def save(self):
        tmp=self.report_path.with_suffix('.tmp');tmp.write_text(json.dumps(self.report,indent=2)+'\n');os.chmod(tmp,0o600);tmp.replace(self.report_path)
    def check(self,name,passed,status=None):
        self.report['assertions'].append({'name':name,'passed':passed is True,'status':status});self.save()
        if passed is not True:raise BoundaryError(name)
    def request(self,path,data=None,token=None,admin=False,method=None,profile=None):
        auth_path=path.startswith('/auth/v1/')
        if not (auth_path or path.startswith('/rest/v1/')) or (admin and not path.startswith('/auth/v1/admin/users')):raise BoundaryError('UNEXPECTED_DESTINATION')
        headers={'apikey':self.admin if admin else KEY,'Content-Type':'application/json'}
        if admin or token:headers['Authorization']='Bearer '+(self.admin if admin else token)
        if profile:
            if profile not in ('public','net'):raise BoundaryError('INVALID_PROFILE')
            headers['Accept-Profile']=profile
        req=urllib.request.Request(URL+path,data=None if data is None else json.dumps(data).encode(),headers=headers,method=method)
        try:
            with self.opener.open(req,timeout=25) as response:status=response.status;raw=response.read(4194305)
        except urllib.error.HTTPError as error:status=error.code;raw=error.read(4194305)
        except Exception:return 0,{}
        if len(raw)>4194304:return 0,{}
        try:return status,json.loads(raw) if raw else {}
        except (ValueError,UnicodeError):return status,{}
    def read_metadata(self):
        result=subprocess.run(['psql',self.db,'-X','-qAt','-v','ON_ERROR_STOP=1'],input=metadata_sql(),text=True,capture_output=True,timeout=45)
        if result.returncode:raise BoundaryError('METADATA_UNAVAILABLE')
        return json.loads(result.stdout)
    def find_owned(self):
        matches=[]
        for page in range(1,6):
            status,data=self.request('/auth/v1/admin/users?page='+str(page)+'&per_page=1000',admin=True)
            if status!=200 or not isinstance(data,dict) or not isinstance(data.get('users'),list):raise BoundaryError('RECOVERY_UNAVAILABLE')
            users=data['users'];matches.extend(u for u in users if own_record(u,self.nonce,self.intent,self.email))
            if len(users)<1000:break
        else:raise BoundaryError('RECOVERY_PAGINATION_INCOMPLETE')
        if len(matches)>1:raise BoundaryError('RECOVERY_IDENTITY_AMBIGUOUS')
        return matches[0]['id'] if matches else None
    @staticmethod
    def absent(status,data):return status==404 and isinstance(data,dict) and (data.get('error_code')=='user_not_found' or data.get('code')=='user_not_found')
    def cleanup(self):
        if not self.creation_attempted:return True
        self.user_id=self.user_id or self.find_owned()
        if self.user_id is None and self.create_outcome=="uncertain":raise BoundaryError("CREATE_OUTCOME_UNRESOLVED")
        if self.user_id:
            status,user=self.request('/auth/v1/admin/users/'+self.user_id,admin=True)
            if not self.absent(status,user):
                if status!=200 or not own_record(user,self.nonce,self.intent,self.email,self.user_id):raise BoundaryError('CLEANUP_IDENTITY_MISMATCH')
                self.request('/auth/v1/admin/users/'+self.user_id,admin=True,method='DELETE')
                status,user=self.request('/auth/v1/admin/users/'+self.user_id,admin=True)
                if not self.absent(status,user):raise BoundaryError('CLEANUP_ABSENCE_NOT_CONFIRMED')
        if self.find_owned() is not None:raise BoundaryError('CLEANUP_RESIDUE')
        return True
    def run(self):
        passed=False
        try:
            self.check('HML_METADATA_AND_LOGINS',metadata_valid(self.read_metadata(),self.stage))
            status,_=self.request('/rest/v1/',profile='public');self.check('PUBLIC_API_CONTROL_ANON',status==200,status)
            path='/rest/v1/http_request_queue?select=id&limit=0'
            status,data=self.request(path,profile='net');self.check('NET_SCHEMA_DENIED_ANON',api_denied(status,data),status)
            self.creation_attempted=True;self.create_outcome='uncertain';self.report['cleanup']='REQUIRED';self.save()
            password=secrets.token_urlsafe(40)+'Aa1!'
            status,user=self.request('/auth/v1/admin/users',{'email':self.email,'password':password,'email_confirm':True,'app_metadata':{'scope':SCOPE,'boundary_nonce':self.nonce,'fixture_request_id':self.intent}},admin=True)
            if 400<=status<500:self.create_outcome='rejected'
            if status in (200,201) and own_record(user,self.nonce,self.intent,self.email):self.create_outcome='confirmed'
            self.check('OWN_AUTH_CREATED',self.create_outcome=='confirmed',status)
            self.user_id=user['id'];self.report['recovery']['user_id']=self.user_id;self.save()
            status,session=self.request('/auth/v1/token?grant_type=password',{'email':self.email,'password':password})
            token=session.get('access_token') if isinstance(session,dict) else None
            self.check('AUTHENTICATED_SESSION_CREATED',status==200 and isinstance(token,str) and bool(token),status)
            status,user=self.request('/auth/v1/user',token=token);self.check('AUTHENTICATED_IDENTITY_CONFIRMED',status==200 and isinstance(user,dict) and user.get('id')==self.user_id,status)
            status,_=self.request('/rest/v1/',token=token,profile='public');self.check('PUBLIC_API_CONTROL_AUTHENTICATED',status==200,status)
            status,data=self.request(path,token=token,profile='net');self.check('NET_SCHEMA_DENIED_AUTHENTICATED',api_denied(status,data),status)
            passed=True
        except Exception:self.report['state']='FAIL'
        finally:
            try:
                self.cleanup()
                self.report['cleanup']='OWN_AUTH_ABSENT_CONFIRMED' if self.creation_attempted else 'NOT_REQUIRED'
            except Exception:self.report['cleanup']='FAILED';passed=False
            self.report['state']='PASS' if passed else 'FAIL';self.save()
        return passed

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--stage',choices=('preinstall','postinstall'),required=True);parser.add_argument('--report',required=True);args=parser.parse_args()
    try:
        probe=Probe(os.environ,args.stage,args.report);ok=probe.run()
        print('WORKER_API_BOUNDARY_'+('PASS' if ok else 'FAIL')+' stage='+args.stage+' cleanup='+probe.report['cleanup'])
        return 0 if ok else 1
    except Exception:
        print('WORKER_API_BOUNDARY_FAIL configuration_or_runner');return 1
if __name__=='__main__':sys.exit(main())
