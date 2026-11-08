#!/usr/bin/env bash
# Native local-only containment. Never passes remote credentials to a container.
set -Eeuo pipefail
exec python3 - "$@" <<'PY'
import ipaddress,json,os,re,socket,subprocess,sys,threading,time

def require(ok,message):
    if not ok:raise RuntimeError(message)
require(os.environ.get('GITHUB_ACTIONS')=='true' and os.environ.get('GITHUB_REPOSITORY')=='contaos999999/develop','Canonical isolated runner required')
require(not any(os.environ.get(k) for k in ('DATABASE_URL','SUPABASE_DB_URL','SUPABASE_ACCESS_TOKEN')),'Remote credentials forbidden')
run=os.environ.get('GITHUB_RUN_ID','');attempt=os.environ.get('GITHUB_RUN_ATTEMPT','');job=os.environ.get('GITHUB_JOB','')
require(re.fullmatch(r'[0-9]+',run) and re.fullmatch(r'[0-9]+',attempt) and job in ('restore','synthetic-data-restore'),'Exact local run identity required')
name='contaos-proof-'+run+'-'+attempt+'-'+job
container='supabase_db_contaos-hml-local'
labels={'com.contaos.scope':'isolated-db-proof','com.contaos.run':run,'com.contaos.attempt':attempt,'com.contaos.job':job}
def capture(args):return subprocess.run(args,text=True,capture_output=True,timeout=30)
def metadata(args):
    p=capture(args);require(p.returncode==0,'Docker metadata unavailable')
    result=json.loads(p.stdout);require(isinstance(result,list) and len(result)==1,'Exact Docker object required');return result[0]
def network():
    exists=capture(['docker','network','inspect',name])
    if exists.returncode:
        args=['docker','network','create','--internal']
        for key,value in labels.items():args+=['--label',key+'='+value]
        subprocess.run(args+[name],check=True,stdout=subprocess.DEVNULL,timeout=30)
    n=metadata(['docker','network','inspect',name])
    require(n.get('Name')==name and n.get('Internal') is True and all(n.get('Labels',{}).get(k)==v for k,v in labels.items()),'Unowned or noninternal Docker network')
    subnets=[ipaddress.ip_network(x['Subnet']) for x in n['IPAM']['Config'] if 'Subnet' in x]
    require(bool(subnets),'Internal network subnet required');return subnets
def existing_container():
    p=capture(['docker','inspect',container])
    if p.returncode:return None
    data=json.loads(p.stdout);require(isinstance(data,list) and len(data)==1,'Exact local container required');return data[0]
def sole_network(c):
    require(c.get('Name')=='/'+container and set(c['NetworkSettings']['Networks'])=={name},'Unexpected local container attachment')
def native_proof(subnets):
    c=existing_container();require(c is not None,'Local Postgres container required');sole_network(c)
    # UDP connect selects the host interface without sending a datagram.
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as route:
        route.connect(('192.0.2.1',9));address=route.getsockname()[0]
    ip=ipaddress.ip_address(address)
    require(not ip.is_loopback and not any(ip in subnet for subnet in subnets),'Controlled host endpoint must be outside internal subnet')
    listener=socket.socket();listener.bind((address,0));listener.listen(4);listener.settimeout(.1)
    port=listener.getsockname()[1];accepted=[];stop=threading.Event()
    def serve():
        while not stop.is_set():
            try:client,_=listener.accept();accepted.append(True);client.close()
            except socket.timeout:pass
            except OSError:
                if not stop.is_set():raise
    thread=threading.Thread(target=serve,daemon=True);thread.start()
    def positive(expected):
        with socket.create_connection((address,port),timeout=2):pass
        deadline=time.monotonic()+2
        while len(accepted)<expected and time.monotonic()<deadline:time.sleep(.01)
        require(len(accepted)==expected,'Controlled host TCP positive failed')
    try:
        positive(1)
        script='''command -v timeout >/dev/null || exit 90
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5432' >/dev/null 2>&1 || exit 91
timeout 3 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' proof "$1" "$2" >/dev/null 2>&1
code=$?
case "$code" in 1|124) exit 0;; *) exit 92;; esac'''
        p=capture(['docker','exec',container,'bash','-c',script,'proof',address,str(port)])
        require(p.returncode==0,'Native isolated TCP denial or local positive failed')
        time.sleep(.2);require(len(accepted)==1,'Isolated container reached controlled host endpoint')
        positive(2)
        sole_network(metadata(['docker','inspect',container]));network()
        proof={'state':'PASS_NATIVE_LOCAL_EGRESS_DENY','head':os.environ.get('GITHUB_SHA'),'operation':list(operation),'internal':True,'sole_network':True,'host_positive_controls':2,'container_loopback_positive':True,'isolated_receiver_connections':0}
        from pathlib import Path
        output=Path('restore-proof' if job=='restore' else 'restore-proof-synthetic')/'isolated-db-network.jsonl'
        require(output.parent.is_dir(),'Owned local proof directory required')
        with output.open('a') as stream:stream.write(json.dumps(proof)+'\n')
        print('ISOLATED_DATABASE_NATIVE_EGRESS_DENY_PASS host_positive=2 container_loopback_positive=1 isolated_receiver_connections=0 internal=true sole_network=true')
    finally:stop.set();thread.join(timeout=1);listener.close()

args=sys.argv[1:]
require(args and args[0]=='run','Explicit local operation required');operation=tuple(args[1:])
require(operation in (('db','start'),('db','reset','--local','--no-seed'),('stop','--no-backup'),('migration','list','--local')),'Remote or unsupported operation forbidden')
subnets=network();current=existing_container()
if current is not None:sole_network(current)
subprocess.run(['supabase','--network-id',name,*operation],check=True)
if operation[0]=='stop':
    require(existing_container() is None,'Local container remained active')
else:native_proof(network())
PY
