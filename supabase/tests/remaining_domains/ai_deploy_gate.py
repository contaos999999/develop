"""Read-only gate binding a verified HML worker deployment to this approved HEAD."""
import hashlib,re,json
from datetime import datetime,timedelta
from pathlib import Path
FILES=('supabase/functions/queue-worker-ai/index.ts','supabase/functions/queue-worker-ai/job-envelope.mjs')
def runtime_route(task,event):
    proof=task.get('remaining_certification',{}).get('approved_ai_worker_deploy')
    return event in (('workflow_run','workflow_dispatch') if proof else ('workflow_run',))
def instant(value):
    assert isinstance(value,str)
    result=datetime.fromisoformat(value.replace('Z','+00:00'))
    assert result.tzinfo is not None and result.utcoffset()==timedelta(0)
    return result

def verify_ci_binding(restore,checks,head):
    assert restore['head_sha']==head and restore['head_branch']=='main' and restore['event']=='push' and restore['status']=='completed' and restore['conclusion']=='success' and restore['name']=='ContaOS Restore Isolado'
    bounds=[instant(restore['updated_at'])]
    assert bounds[0]>=instant(restore['created_at'])
    for name in ('guard','reconstruir-banco-do-zero','prova-backup-dados-sinteticos-duas-instancias'):
        matches=[c for c in checks if c['name']==name and c['head_sha']==head]
        assert matches,name
        latest=max(matches,key=lambda c:c['id'])
        assert latest['conclusion']=='success',name
        bounds.append(instant(latest['completed_at']))
    return max(bounds).isoformat()

def validate_receipt(task,head,receipt,root=Path('.'),not_before=None,comment_created_at=None):
    assert re.fullmatch('[0-9a-f]{40}',head)
    assert set(receipt)=={'schema','backend_head','project','function_slug','version','prior_version','verify_jwt','status','readback_equal','source_sha256','prior_source_sha256','management_bundle_sha256','active_ai_jobs_before','active_ai_jobs_after','deployed_at','verified_at'}
    proof=task['remaining_certification']['approved_ai_worker_deploy']
    assert task['remaining_certification']['project']=='gklhhhyosgasnyoxlrui'
    assert proof['project']=='gklhhhyosgasnyoxlrui' and proof['function_slug']=='queue-worker-ai'
    assert proof['from_version']==4 and proof['expected_version']==5 and proof['verify_jwt'] is False
    expected=proof['source_sha256'];assert set(expected)==set(FILES)
    assert all(re.fullmatch('[0-9a-f]{64}',v) and hashlib.sha256((root/p).read_bytes()).hexdigest()==v for p,v in expected.items())
    assert receipt['schema']=='contaos.ai-worker-deployment.v1' and receipt['backend_head']==head
    assert receipt['project']==proof['project'] and receipt['function_slug']==proof['function_slug']
    assert receipt['version']==proof['expected_version'] and receipt['prior_version']==proof['from_version']
    assert receipt['verify_jwt'] is False and receipt['status']=='ACTIVE' and receipt['readback_equal'] is True
    assert receipt['source_sha256']==expected and receipt['prior_source_sha256']==proof['prior_source_sha256']
    assert re.fullmatch('[0-9a-f]{64}',receipt['management_bundle_sha256'])
    assert type(receipt['active_ai_jobs_before']) is int and receipt['active_ai_jobs_before']==0
    assert type(receipt['active_ai_jobs_after']) is int and receipt['active_ai_jobs_after']==0
    deployed,verified=instant(receipt['deployed_at']),instant(receipt['verified_at'])
    assert deployed<=verified
    if not_before is not None:assert deployed>=instant(not_before) and verified>=instant(not_before)
    if comment_created_at is not None:
        created=instant(comment_created_at)
        assert verified<=created
        if not_before is not None:assert created>=instant(not_before)
    return receipt

def find_deployment_receipt(task,head,comments,root=Path('.'),not_before=None):
    assert isinstance(comments,list) and len(comments)<100
    matches=[]
    for comment in comments:
        if comment.get('user',{}).get('login')!='contaos9999' or comment.get('issue_url')!='https://api.github.com/repos/contaos999999/develop/issues/138':continue
        try:body=json.loads(comment['body'])
        except (ValueError,KeyError,TypeError):continue
        if not isinstance(body,dict) or body.get('schema')!='contaos.ai-worker-deployment.v1' or body.get('backend_head')!=head:continue
        receipt=validate_receipt(task,head,body,root,not_before=not_before,comment_created_at=comment['created_at'])
        assert type(comment['id']) is int and comment['id']>0
        matches.append((comment['id'],receipt))
    assert len(matches)==1,'RUNTIME_DEPLOYMENT_PENDING_OR_AMBIGUOUS_NO_HML_ACCESS'
    return matches[0]
