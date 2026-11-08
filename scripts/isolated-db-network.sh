#!/usr/bin/env bash
# Native local-only containment. Never passes remote credentials to a container.
set -Eeuo pipefail
exec python3 - "$@" <<'PY'
import hashlib,ipaddress,json,os,re,shlex,socket,subprocess,sys,threading,time

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
        args=['docker','network','create','--ipv6=false']
        for key,value in labels.items():args+=['--label',key+'='+value]
        subprocess.run(args+[name],check=True,stdout=subprocess.DEVNULL,timeout=30)
    n=metadata(['docker','network','inspect',name])
    require(n.get('Name')==name and n.get('Internal') is False and n.get('EnableIPv6') is False and all(n.get('Labels',{}).get(k)==v for k,v in labels.items()),'Unowned or unsupported Docker network')
    subnets=[ipaddress.ip_network(x['Subnet']) for x in n['IPAM']['Config'] if 'Subnet' in x]
    private=[ipaddress.ip_network(x) for x in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16')]
    require(len(subnets)==1 and subnets[0].version==4 and any(subnets[0].subnet_of(x) for x in private),'Exact private IPv4 subnet required');return subnets
def existing_container():
    p=capture(['docker','inspect',container])
    if p.returncode:return None
    data=json.loads(p.stdout);require(isinstance(data,list) and len(data)==1,'Exact local container required');return data[0]
def sole_network(c):
    require(c.get('Name')=='/'+container and set(c['NetworkSettings']['Networks'])=={name},'Unexpected local container attachment')
    nic=c['NetworkSettings']['Networks'][name]
    require(not nic.get('GlobalIPv6Address') and not nic.get('IPv6Gateway'),'Unexpected IPv6 attachment')
chain='CTOS_'+hashlib.sha256(name.encode()).hexdigest()[:16]
return_rule=['-m','conntrack','--ctstate','ESTABLISHED','-m','comment','--comment',name,'-j','RETURN']
drop_rule=['-m','comment','--comment',name,'-j','DROP']
def iptables(args,missing=False):
    p=capture(['sudo','-n','iptables','-w','5',*args])
    if missing and p.returncode:return None
    require(p.returncode==0,'Owned native firewall operation failed');return p.stdout
def rules(target,missing=False):
    raw=iptables(['-S',target],missing)
    if raw is None:return None
    rows=[shlex.split(line) for line in raw.splitlines() if line.strip()]
    require(rows and rows[0][0] in ('-N','-P') and rows[0][1]==target,'Unexpected kernel chain metadata')
    require(all(row[:2]==['-A',target] for row in rows[1:]),'Unexpected kernel rule format');return [row[2:] for row in rows[1:]]
def firewall(subnets,install=False):
    policy=rules(chain,missing=install)
    if policy is None:
        iptables(['-N',chain]);iptables(['-A',chain,*return_rule]);iptables(['-A',chain,*drop_rule])
    require(rules(chain)==[return_rule,drop_rule],'Existing firewall policy diverges; never overwrite')
    for parent in ('DOCKER-USER','INPUT'):
        jump=['-s',str(subnets[0]),'-m','comment','--comment',name,'-j',chain]
        rows=rules(parent)
        if install and (not rows or rows[0]!=jump):
            require(jump not in rows,'Owned firewall priority changed');iptables(['-I',parent,'1',*jump])
        require(rules(parent)[0]==jump,'Owned source fence must precede other host/Docker rules')
    require(rules('FORWARD')[0]==['-j','DOCKER-USER'],'Docker forward fence must be first')
def dropped():
    raw=iptables(['-n','-v','-x','-L',chain]);matches=re.findall(r'^\s*(\d+)\s+\d+\s+DROP\s',raw,re.M)
    require(len(matches)==1,'Exact native DROP counter required');return int(matches[0])
def local_sql(sql):
    p=capture(['docker','exec',container,'psql','-U','postgres','-d','postgres','-X','-qAt','-v','ON_ERROR_STOP=1','-c',sql])
    require(p.returncode==0,'Owned local SQL probe failed');return p.stdout.strip()
def no_ipv6_route():
    for filename in ('if_inet6','ipv6_route'):
        p=capture(['docker','exec',container,'cat','/proc/net/'+filename]);require(p.returncode==0,'IPv6 kernel metadata required')
        for line in p.stdout.splitlines():
            row=line.split();address=ipaddress.IPv6Address(int(row[0],16))
            if filename=='if_inet6':require(address.is_loopback or address.is_link_local,'Global IPv6 address forbidden')
            elif row[-1]!='lo':require(int(row[1],16)>0 and (address.is_link_local or address.is_multicast),'Global/default IPv6 route forbidden')
def native_proof(subnets):
    c=existing_container();require(c is not None,'Local Postgres container required');sole_network(c)
    firewall(subnets);no_ipv6_route()
    # UDP connect selects the host interface without sending a datagram.
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as route:
        route.connect(('192.0.2.1',9));address=route.getsockname()[0]
    ip=ipaddress.ip_address(address)
    require(not ip.is_loopback and not any(ip in subnet for subnet in subnets),'Controlled host endpoint must be outside owned subnet')
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
        before_tcp=dropped()
        database_port=local_sql('show port;')
        require(re.fullmatch(r'[0-9]+',database_port) and 1<=int(database_port)<=65535,'Actual local Postgres TCP port required')
        script='''command -v timeout >/dev/null || exit 90
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/"$1"' proof "$3" >/dev/null 2>&1 || exit 91
timeout 3 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' proof "$1" "$2" >/dev/null 2>&1
code=$?
case "$code" in 1|124) exit 0;; *) exit 92;; esac'''
        p=capture(['docker','exec',container,'bash','-c',script,'proof',address,str(port),database_port])
        diagnostic={'class':{0:'NATIVE_TCP_CONTROLS_OK',90:'TIMEOUT_TOOL_MISSING',91:'LOCAL_POSTGRES_TCP_POSITIVE_FAILED',92:'EXTERNAL_TCP_NOT_DENIED'}.get(p.returncode,'DOCKER_OR_UNKNOWN_FAILURE'),'drop_packets_delta':dropped()-before_tcp,'controlled_receiver_connections':len(accepted)-1}
        print('LOCAL_TCP_CONTROL_DIAGNOSTIC '+json.dumps(diagnostic),flush=True)
        require(p.returncode==0,'Native TCP control failed: '+diagnostic['class'])
        tcp_delta=dropped()-before_tcp;require(tcp_delta>0,'TCP failure without native DROP is not proof')
        pg_net_state='NOT_INSTALLED_BEFORE_RESET';pg_net_delta=None
        installed=local_sql("select exists(select 1 from pg_extension where extname='pg_net');")=='t'
        if installed:
            local_sql('select net.check_worker_is_up();');before_http=dropped()
            request=local_sql("select net.http_post(url:='http://"+address+':'+str(port)+"/contaos-local-native-probe',body:='{}'::jsonb,headers:='{\"Content-Type\":\"application/json\"}'::jsonb,timeout_milliseconds:=1500);")
            require(re.fullmatch(r'[0-9]+',request),'Exact own probe request required');deadline=time.monotonic()+10;denied=False
            while time.monotonic()<deadline:
                denied=local_sql('select exists(select 1 from net._http_response where id='+request+' and status_code is null and (timed_out or error_msg is not null));')=='t'
                if denied:break
                time.sleep(.1)
            pg_net_delta=dropped()-before_http;require(denied and pg_net_delta>0,'Real pg_net request must fail with native DROP proof');pg_net_state='PASS_REAL_LOCAL_HTTP_DENIED'
        else:require(operation==('db','start'),'Real pg_net probe required after reset')
        time.sleep(.2);require(len(accepted)==1,'Isolated container reached controlled host endpoint')
        positive(2)
        sole_network(metadata(['docker','inspect',container]));firewall(network());no_ipv6_route()
        proof={'state':'PASS_NATIVE_LOCAL_TCP_HTTP_DENY','head':os.environ.get('GITHUB_SHA'),'operation':list(operation),'firewall_verified':True,'sole_network':True,'global_ipv6':False,'dns_certified':False,'host_positive_controls':2,'container_loopback_positive':True,'isolated_receiver_connections':0,'tcp_drop_packets_delta':tcp_delta,'pg_net_probe':pg_net_state,'pg_net_drop_packets_delta':pg_net_delta}
        from pathlib import Path
        output=Path('restore-proof' if job=='restore' else 'restore-proof-synthetic')/'isolated-db-network.jsonl'
        require(output.parent.is_dir(),'Owned local proof directory required')
        with output.open('a') as stream:stream.write(json.dumps(proof)+'\n')
        print('ISOLATED_DATABASE_NATIVE_TCP_HTTP_DENY_PASS host_positive=2 container_loopback_positive=1 isolated_receiver_connections=0 firewall=true pg_net='+pg_net_state)
    finally:stop.set();thread.join(timeout=1);listener.close()

args=sys.argv[1:]
require(args and args[0]=='run','Explicit local operation required');operation=tuple(args[1:])
require(operation in (('db','start'),('db','reset','--local','--no-seed'),('stop','--no-backup'),('migration','list','--local')),'Remote or unsupported operation forbidden')
subnets=network();current=existing_container()
if current is not None:sole_network(current)
firewall(subnets,install=True)
subprocess.run(['supabase','--network-id',name,*operation],check=True)
if operation[0]=='stop':
    require(existing_container() is None,'Local container remained active')
else:native_proof(network())
PY
