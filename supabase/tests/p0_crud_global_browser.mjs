import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync,renameSync,existsSync,unlinkSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {createServer as createTCPServer} from 'node:net';
export const PUBLISHED_ORIGIN='https://scope-and-approval-keeper.lovable.app';
const HML_ORIGIN='https://gklhhhyosgasnyoxlrui.supabase.co';
const browserDebugPorts=new WeakMap();
const FRONTEND_PIN='164b10b44eaf5b553efcc7ab4e053b86c4d3b269';
export function persistBrowserFixture(path,fixture){
  const current=JSON.parse(readFileSync(path,'utf8'));assert.equal(current.nonce,fixture.nonce);
  for(const key of ['permission_control','readiness_control'])if(current[key])fixture[key]=current[key];
  const temporary=path+'.browser.tmp';writeFileSync(temporary,JSON.stringify(fixture,null,2)+'\n',{mode:0o600});renameSync(temporary,path);
}
export function createProofRecorder(local,saveLocal){
  let target=local,save=saveLocal;
  return {
    check(name,pass,http){target.assertions.push(publicRecord({name,pass,http}));save();assert(pass,name);},
    fence(snapshot){target.published_fence=snapshot;finalizePublishedFence(target,snapshot);save();},
    fenceRecorder(){const original=target,persist=save;return snapshot=>{original.published_fence=snapshot;finalizePublishedFence(original,snapshot);persist();};},
    async published(report,saveReport,operation){assert.equal(target,local);target=report;save=saveReport;try{return await operation();}finally{target=local;save=saveLocal;}}
  };
}
export async function runDocumentProvenances({proveBackend,published,local,now=Date.now}){
  const deadline=now()+900000;let timer;
  try{await Promise.race([(async()=>{await proveBackend();assert(now()<deadline);await published(deadline);assert(now()<deadline);await local(deadline);assert(now()<deadline);})(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('DOCUMENT_BATCH_DEADLINE')),900000);})]);}finally{clearTimeout(timer);}
}
async function boundedPublicText(fetcher,url,maximum,expectedOrigin=PUBLISHED_ORIGIN){
  const target=new URL(url);assert.equal(target.origin,expectedOrigin);assert(!target.username&&!target.password&&!target.hash);
  const response=await fetcher(target.href,{redirect:'error',credentials:'omit',signal:AbortSignal.timeout(15000)});
  assert(response.ok&&response.status===200&&new URL(response.url).href===target.href);
  const reader=response.body.getReader(),parts=[];let bytes=0;
  try{while(true){const next=await reader.read();if(next.done)break;bytes+=next.value.byteLength;assert(bytes<=maximum);parts.push(Buffer.from(next.value));}}
  finally{await reader.cancel();}
  return Buffer.concat(parts).toString('utf8');
}
export function publicHTMLScripts(parser,html){
  assert(parser&&typeof parser.parse==='function');const scripts=[];
  const document=parser.parse(html,{scriptingEnabled:true,onParseError:error=>{assert(['missing-doctype','unexpected-null-character'].includes(error.code),'Ambiguous public HTML');}});
  function walk(node){
    if(node.tagName==='base')throw Error('Public base URL is unsupported');
    if(node.tagName==='template')return;
    if(node.tagName==='script'){
      assert.equal(node.namespaceURI,'http://www.w3.org/1999/xhtml');assert(!node.attrs.some(a=>a.name==='nomodule'),'Legacy-only client is unsupported');
      scripts.push({attributes:node.attrs.map(a=>[a.name,a.value]),source:(node.childNodes??[]).map(n=>{assert.equal(n.nodeName,'#text');return n.value;}).join('')});
    }
    for(const child of node.childNodes??[])walk(child);
  }
  walk(document);return scripts;
}
export function validateHTMLParserFixtures(parser){
  for(const html of ['<!-- <script src="/assets/decoy.js"></script> -->','<template><script src="/assets/decoy.js"></script></template>','<textarea><script src="/assets/decoy.js"></script></textarea>'])assert.equal(publicHTMLScripts(parser,html).length,0);
  assert.throws(()=>publicHTMLScripts(parser,'<script nomodule src="/assets/legacy-hml-client.js"></script>'));
  for(const html of ['<script src=https://foreign.invalid/a.js src="/assets/main.js"></script>','<script src="/assets/main.js" SRC=https://foreign.invalid/a.js></script>'])assert.throws(()=>publicHTMLScripts(parser,html));
  assert(publicHTMLScripts(parser,'<script>const payload="\0";</script>')[0].source.includes('\ufffd'));
  const scripts=publicHTMLScripts(parser,'<script defer src="/~flock.js"></script><script>const bootstrap=1;</script><script type=module src="/assets/main.js"></script>');
  assert.equal(scripts.length,3);assert.equal(scripts[1].source,'const bootstrap=1;');assert.equal(new Map(scripts[2].attributes).get('src'),'/assets/main.js');
}
export function publicHTMLVariantSummary(analyzer,expected,actual){
  assert.equal(typeof expected,'string');assert.equal(typeof actual,'string');assert(Buffer.byteLength(expected)<=262144&&Buffer.byteLength(actual)<=262144);
  let prefix=0;while(prefix<expected.length&&prefix<actual.length&&expected[prefix]===actual[prefix])prefix++;let suffix=0;while(suffix<expected.length-prefix&&suffix<actual.length-prefix&&expected[expected.length-1-suffix]===actual[actual.length-1-suffix])suffix++;
  const before=expected.slice(expected.lastIndexOf('<',prefix),prefix),tag=/^<\/?([a-z0-9:-]+)/i.exec(before)?.[1]?.toLowerCase(),attribute=/([a-z0-9:_-]+)\s*=\s*["'][^"']*$/i.exec(before)?.[1]?.toLowerCase();
  const left=analyzer.htmlEntries(expected),right=analyzer.htmlEntries(actual),executable=entries=>entries.filter(script=>!['application/json','application/ld+json'].includes(new Map(script.attributes).get('type'))),hash=value=>createHash('sha256').update(value).digest('hex');
  return {all_html_bytes_equal:expected===actual,expected_bytes:Buffer.byteLength(expected),actual_bytes:Buffer.byteLength(actual),first_difference_character:prefix,common_suffix_characters:suffix,first_difference_tag:['script','meta','link','html','head','body','title','div','input'].includes(tag)?tag:'OTHER',first_difference_attribute:['nonce','content','src','href','value','data-token','data-client-token','data-project-token','integrity','crossorigin','lang','style','class','id','type'].includes(attribute)?attribute:'OTHER',expected_script_count:left.length,actual_script_count:right.length,all_script_entries_equal:JSON.stringify(left)===JSON.stringify(right),executable_entries_equal:JSON.stringify(executable(left))===JSON.stringify(executable(right)),expected_changed_region_sha256:hash(expected.slice(prefix,expected.length-suffix)),actual_changed_region_sha256:hash(actual.slice(prefix,actual.length-suffix))};
}
export async function inspectPublishedBackend(fetcher,analyzer,onPhase=()=>{}){
  try{onPhase('READ_HTML');const html=await boundedPublicText(fetcher,PUBLISHED_ORIGIN+'/login',262144);return await inspectPublishedHTML(fetcher,analyzer,html,onPhase,PUBLISHED_ORIGIN+'/login');}catch{throw Error('PUBLICADA_BACKEND_NAO_COMPROVADO');}
}
export async function inspectPublishedDocument(fetcher,analyzer,body,url,onPhase=()=>{}){
  return inspectDocumentAtOrigin(fetcher,analyzer,body,url,onPhase,PUBLISHED_ORIGIN);
}
async function inspectDocumentAtOrigin(fetcher,analyzer,body,url,onPhase,expectedOrigin){
  const target=new URL(url);assert.equal(target.origin,expectedOrigin);assert(!target.username&&!target.password&&!target.hash);
  assert(Buffer.isBuffer(body)&&body.length<=262144);const html=body.toString('utf8');assert(Buffer.from(html,'utf8').equals(body),'Lossy Document UTF-8');
  return inspectPublishedHTML(fetcher,analyzer,html,onPhase,target.href);
}
async function inspectPublishedHTML(fetcher,analyzer,html,onPhase,documentURL){
  const documentOrigin=new URL(documentURL).origin;
  try{
    onPhase('PARSE_SCRIPT_ENTRIES');
    // Every executable script participates in inert analysis; no auxiliary script is ignored.
    const entries=[],modules=new Map();let total=0;
    const allowedScriptPath=p=>p.startsWith('/assets/')||p==='/~flock.js'||/^\/__l5e\/events\.[a-f0-9]+\.js$/.test(p);
    assert.equal(typeof analyzer.htmlEntries,'function');
    for(const script of analyzer.htmlEntries(html)){
      const values=new Map(script.attributes);assert.equal(values.size,script.attributes.length);
      const type=values.get('type');if(['application/json','application/ld+json'].includes(type))continue;
      assert(type===undefined||['module','text/javascript','application/javascript'].includes(type));
      if(values.has('src')){
        assert(!script.source.trim());const raw=values.get('src');assert(!/[&<>\s]/.test(raw));
        const url=new URL(raw,documentURL);assert.equal(url.origin,documentOrigin);assert(allowedScriptPath(url.pathname)&&!url.username&&!url.password&&!url.search&&!url.hash);entries.push(url.href);
      }else{
        const source=script.source;if(!source.trim())continue;
        assert(Buffer.byteLength(source)<=262144);total+=Buffer.byteLength(source);
        const id=new URL('./__inline_'+createHash('sha256').update(source).digest('hex')+'.js',documentURL).href;assert(!modules.has(id));modules.set(id,source);entries.push(id);
      }
    }
    assert(entries.length>0&&entries.length<=16);const pending=[...new Set(entries.filter(e=>!modules.has(e)))];
    for(const [url,source] of modules)for(const name of analyzer.imports(source)){const child=new URL(name,url);assert.equal(child.origin,documentOrigin);assert(child.pathname.startsWith('/assets/')&&!child.search&&!child.hash);pending.push(child.href);}
    onPhase('READ_SCRIPT_GRAPH');while(pending.length){
      const url=pending.shift();if(modules.has(url))continue;assert(modules.size<128);
      const source=await boundedPublicText(fetcher,url,4194304,documentOrigin);total+=Buffer.byteLength(source);assert(total<=8388608);modules.set(url,source);
      // The parser returns imports, not arbitrary URLs; every dependency is bounded and same origin.
      const imports=analyzer.imports(source);
      for(const name of imports){const child=new URL(name,url);assert.equal(child.origin,documentOrigin);assert(child.pathname.startsWith('/assets/')&&!child.search&&!child.hash);if(!modules.has(child.href))pending.push(child.href);}
    }
    onPhase('PROVE_CONFIGURED_CLIENT');const binding=analyzer.prove(modules,entries);assert.equal(binding.verified,true);assert(/^\d+\.\d+\.\d+$/.test(analyzer.version));if(analyzer.reference_sha256){assert(/^[a-f0-9]{64}$/.test(analyzer.reference_sha256));assert.equal(analyzer.compiler_version,'1.2.1');}
    const result={state:'HML_CONFIG_CONFIRMED',frontend_head:null,source_parity:'NAO_VERIFICADA',module_count:modules.size,asset_sha256:[...modules.values()].map(s=>createHash('sha256').update(s).digest('hex')),parser_version:analyzer.version,sdk_version:'2.118.0',...(analyzer.reference_sha256?{sdk_source_sha256:analyzer.reference_sha256,compiler_version:analyzer.compiler_version}:{} )};
    Object.defineProperty(result,'runtimeProof',{value:{origin:documentOrigin,html_sha256:createHash('sha256').update(html).digest('hex'),inspectDocument:(body,url)=>inspectDocumentAtOrigin(fetcher,analyzer,body,url,onPhase,documentOrigin),diagnoseHTML:async body=>{assert(Buffer.isBuffer(body)&&body.length<=262144);const repeat=await boundedPublicText(fetcher,PUBLISHED_ORIGIN+'/login',262144);return {available:true,initial_vs_browser:publicHTMLVariantSummary(analyzer,html,body.toString('utf8')),initial_vs_repeat:publicHTMLVariantSummary(analyzer,html,repeat)};},modules:new Map([...modules].filter(([url])=>!url.includes('/__inline_')).map(([url,source])=>[url,createHash('sha256').update(source).digest('hex')]))}});return result;
  }catch{throw Error('PUBLICADA_BACKEND_NAO_COMPROVADO');}
}
export function publishedRequestAllowed(raw,navigation=false,ownDownloads=[]){
  let url;try{url=new URL(raw);}catch{return false;}
  if(navigation)return url.origin===PUBLISHED_ORIGIN||(url.origin===HML_ORIGIN&&ownDownloads.some(path=>url.pathname==='/storage/v1/object/sign/contaos-documentos/'+path));
  if(url.hostname.endsWith('.supabase.co')||url.hostname.endsWith('.supabase.in'))return url.origin===HML_ORIGIN;
  return url.origin===PUBLISHED_ORIGIN||['data:','blob:'].includes(url.protocol);
}
// Validate actual browser response bytes while Chromium has paused their delivery.
export function validatePublishedResponse(proof,{url,resourceType,status,body}){
  const require=(condition,code)=>{if(!condition)throw Object.assign(Error('Published response rejected'),{code});};
  require(Number.isInteger(status)&&!(status>=300&&status<400),'FENCE_RESPONSE_STATUS');
  if(resourceType==='Script'){
    require(proof?.modules instanceof Map&&proof.modules.has(url),'FENCE_SCRIPT_UNINSPECTED');require(Buffer.isBuffer(body)&&body.length<=4194304,'FENCE_SCRIPT_BODY_LIMIT');
    const actual=createHash('sha256').update(body).digest('hex'),expected=proof.modules.get(url);if(actual!==expected)throw Object.assign(Error('Published executable bytes changed'),{code:'FENCE_SCRIPT_HASH',proof_hashes:{expected,actual}});
  }else if(resourceType==='Document'&&new URL(url).origin===proof?.origin){
    require(Buffer.isBuffer(body)&&body.length<=262144,'FENCE_DOCUMENT_BODY_LIMIT');const actual=createHash('sha256').update(body).digest('hex'),expected=proof.html_sha256;if(actual!==expected)throw Object.assign(Error('Published HTML bytes changed'),{code:'FENCE_DOCUMENT_HASH',proof_hashes:{expected,actual}});
  }
  return true;
}
// Browser-scoped auto-attach requires flattened CDP sessions. Use the native Node
// WebSocket transport because Playwright's CDPSession.send omits envelope sessionId.
async function connectNativeBrowserCDP(browser,identity){
  const port=browserDebugPorts.get(browser);assert(Number.isInteger(port)&&port>0&&port<=65535);
  const response=await fetch('http://127.0.0.1:'+port+'/json/version',{redirect:'error',signal:AbortSignal.timeout(10000)});assert(response.ok);const reader=response.body.getReader(),parts=[];let size=0;try{while(true){const next=await reader.read();if(next.done)break;size+=next.value.byteLength;assert(size<=16384);parts.push(Buffer.from(next.value));}}finally{await reader.cancel();}const metadata=Buffer.concat(parts).toString('utf8');
  const endpoint=new URL(JSON.parse(metadata).webSocketDebuggerUrl);assert(endpoint.protocol==='ws:'&&endpoint.hostname==='127.0.0.1'&&Number(endpoint.port)===port&&!endpoint.username&&!endpoint.password&&!endpoint.search&&!endpoint.hash&&/^\/devtools\/browser\/[a-f0-9-]+$/i.test(endpoint.pathname));
  const socket=new WebSocket(endpoint.href);
  let serial=0,listener=()=>{},onClose=()=>{};const commands=new Map();
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',()=>reject(Object.assign(Error('Local Chromium interception unavailable'),{code:'CDP_SOCKET_CONNECT'})),{once:true});});
  socket.addEventListener('message',event=>{const data=JSON.parse(event.data);if(data.id){const pending=commands.get(data.id);if(!pending)return;commands.delete(data.id);clearTimeout(pending.timer);if(data.error)pending.reject(Object.assign(Error('Chromium interception command rejected'),{code:'CDP_'+pending.method.replace(/[^a-zA-Z0-9]/g,'_').toUpperCase(),protocol_code:Number.isInteger(data.error.code)?data.error.code:null,protocol_reason:/not supported|not found|wasn't found|unknown method/i.test(data.error.message??'')?'UNSUPPORTED':(/closed|detached|no session/i.test(data.error.message??'')?'TARGET_CLOSED':'OTHER_CDP_ERROR')}));else pending.resolve(data.result??{});}else listener(data);});
  socket.addEventListener('close',()=>{onClose();for(const pending of commands.values()){clearTimeout(pending.timer);pending.reject(Error('Chromium interception connection closed'));}commands.clear();});
  const transport={send(method,params={},sessionId){const id=++serial;return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{commands.delete(id);reject(Error('Chromium interception command timeout'));},10000);commands.set(id,{resolve,reject,timer,method});socket.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});},onEvent(callback){listener=callback;},onClose(callback){onClose=callback;},close(){socket.close();}};
  try{const target=await transport.send('Target.getTargetInfo',{targetId:identity.targetId});assert.equal(target.targetInfo.browserContextId,identity.browserContextId);}catch(error){transport.close();throw error;}return transport;
}
export async function boundedSignedDownload(fetcher,raw,ownPath,expectedSize){
  const url=new URL(raw);assert.equal(url.origin,HML_ORIGIN);assert(!url.username&&!url.password&&!url.hash);assert.equal(url.pathname,'/storage/v1/object/sign/contaos-documentos/'+ownPath);assert(typeof ownPath==='string'&&ownPath.length>0&&!ownPath.includes('..'));assert(Number.isSafeInteger(expectedSize)&&expectedSize>0&&expectedSize<=4194304);
  const response=await fetcher(url.href,{redirect:'error',credentials:'omit',signal:AbortSignal.timeout(15000)});assert.equal(response.status,200);
  const reader=response.body.getReader(),parts=[];let size=0;
  try{while(true){const next=await reader.read();if(next.done)break;size+=next.value.byteLength;assert(size<=expectedSize,'Signed download exceeds expected size');parts.push(Buffer.from(next.value));}}finally{await reader.cancel();}
  assert.equal(size,expectedSize);return Buffer.concat(parts);
}
export function webSocketDenyRules(){return {matchedNetworkConditions:['ws://*:*/*','wss://*:*/*'].map(urlPattern=>({urlPattern,offline:true,latency:0,downloadThroughput:-1,uploadThroughput:-1}))};}
export function nativePageBarrier(targetInfos,sessions,ownContext,initialTarget){
  const pages=new Set(targetInfos.filter(target=>target.browserContextId===ownContext&&['page','iframe'].includes(target.type)).map(target=>target.targetId));
  for(const session of sessions)if(session.contextId===ownContext&&['page','iframe'].includes(session.type))pages.add(session.targetId);
  assert(pages.has(initialTarget),'Initial native target identity disappeared');return pages;
}
export function unexpectedWorkerDeny(target,ownContext){
  if(!['worker','shared_worker'].includes(target.type)||(target.contextId&&target.contextId!==ownContext))return null;
  const paused=target.waitingForDebugger===true;return {code:!target.contextId?'FENCE_WORKER_CONTEXT_UNKNOWN':(paused?'FENCE_UNEXPECTED_WORKER_PAUSED':'FENCE_UNEXPECTED_WORKER_RUNNING'),paused};
}
export function validateNativeProxyWorkerProof(kind,results,proof){
  assert(['HTTP','BLOB','DATA'].includes(kind));const opaque=kind==='DATA';assert.deepEqual(results,[{status:opaque?null:200,rejected:opaque},true,true,opaque?'OPAQUE':'OWN']);
  assert.equal(proof.own_start_requests,1);assert.equal(proof.own_bootstrap_requests,kind==='HTTP'?1:0);for(const key of ['foreign_tcp_connections','foreign_http_requests','websocket_upgrades'])assert.equal(proof[key],0);assert(Number.isInteger(proof.deny_connections)&&proof.deny_connections>0);return true;
}
export function finalizePublishedFence(report,snapshot){if(!snapshot?.failed)return false;report.state='FAIL';report.failure_code='FENCE_LATE_PUBLISHED_FAILURE';return true;}
export function finalizeUnexpectedBrowserWorker(report){if(!report.unexpected_browser_worker)return false;report.state='FAIL';report.failure_code='FENCE_UNEXPECTED_BROWSER_WORKER';return true;}
// Native context proxy policy: approved origins stay DIRECT; all others reach
// a loopback TCP deny endpoint that never reads, replies, or forwards data.
export function nativeDestinationProxy(origins,port){
  assert(Number.isInteger(port)&&port>0&&port<=65535);assert(Array.isArray(origins)&&origins.length>0&&origins.length<=2);assert.equal(new Set(origins).size,origins.length);
  const rules=origins.map(raw=>{assert.equal(typeof raw,'string');const url=new URL(raw);assert(['http:','https:'].includes(url.protocol));assert.equal(url.origin,raw);assert(!url.username&&!url.password&&!url.search&&!url.hash&&url.pathname==='/');assert(!url.hostname.endsWith('.'));assert(/^(?:[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?|\[[a-f0-9:]+\])$/.test(url.hostname));assert(!url.hostname.startsWith('.'));return url.protocol+'//'+url.hostname+':'+(url.port||(url.protocol==='https:'?'443':'80'));});
  return {server:'http://127.0.0.1:'+port,bypass:'<-loopback>,'+rules.join(',')};
}
export async function startNativeDestinationDeny(){
  let connections=0,closed=false,closing;const server=createTCPServer(socket=>{connections=Math.min(100000,connections+1);socket.on('error',()=>{});socket.destroy();});
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});const port=server.address().port;server.once('close',()=>{closed=true;});
  return {port,snapshot:()=>({connections,closed}),close:()=>closing??=(new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Native deny close did not drain')),1000);server.close(error=>{clearTimeout(timer);if(error)reject(error);else resolve();});}))};
}
// Native Chromium interception preserves browser CORS, cookies and Origin semantics.
// No request body/header is read, and no response is replaced or fulfilled by the harness.
export async function installPublishedCDPFence(browser,context,page,proof,allowed,expectedPopup=()=>false){
  assert(proof?.modules instanceof Map&&proof.modules.size>0);assert.equal(typeof allowed,'function');
  const initial=await context.newCDPSession(page),info=await initial.send('Target.getTargetInfo');await initial.detach();
  const ownContext=info.targetInfo.browserContextId,initialTarget=info.targetInfo.targetId;assert(ownContext);
  const root=await connectNativeBrowserCDP(browser,{targetId:initialTarget,browserContextId:ownContext}),sessions=new Map(),configured=new Map();let failed=false,closed=false,failureCode=null,failureProtocol=null,failureRequest=null,failureHashes=null,failureHTML=null,verifiedScripts=0,verifiedDocuments=0,redirectBlocks=0,workerTargets=0,workerReady=0,workerWaiting=0,workerRuntimeResumes=0;
  const active=new Set();let documentInspection=false;const documentProofs=[],loadedScriptHashes=new Set();
  const fail=error=>{failed=true;if(!failureHashes&&/^[a-f0-9]{64}$/.test(error?.proof_hashes?.expected??'')&&/^[a-f0-9]{64}$/.test(error?.proof_hashes?.actual??''))failureHashes={expected:error.proof_hashes.expected,actual:error.proof_hashes.actual};if(!failureProtocol&&Number.isInteger(error?.protocol_code))failureProtocol={code:error.protocol_code,reason:error.protocol_reason};if(!failureCode)failureCode=typeof error?.code==='string'&&/^(?:CDP|FENCE)_[A-Z0-9_]{1,80}$/.test(error.code)?error.code:'FENCE_ASYNC_FAILURE';void context.close().catch(()=>{});};
  root.onClose(()=>{if(!closed)fail({code:'FENCE_CDP_DISCONNECTED'});});
  // No Playwright routing: its frozen implementation fabricates preflight 204.
  // One native CDP agent validates Request and Response without modifying bytes.
  function track(p){active.add(p);p.catch(fail).finally(()=>active.delete(p));}
  const send=(session,method,params={})=>{if(method==='Runtime.runIfWaitingForDebugger'&&session.contextId===ownContext&&['worker','shared_worker'].includes(session.type))workerRuntimeResumes++;return root.send(method,params,session.id);};
  async function paused(session,event){
    const requestId=event.requestId,url=event.request.url,resourceType=event.resourceType;
    if(session.type==='page'&&session.targetId!==initialTarget){await send(session,'Fetch.failRequest',{requestId,errorReason:'BlockedByClient'});if(!expectedPopup(url))throw Object.assign(Error('Unexpected page target'),{code:'FENCE_UNEXPECTED_POPUP'});return;}
    if(failed||!allowed(url,resourceType==='Document')){await send(session,'Fetch.failRequest',{requestId,errorReason:'BlockedByClient'});throw Object.assign(Error('Published request blocked before transmission'),{code:'FENCE_UNAPPROVED_REQUEST'});}
    const response=event.responseStatusCode!==undefined||event.responseErrorReason!==undefined;
    if(!response){await send(session,'Fetch.continueRequest',{requestId});return;}
    let body;try{
      if(event.responseErrorReason)throw Object.assign(Error('Published response transport failed'),{code:'FENCE_RESPONSE_TRANSPORT'});if(event.responseStatusCode>=300&&event.responseStatusCode<400){redirectBlocks++;throw Object.assign(Error('Published redirects are blocked before following'),{code:'FENCE_RESPONSE_REDIRECT'});}
      if(resourceType==='Script'||(resourceType==='Document'&&new URL(url).origin===proof.origin)){
        const result=await send(session,'Fetch.getResponseBody',{requestId});body=Buffer.from(result.body,result.base64Encoded?'base64':'utf8');
      }
      if(resourceType==='Document'&&new URL(url).origin===proof.origin&&typeof proof.inspectDocument==='function'){
        assert.equal(event.responseStatusCode,200);if(documentInspection)throw Object.assign(Error('Overlapping Document inspection'),{code:'FENCE_DOCUMENT_OVERLAP'});
        documentInspection=(async()=>{const inspected=await proof.inspectDocument(body,url);assert.equal(inspected.state,'HML_CONFIG_CONFIRMED');proof=inspected.runtimeProof;assert(proof?.modules instanceof Map);assert(documentProofs.length<128);documentProofs.push({html_sha256:proof.html_sha256,asset_sha256:inspected.asset_sha256,module_count:inspected.module_count,sdk_version:inspected.sdk_version,sdk_source_sha256:inspected.sdk_source_sha256,compiler_version:inspected.compiler_version,parser_version:inspected.parser_version});})();
        try{await documentInspection;}finally{documentInspection=false;}
      }
      // Keep speculative/concurrent scripts paused until the exact Document graph is proved.
      // Rejection propagates to both responses; no bytes are delivered on failure.
      if(resourceType==='Script'&&documentInspection)await documentInspection;
      if(failed||closed)throw Object.assign(Error('Fence failed while response was paused'),{code:'FENCE_RESPONSE_LATCH'});
      validatePublishedResponse(proof,{url,resourceType,status:event.responseStatusCode,body});
      if(resourceType==='Script'){verifiedScripts++;loadedScriptHashes.add(createHash('sha256').update(body).digest('hex'));}if(resourceType==='Document'&&new URL(url).origin===proof.origin)verifiedDocuments++;
      assert(!failed&&!closed,'Fence failed while response was paused');await send(session,'Fetch.continueResponse',{requestId});
    }catch(error){if(error.code==='FENCE_DOCUMENT_HASH'&&typeof proof.diagnoseHTML==='function'){try{failureHTML=await proof.diagnoseHTML(body);}catch{failureHTML={available:false};}}if(!/^(?:CDP|FENCE)_[A-Z0-9_]{1,80}$/.test(error.code??''))error.code=resourceType==='Document'?'FENCE_DOCUMENT_RESPONSE_REJECTED':resourceType==='Script'?'FENCE_SCRIPT_RESPONSE_REJECTED':'FENCE_OTHER_RESPONSE_REJECTED';fail(error);await send(session,'Fetch.failRequest',{requestId,errorReason:'BlockedByClient'}).catch(()=>{});throw error;}
  }
  function message(session,data){
    if(data.method==='Page.windowOpen'){if(!expectedPopup(data.params.url))fail({code:'FENCE_UNEXPECTED_POPUP'});}
    else if(data.method==='Audits.issueAdded'&&data.params.issue?.code==='ContentSecurityPolicyIssue'){const detail=data.params.issue.details?.contentSecurityPolicyIssueDetails;if(detail?.violatedDirective?.split(/\s/)[0]==='worker-src'&&detail.isReportOnly===false)fail({code:'FENCE_BROWSER_WORKER_CSP_VIOLATION'});}
    else if(data.method==='Fetch.requestPaused')track(paused(session,data.params).catch(error=>{if(!failureRequest){const event=data.params,origin=new URL(event.request.url).origin;failureRequest={resource_type:['Document','Script','Stylesheet','Image','Font','Media','XHR','Fetch','Manifest','Other'].includes(event.resourceType)?event.resourceType:'Other',origin_class:origin===proof.origin?'OWN':origin===HML_ORIGIN?'HML':'UNAPPROVED',response_status:Number.isInteger(event.responseStatusCode)?event.responseStatusCode:null};}throw error;}));
    else if(data.method==='Target.attachedToTarget')attach(session,data.params);
  }
  const targetFilter=[{type:'page'},{type:'iframe'},{type:'worker'},{type:'shared_worker'},{exclude:true}];
  function attach(parent,event){
    const session={id:event.sessionId,targetId:event.targetInfo.targetId,type:event.targetInfo.type,parent,contextId:event.targetInfo.browserContextId??parent?.contextId};sessions.set(session.id,session);
    const workerDeny=unexpectedWorkerDeny({...session,waitingForDebugger:event.waitingForDebugger},ownContext);if(workerDeny){workerTargets++;if(workerDeny.paused)workerWaiting++;fail({code:workerDeny.code});return;}
    const ready=(async()=>{
      assert(session.contextId,'Unresolved attached target context');
      if(session.contextId!==ownContext){await send(session,'Runtime.runIfWaitingForDebugger');return;}
      if(event.targetInfo.type==='page')await send(session,'Page.enable');await send(session,'Audits.enable');
      await send(session,'Network.enable');await send(session,'Network.setBlockedURLs',{urls:['ws://*','wss://*']});
      // Native network-service offline rules stop only WS/WSS handshakes;
      // HTTP(S), navigator state and the real browser CORS path remain intact.
      const denied=await send(session,'Network.emulateNetworkConditionsByRule',webSocketDenyRules());assert.equal(denied.ruleIds?.length,2);
      await send(session,'Fetch.enable',{patterns:[{urlPattern:'*',requestStage:'Request'},{urlPattern:'*',requestStage:'Response'}]});
      await send(session,'Target.setAutoAttach',{autoAttach:true,waitForDebuggerOnStart:true,flatten:true,filter:targetFilter});
      await send(session,'Runtime.runIfWaitingForDebugger');if(['worker','shared_worker'].includes(event.targetInfo.type))workerReady++;
    })();configured.set(event.targetInfo.targetId,ready);track(ready);
  }
  root.onEvent(event=>{
    const session=event.sessionId?sessions.get(event.sessionId):null;
    if(event.method==='Target.attachedToTarget')attach(session,event.params);
    else if(event.method==='Target.detachedFromTarget'){const detached=sessions.get(event.params.sessionId);sessions.delete(event.params.sessionId);if(detached&&!([...sessions.values()].some(other=>other.targetId===detached.targetId)))configured.delete(detached.targetId);}
    else if(session)message(session,event);
  });
  await root.send('Target.setAutoAttach',{autoAttach:true,waitForDebuggerOnStart:true,flatten:true,filter:targetFilter});
  for(let i=0;!configured.has(initialTarget)&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));
  assert(configured.has(initialTarget),'Initial published target was not intercepted');await configured.get(initialTarget);assert(!failed);
  context.on('close',()=>{closed=true;root.close();});
  return {assertSafe:()=>{assert(!failed&&!closed,'Published preventive fence');assert(verifiedScripts>0&&verifiedDocuments>0,'Actual published source bytes not verified');},snapshot:()=>({document_proofs:documentProofs,loaded_script_sha256:[...loadedScriptHashes],verified_scripts:verifiedScripts,verified_documents:verifiedDocuments,redirect_blocks:redirectBlocks,worker_targets:workerTargets,worker_ready:workerReady,worker_waiting:workerWaiting,worker_runtime_resumes:workerRuntimeResumes,protocol_failure:failureProtocol,failure_code:failureCode,failure_request:failureRequest,failure_hashes:failureHashes,html_variant:failureHTML,failed})};
}
// Credential-free real Chromium fixtures run in the canonical public-probe job.
export async function verifyPublishedCDPFence(browser,onPhase=()=>{},onEvidence=()=>{},deny){
  assert(deny&&!deny.snapshot().closed);
  const counters={foreign:0,post:0,preflight:0,post_allowed:0,preflight_allowed:0,executed:0,upgrades:0,worker_scripts:0,worker_starts:0,redirect307:0,redirect308:0,foreign_tcp:0,own_tcp:0};let mode='normal',concurrentReads=0,concurrentEffects=0;let own,other;
  const script='globalThis.nativeFenceFixture=true;';
  const html='<!doctype html><html><head><script src="/main.js"></script></head><body>Own synthetic fence fixture</body></html>';
  const foreign=createServer((request,response)=>{counters.foreign++;const allowed=request.url==='/allow-effect';if(request.method==='OPTIONS')counters[allowed?'preflight_allowed':'preflight']++;if(request.method==='POST')counters[allowed?'post_allowed':'post']++;response.writeHead(request.method==='OPTIONS'?204:200,{'Content-Type':'text/plain',...(allowed?{'Access-Control-Allow-Origin':own,'Access-Control-Allow-Methods':'POST','Access-Control-Allow-Headers':'content-type'}:{})});response.end('own synthetic foreign fixture');});
  foreign.on('connection',()=>{counters.foreign_tcp++;});
  const ipv6=createServer((request,response)=>{counters.foreign++;response.writeHead(200);response.end('Own synthetic IPv6 negative');});ipv6.on('connection',()=>{counters.foreign_tcp++;});ipv6.on('upgrade',(request,socket)=>{counters.upgrades++;socket.destroy();});
  foreign.on('upgrade',(request,socket)=>{counters.upgrades++;socket.destroy();});
  const local=createServer((request,response)=>{
    if(request.url==='/redirect307'||request.url==='/redirect308'){counters['redirect'+request.url.slice(-3)]++;response.writeHead(Number(request.url.slice(-3)),{Location:other+'/effect'});response.end();return;}
    if(request.url==='/worker-proxy.js'){counters.worker_scripts++;response.writeHead(200,{'Content-Type':'text/javascript'});response.end(proxyWorkerSource());return;}
    if(request.url==='/worker-start'){counters.worker_starts++;response.writeHead(200);response.end();return;}
    if(request.url==='/worker.js'||request.url==='/worker-ws.js'){counters.worker_scripts++;response.writeHead(200,{'Content-Type':'text/javascript'});response.end(request.url==='/worker.js'?'fetch('+JSON.stringify(own+'/worker-start')+');fetch('+JSON.stringify(other+'/effect')+');new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');':'const socket=new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');socket.onerror=()=>postMessage("NATIVE_WS_ERROR");socket.onopen=()=>postMessage("UNEXPECTED_OPEN");');return;}
    if(request.url==='/concurrent-executed'){concurrentEffects++;response.writeHead(200);response.end();return;}
    if(request.url==='/concurrent.js'){concurrentReads++;response.writeHead(200,{'Content-Type':'text/javascript'});response.end(mode==='changed'?'fetch("/executed")':'globalThis.concurrentRuns=(globalThis.concurrentRuns||0)+1;fetch("/concurrent-executed");');return;}
    if(request.url==='/main.js'){response.writeHead(200,{'Content-Type':'text/javascript'});response.end(mode==='changed'?'fetch("/executed")':script);return;}
    if(request.url==='/executed'){counters.executed++;response.writeHead(200);response.end();return;}
    response.writeHead(200,{'Content-Type':'text/html'});response.end(html);
  });
  local.on('connection',()=>{counters.own_tcp++;});local.on('upgrade',(request,socket)=>{counters.upgrades++;socket.destroy();});
  const sockets=new Set();for(const server of [local,foreign,ipv6])server.on('connection',socket=>{sockets.add(socket);socket.once('close',()=>sockets.delete(socket));});
  async function drainAfterContextClose(){for(let i=0;sockets.size&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));assert.equal(sockets.size,0,'Fixture TCP connections did not drain after context close');await new Promise(resolve=>setImmediate(resolve));await new Promise(resolve=>setTimeout(resolve,100));await new Promise(resolve=>setImmediate(resolve));assert.equal(sockets.size,0,'Late fixture TCP connection');}
    function proxyWorkerSource(){return 'Promise.all([fetch('+JSON.stringify(own+'/worker-start')+').then(r=>({status:r.status,rejected:false}),()=>({status:null,rejected:true})),fetch('+JSON.stringify(other+'/effect')+').then(()=>false,()=>true),new Promise(resolve=>{const ws=new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');ws.onopen=()=>{ws.close();resolve(false);};ws.onerror=()=>resolve(true);setTimeout(()=>resolve(false),1500);})]).then(results=>postMessage([...results,self.origin==="null"?"OPAQUE":self.origin==='+JSON.stringify(own)+'?"OWN":"UNEXPECTED"]));';}
  const listen=server=>new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',()=>resolve('http://127.0.0.1:'+server.address().port));});
  const close=server=>new Promise(resolve=>server.close(()=>resolve()));
  try{
    own=await listen(local);other=await listen(foreign);const ipv6Origin=await new Promise((resolve,reject)=>{ipv6.once('error',reject);ipv6.listen(0,'::1',()=>resolve('http://[::1]:'+ipv6.address().port));});

    const proof={origin:own,html_sha256:createHash('sha256').update(html).digest('hex'),modules:new Map([[own+'/main.js',createHash('sha256').update(script).digest('hex')],[own+'/worker.js',createHash('sha256').update('fetch('+JSON.stringify(own+'/worker-start')+');fetch('+JSON.stringify(other+'/effect')+');new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');').digest('hex')],[own+'/worker-ws.js',createHash('sha256').update('const socket=new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');socket.onerror=()=>postMessage("NATIVE_WS_ERROR");socket.onopen=()=>postMessage("UNEXPECTED_OPEN");').digest('hex')]])};
    onPhase('NATIVE_PROXY_EXACT_ORIGINS');
    {
      const context=await browser.newContext({serviceWorkers:'block',proxy:nativeDestinationProxy([own],deny.port)}),page=await context.newPage(),beforeProxy=deny.snapshot().connections;
      try{const response=await page.goto(own+'/login');assert.equal(response.status(),200);assert.equal(await response.text(),html);await page.waitForFunction(()=>globalThis.nativeFenceFixture===true);await page.waitForLoadState('networkidle');assert.equal(deny.snapshot().connections,beforeProxy,'Approved origin did not stay DIRECT');
        const ownURL=new URL(own),foreignURL=new URL(other),negatives=[other+'/effect',other.replace('http:','https:')+'/effect',own.replace('http:','https:')+'/effect','http://localhost:'+foreignURL.port+'/effect','http://localhost.:'+foreignURL.port+'/effect','http://127.0.0.1.evil.invalid:'+ownURL.port+'/effect','http://sub.localhost:'+foreignURL.port+'/effect',ipv6Origin+'/effect',ipv6Origin.replace('http:','https:')+'/effect'];
        const beforeOwnTCP=counters.own_tcp;
        for(const [index,url] of negatives.entries()){const before=deny.snapshot().connections;const rejected=await page.evaluate(async url=>{try{await fetch(url,{signal:AbortSignal.timeout(3000)});return false;}catch{return true;}},url);assert(rejected,'Unapproved fetch returned a response');assert(deny.snapshot().connections>before,'Negative did not exercise native DENY proxy');onEvidence({phase:'NATIVE_PROXY_NEGATIVE_'+index,browser_rejected:true,deny_connections:deny.snapshot().connections-before});}
        for(const host of [foreignURL.host,new URL(ipv6Origin).host,ownURL.host])for(const scheme of ['ws:','wss:']){const before=deny.snapshot().connections;const blocked=await page.evaluate(url=>new Promise(resolve=>{const ws=new WebSocket(url);ws.onopen=()=>{ws.close();resolve(false);};ws.onerror=()=>resolve(true);setTimeout(()=>resolve(false),1500);}),scheme+'//'+host+'/socket');assert(blocked);assert(deny.snapshot().connections>before);}
        await context.close();await drainAfterContextClose();assert.equal(counters.own_tcp,beforeOwnTCP,'Scheme mismatch reached approved server TCP');assert.equal(counters.foreign_tcp,0);assert.equal(counters.foreign,0);assert.equal(counters.upgrades,0);onEvidence({phase:'FINAL_NATIVE_PROXY_EXACT_ORIGINS',after_context_close_and_tcp_drain:true,foreign_tcp_connections:counters.foreign_tcp,foreign_http_requests:counters.foreign,websocket_upgrades:counters.upgrades});
      }finally{await context.close();await drainAfterContextClose();}
    }
    for(const kind of ['HTTP','BLOB','DATA']){onPhase('NATIVE_PROXY_WORKER_'+kind);const context=await browser.newContext({serviceWorkers:'block',proxy:nativeDestinationProxy([own],deny.port)}),page=await context.newPage(),beforeStart=counters.worker_starts,beforeBootstrap=counters.worker_scripts,beforeProxy=deny.snapshot().connections;
      try{await page.goto(own+'/login');const results=await page.evaluate(({kind,source})=>new Promise((resolve,reject)=>{const url=kind==='HTTP'?'/worker-proxy.js':(kind==='BLOB'?URL.createObjectURL(new Blob([source],{type:'text/javascript'})):'data:text/javascript;charset=utf-8,'+encodeURIComponent(source));const worker=new Worker(url);worker.onmessage=event=>{worker.terminate();resolve(event.data);};worker.onerror=()=>reject(Error('Own worker fixture failed'));setTimeout(()=>reject(Error('Own worker proxy fixture timeout')),5000);}),{kind,source:proxyWorkerSource()});await context.close();await drainAfterContextClose();onEvidence({phase:'FINAL_NATIVE_PROXY_WORKER_'+kind,after_context_close_and_tcp_drain:true,own_worker_started:counters.worker_starts-beforeStart===1,own_fetch_status:Number.isInteger(results?.[0]?.status)?results[0].status:null,own_fetch_rejected:results?.[0]?.rejected===true,origin_class:['OWN','OPAQUE'].includes(results?.[3])?results[3]:'UNEXPECTED',worker_start_requests:counters.worker_starts-beforeStart,own_bootstrap_requests:counters.worker_scripts-beforeBootstrap,foreign_tcp_connections:counters.foreign_tcp,foreign_http_requests:counters.foreign,websocket_upgrades:counters.upgrades,deny_connections:deny.snapshot().connections-beforeProxy,browser_worker_functionally_certified:false});assert.equal(counters.worker_starts-beforeStart,1);assert.equal(counters.worker_scripts-beforeBootstrap,kind==='HTTP'?1:0);assert(deny.snapshot().connections>beforeProxy);assert.equal(counters.foreign_tcp,0);assert.equal(counters.foreign,0);assert.equal(counters.upgrades,0);validateNativeProxyWorkerProof(kind,results,{own_start_requests:counters.worker_starts-beforeStart,own_bootstrap_requests:counters.worker_scripts-beforeBootstrap,foreign_tcp_connections:counters.foreign_tcp,foreign_http_requests:counters.foreign,websocket_upgrades:counters.upgrades,deny_connections:deny.snapshot().connections-beforeProxy});}finally{await context.close();await drainAfterContextClose();}
    }
    onPhase('NATIVE_PROXY_UNAVAILABLE');{
      const dead=await startNativeDestinationDeny();await dead.close();const context=await browser.newContext({serviceWorkers:'block',proxy:nativeDestinationProxy([own],dead.port)}),page=await context.newPage();try{await page.goto(own+'/login');const rejected=await page.evaluate(async url=>{try{await fetch(url,{signal:AbortSignal.timeout(3000)});return false;}catch{return true;}},other+'/effect');assert(rejected);await context.close();await drainAfterContextClose();assert.equal(counters.foreign_tcp,0);assert.equal(counters.foreign,0);onEvidence({phase:'FINAL_NATIVE_PROXY_UNAVAILABLE',after_context_close_and_tcp_drain:true,browser_rejected:true,foreign_tcp_connections:counters.foreign_tcp,foreign_http_requests:counters.foreign,no_direct_fallback:true});}finally{await context.close();await drainAfterContextClose();}
    }
    async function fixture(action,{permitForeign=false,changed=false,expectedPopup=false,cors=null,ownWorkerAttempt=false,proofOverride=proof,concurrentExpected=null}={}){
      const beforeCounters={...counters},beforeConcurrentEffects=concurrentEffects;mode=changed?'changed':'normal';const context=await browser.newContext({serviceWorkers:'block',proxy:nativeDestinationProxy(permitForeign?[own,other]:[own],deny.port)});const page=await context.newPage();
      let fence;try{fence=await installPublishedCDPFence(browser,context,page,proofOverride,url=>{const origin=new URL(url).origin;return origin===own||(permitForeign&&origin===other);},()=>expectedPopup);await action({context,page,fence});}
      catch(error){const code=fence?.snapshot().failure_code;if(code)error.code=code;const protocol=fence?.snapshot().protocol_failure;if(protocol)error.protocol_failure=protocol;throw error;}
      finally{await context.close();await drainAfterContextClose();if(concurrentExpected!==null){assert.equal(concurrentEffects-beforeConcurrentEffects,concurrentExpected,'Concurrent script execution after proof/close');onEvidence({phase:'FINAL_CONCURRENT_SCRIPT_EFFECTS',observed_script_effects:concurrentEffects-beforeConcurrentEffects,after_context_close_and_tcp_drain:true});}onEvidence({phase:'FINAL_AFTER_CLOSE_TCP_DRAIN',observation_ms:100,tcp_connections:sockets.size,foreign_tcp_connections:counters.foreign_tcp-beforeCounters.foreign_tcp,foreign_http_requests:counters.foreign-beforeCounters.foreign,worker_start_requests:counters.worker_starts-beforeCounters.worker_starts,bootstrap_requests:counters.worker_scripts-beforeCounters.worker_scripts,websocket_upgrades:counters.upgrades-beforeCounters.upgrades,unexpected_script_execution:counters.executed-beforeCounters.executed});if(!ownWorkerAttempt){assert.equal(counters.worker_starts,beforeCounters.worker_starts,'Late unexpected worker START');assert.equal(counters.worker_scripts,beforeCounters.worker_scripts,'Unexpected worker bootstrap');}assert.equal(counters.upgrades,beforeCounters.upgrades,'Late WebSocket handshake');assert.equal(counters.executed,beforeCounters.executed,'Late changed script execution');if(!permitForeign){assert.equal(counters.foreign,beforeCounters.foreign,'Late foreign HTTP effect');assert.equal(counters.foreign_tcp,beforeCounters.foreign_tcp,'Late foreign TCP connection');}if(cors){const allowed=cors==='allowed',preflight=counters[allowed?'preflight_allowed':'preflight']-beforeCounters[allowed?'preflight_allowed':'preflight'],posts=counters[allowed?'post_allowed':'post']-beforeCounters[allowed?'post_allowed':'post'];onEvidence({phase:allowed?'FINAL_NATIVE_CORS_ALLOWED':'FINAL_NATIVE_CORS_DENIED',after_context_close_and_tcp_drain:true,preflight_requests:preflight,post_effects:posts});assert(preflight>0,'Final native preflight missing');assert.equal(posts,allowed?1:0,'Late CORS POST effect');}}
    }
    for(const outcome of ['VALID','CHANGED','PROOF_REJECTED']){
      onPhase('CONCURRENT_DOCUMENT_SCRIPT_'+outcome);const beforeEffects=concurrentEffects;
      let release,started,inspections=0;const waiting=new Promise(resolve=>started=resolve),pending=new Promise(resolve=>release=resolve);
      const scriptHash=createHash('sha256').update('globalThis.concurrentRuns=(globalThis.concurrentRuns||0)+1;fetch("/concurrent-executed");').digest('hex');
      const graph={...proof,modules:new Map([...proof.modules,[own+'/concurrent.js',scriptHash]])};
      const documentProof={...graph,inspectDocument:async()=>{
        inspections++;if(inspections===2){started();await pending;if(outcome==='PROOF_REJECTED')throw Object.assign(Error('Own rejected proof fixture'),{code:'FENCE_DOCUMENT_RESPONSE_REJECTED'});}
        return {state:'HML_CONFIG_CONFIRMED',module_count:graph.modules.size,asset_sha256:[...graph.modules.values()],runtimeProof:documentProof};
      }};
      await fixture(async({page,fence})=>{
        await page.goto(own+'/login');fence.assertSafe();
        await page.evaluate(url=>{const frame=document.createElement('iframe');frame.src=url;document.body.append(frame);},own+'/second');
        await Promise.race([waiting,new Promise((_,reject)=>setTimeout(()=>reject(Error('Own Document fixture did not start')),3000))]);
        const before=concurrentReads;mode=outcome==='CHANGED'?'changed':'normal';
        await page.evaluate(()=>{const script=document.createElement('script');script.src='/concurrent.js';document.head.append(script);});
        for(let i=0;concurrentReads===before&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));
        assert.equal(concurrentReads,before+1);await new Promise(resolve=>setTimeout(resolve,100));
        assert.equal(await page.evaluate(()=>globalThis.concurrentRuns??0),0);assert.equal(fence.snapshot().failed,false,'Valid pending proof must retain Script without aborting');
        release();
        if(outcome==='VALID'){await page.waitForFunction(()=>globalThis.concurrentRuns===1);await page.waitForLoadState('networkidle');fence.assertSafe();}
        else {for(let i=0;!fence.snapshot().failed&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));assert.equal(fence.snapshot().failed,true);assert.equal(fence.snapshot().failure_code,outcome==='CHANGED'?'FENCE_SCRIPT_HASH':'FENCE_DOCUMENT_RESPONSE_REJECTED');}
        onEvidence({phase:'CONCURRENT_DOCUMENT_SCRIPT_'+outcome,proof_inspections:inspections,script_retained_before_proof:true,observed_script_effects:concurrentEffects-beforeEffects,fence_failed:fence.snapshot().failed,failure_code:fence.snapshot().failure_code});
      },{proofOverride:documentProof,concurrentExpected:outcome==='VALID'?1:0});
    }
    for(const status of [307,308]){onPhase('REDIRECT_'+status);await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();await page.goto(own+'/redirect'+status).catch(()=>{});await new Promise(resolve=>setTimeout(resolve,100));assert.equal(counters.foreign,0,'Redirect transmitted to foreign endpoint');assert(fence.snapshot().failed);});}
    onPhase('NATIVE_POPUP_DENY');await fixture(async({context,page,fence})=>{
      await page.goto(own+'/login');fence.assertSafe();const before=counters.redirect308;
      const denied=await page.evaluate(([foreignURL,ownURL,websocketURL])=>{
        const direct=window.open(foreignURL,'_blank'),approved=window.open(ownURL,'_blank'),blank=window.open('about:blank','_blank');
        if(blank)blank.document.write('<script>fetch('+JSON.stringify(foreignURL)+');new WebSocket('+JSON.stringify(websocketURL)+');<\/script>');
        return direct===null&&approved===null&&blank===null;
      },[other+'/effect',own+'/redirect308',other.replace('http:','ws:')+'/socket']);
      assert(denied,'Native Chromium policy did not deny window.open');
      await page.evaluate(url=>{const a=document.createElement('a');a.href=url;a.target='_blank';a.textContent='Own deny link';document.body.append(a);const form=document.createElement('form');form.action=url;form.target='_blank';const button=document.createElement('button');button.textContent='Own deny form';form.append(button);document.body.append(form);},other+'/effect');
      await page.getByRole('link',{name:'Own deny link',exact:true}).click();await page.getByRole('button',{name:'Own deny form',exact:true}).click();await new Promise(resolve=>setTimeout(resolve,100));
      assert.equal(context.pages().length,1,'A new web contents escaped native denial');assert.equal(counters.foreign,0);assert.equal(counters.redirect308,before);assert.equal(counters.upgrades,0);fence.assertSafe();onEvidence({phase:'NATIVE_POPUP_DENY',foreign_requests:counters.foreign,own_redirect_requests:counters.redirect308-before,websocket_upgrades:counters.upgrades,extra_pages:context.pages().length-1});
    },{expectedPopup:true});
    onPhase('UNEXPECTED_POPUP');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();await page.evaluate(url=>{window.open(url,'_blank');},other+'/effect').catch(()=>{});for(let i=0;!fence.snapshot().failed&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));assert(fence.snapshot().failed,'Unexpected popup attempt was not reported');assert.equal(counters.foreign,0);});
    onPhase('NATIVE_WEBSOCKET_DENY');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();const blocked=await page.evaluate(url=>new Promise(resolve=>{const socket=new WebSocket(url);socket.onopen=()=>{socket.close();resolve(false);};socket.onerror=()=>resolve(true);setTimeout(()=>resolve(false),1000);}),other.replace('http:','ws:')+'/socket');onEvidence({phase:'NATIVE_WEBSOCKET_DENY',browser_error:blocked,websocket_upgrades:counters.upgrades,foreign_http_requests:counters.foreign});if(!blocked)throw Object.assign(Error('Native websocket denial did not occur'),{code:'FENCE_WEBSOCKET_NO_ERROR'});if(counters.upgrades!==0)throw Object.assign(Error('Websocket upgrade reached foreign server'),{code:'FENCE_WEBSOCKET_UPGRADE_TRANSMITTED'});fence.assertSafe();});
    onPhase('IFRAME_FOREIGN');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();await page.evaluate(url=>{const frame=document.createElement('iframe');frame.src=url;document.body.append(frame);},other+'/effect').catch(()=>{});for(let i=0;!fence.snapshot().failed&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));assert(fence.snapshot().failed,'Iframe was not fenced');assert.equal(counters.foreign,0,'Iframe transmitted to foreign endpoint');});
    const workerPayload='fetch('+JSON.stringify(own+'/worker-start')+');fetch('+JSON.stringify(other+'/effect')+');new WebSocket('+JSON.stringify(other.replace('http:','ws:')+'/socket')+');';
    for(const kind of ['HTTP','BLOB','DATA']){onPhase('WORKER_DENY_'+kind);await fixture(async({page,fence})=>{
      await page.goto(own+'/login');fence.assertSafe();const before=counters.worker_scripts,beforeStarts=counters.worker_starts;
      const start=await page.evaluate(({kind,source})=>{try{const url=kind==='HTTP'?'/worker.js':(kind==='BLOB'?URL.createObjectURL(new Blob([source],{type:'text/javascript'})):'data:text/javascript;charset=utf-8,'+encodeURIComponent(source));globalThis.ownFenceWorker=new Worker(url);return {created:true,error:null};}catch(error){return {created:false,error:['SecurityError','TypeError','SyntaxError','ReferenceError'].includes(error.name)?error.name:'Other'};}},{kind,source:workerPayload}).catch(()=>({created:null,error:'CONTEXT_CLOSED'}));
      for(let i=0;!fence.snapshot().failed&&start.created!==false&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));const state=fence.snapshot();onEvidence({phase:'WORKER_DENY_'+kind,worker_created:start.created,worker_error:start.error,worker_waiting:state.worker_waiting,worker_runtime_resumes:state.worker_runtime_resumes,bootstrap_requests:counters.worker_scripts-before,worker_start_requests:counters.worker_starts-beforeStarts,foreign_http_requests:counters.foreign,websocket_upgrades:counters.upgrades,fence_failed:state.failed,failure_code:state.failure_code});
      if(start.created===false)assert.equal(start.error,'SecurityError','Fixture did not exercise a supported or natively denied Worker');else assert(state.failed&&state.worker_waiting>0,'Unexpected Worker did not report FAIL');
      assert.equal(state.worker_runtime_resumes,0);assert.equal(counters.foreign,0);assert.equal(counters.upgrades,0);
    },{ownWorkerAttempt:true});}
    onPhase('NATIVE_SHARED_WORKER_DISABLED');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();const before=counters.worker_scripts,beforeStarts=counters.worker_starts;const outcome=await page.evaluate(()=>{const exposed=typeof SharedWorker;try{new SharedWorker('/worker.js');return {exposed,created:true,error:null};}catch(error){return {exposed,created:false,error:error.name==='ReferenceError'?'ReferenceError':'Other'};}});onEvidence({phase:'NATIVE_SHARED_WORKER_DISABLED',native_interface:outcome.exposed,constructor_error:outcome.error,bootstrap_requests:counters.worker_scripts-before,worker_start_requests:counters.worker_starts-beforeStarts,foreign_http_requests:counters.foreign,websocket_upgrades:counters.upgrades});assert.equal(outcome.exposed,'undefined');assert.equal(outcome.created,false);assert.equal(outcome.error,'ReferenceError');assert.equal(counters.worker_scripts,before);assert.equal(counters.worker_starts,beforeStarts);assert.equal(counters.foreign,0);assert.equal(counters.upgrades,0);fence.assertSafe();});
    onPhase('CHANGED_SCRIPT');await fixture(async({page,fence})=>{await page.goto(own+'/login').catch(()=>{});assert(fence.snapshot().failed,'Changed executable response was not blocked');assert.equal(counters.executed,0,'Changed executable ran before hash proof');},{changed:true});
    onPhase('NATIVE_CORS_ALLOWED');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();const status=await page.evaluate(async url=>(await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{"fixture":true}'})).status,other+'/allow-effect');onEvidence({phase:'NATIVE_CORS_ALLOWED',browser_status:status,preflight_requests:counters.preflight_allowed,post_effects:counters.post_allowed,fence_failed:fence.snapshot().failed});assert.equal(status,200);assert(counters.preflight_allowed>0);assert.equal(counters.post_allowed,1);fence.assertSafe();},{permitForeign:true,cors:'allowed'});
    onPhase('NATIVE_CORS');await fixture(async({page,fence})=>{await page.goto(own+'/login');fence.assertSafe();const outcome=await page.evaluate(async url=>{try{const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{"fixture":true}'});return {rejected:false,status:response.status};}catch{return {rejected:true,status:null};}},other+'/effect');onEvidence({phase:'NATIVE_CORS',browser_rejected:outcome.rejected,browser_status:outcome.status,preflight_requests:counters.preflight,post_effects:counters.post,foreign_http_requests:counters.foreign,fence_failed:fence.snapshot().failed});if(!outcome.rejected)throw Object.assign(Error('Native CORS enforcement was bypassed'),{code:'FENCE_NATIVE_CORS_NOT_REJECTED'});if(!(counters.preflight>0))throw Object.assign(Error('Native preflight did not run'),{code:'FENCE_NATIVE_CORS_PREFLIGHT_NOT_OBSERVED'});if(counters.post!==0)throw Object.assign(Error('Native CORS transmitted denied POST'),{code:'FENCE_NATIVE_CORS_POST_TRANSMITTED'});fence.assertSafe();},{permitForeign:true,cors:'denied'});
    return {native_proxy_exact_origins_verified:true,native_proxy_workers_no_foreign_destinations:true,native_proxy_unavailable_no_direct_fallback:true,redirect_307_blocked:true,redirect_308_blocked:true,native_popups_denied:true,popup_windows_certified:false,unexpected_popup_rejected:true,native_websocket_denied:true,iframe_blocked:true,unexpected_browser_workers_fail_closed:true,shared_worker_natively_disabled:true,browser_worker_execution_certified:false,changed_script_blocked:true,native_cors_positive_verified:true,native_cors_preserved:true,foreign_effects:counters.post,unexpected_execution:counters.executed};
  }finally{await Promise.all([close(local),close(foreign),close(ipv6)]);}
}
// Every variant runs through the real parse5/SDK analyzer while its native
// Document response is paused. These loopback servers never receive credentials.
async function verifyPausedDocumentCDPFence(browser,analyzer,deny,onEvidence){
  let own,foreign,mode='ONE',scriptReads=0,foreignEffects=0,foreignTCP=0,executed=0,documentStarts=0;const sockets=new Set();
  const hash=body=>createHash('sha256').update(body).digest('hex');
  const source=analyzer.fixtureSource;assert.equal(typeof source,'string');
  const html=()=>'<\u0021doctype html><html><head><script>globalThis.ownVariant='+JSON.stringify(mode)+';fetch("/document-start");</script><script type="module" src="/assets/fixture.js"></script>'+(mode==='FOREIGN'?'<script src="'+foreign+'/effect.js"></script>':'')+'</head><body>Own paused Document fixture</body></html>';
  const other=createServer((request,response)=>{foreignEffects++;response.end('globalThis.unexpected=true;');});other.on('connection',()=>foreignTCP++);
  const server=createServer((request,response)=>{
    // Real fixture HTTP close semantics drain the inert Node reader as well as Chromium.
    response.setHeader('Connection','close');
    if(request.url==='/assets/fixture.js'){scriptReads++;response.setHeader('Content-Type','text/javascript');response.end(mode==='MISSING'?'globalThis.unexpected=true;':mode==='WRONG'?source.replaceAll(HML_ORIGIN,'https://foreign.supabase.co'):mode==='CHANGED'&&scriptReads>1?'fetch("/executed");':source);return;}
    if(request.url==='/document-start'){documentStarts++;response.end();return;}
    if(request.url==='/executed'){executed++;response.end();return;}
    response.setHeader('Content-Type','text/html');response.end(html());
  });
  for(const s of [server,other])s.on('connection',socket=>{sockets.add(socket);socket.once('close',()=>sockets.delete(socket));});
  const listen=s=>new Promise((resolve,reject)=>{s.once('error',reject);s.listen(0,'127.0.0.1',()=>resolve('http://127.0.0.1:'+s.address().port));});
  try{own=await listen(server);foreign=await listen(other);
    let previousHash;
    for(const variant of ['ONE','TWO','FOREIGN','MISSING','WRONG','CHANGED']){
      mode=variant;scriptReads=0;documentStarts=0;const positive=['ONE','TWO'].includes(variant),context=await browser.newContext({serviceWorkers:'block',proxy:nativeDestinationProxy([own],deny.port)}),page=await context.newPage();let fence,inspections=0;
      try{
        const proof={origin:own,modules:new Map([[own+'/assets/fixture.js',hash(source)]]),inspectDocument:async(body,url)=>{
          inspections++;assert.equal(documentStarts,0,'Document executed before inspection');
          const result=await inspectDocumentAtOrigin(fetch,analyzer,body,url,()=>{},own);assert.equal(result.runtimeProof.html_sha256,hash(body));return result;
        }};
        fence=await installPublishedCDPFence(browser,context,page,proof,url=>new URL(url).origin===own);
        await page.goto(own+'/login').catch(error=>{if(positive)throw error;});
        if(positive){await page.waitForFunction(()=>globalThis.nativeFenceFixture===true);fence.assertSafe();assert.equal(await page.evaluate(()=>globalThis.ownVariant),variant);const state=fence.snapshot();assert.equal(state.document_proofs.length,1);assert(state.loaded_script_sha256.includes(hash(source)));const digest=state.document_proofs[0].html_sha256;if(previousHash)assert.notEqual(digest,previousHash);previousHash=digest;}
        else {for(let i=0;!fence.snapshot().failed&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));assert(fence.snapshot().failed,'Rejected Document/graph escaped');}
        assert.equal(inspections,1);
      }finally{
        await context.close();for(let i=0;sockets.size&&i<100;i++)await new Promise(resolve=>setTimeout(resolve,10));await new Promise(resolve=>setTimeout(resolve,100));
        onEvidence({phase:'PAUSED_DOCUMENT_'+variant,positive,inspections,fence_failed:fence?.snapshot().failed??null,failure_code:fence?.snapshot().failure_code??null,tcp_connections:sockets.size,document_start_requests:documentStarts,script_requests:scriptReads,foreign_tcp_connections:foreignTCP,foreign_http_requests:foreignEffects,unexpected_script_execution:executed,after_context_close_and_tcp_drain:true});
        assert.equal(sockets.size,0);assert.equal(foreignTCP,0);assert.equal(foreignEffects,0);assert.equal(executed,0);assert.equal(documentStarts,positive||variant==='CHANGED'?1:0);
      }
    }
  }finally{await Promise.all([new Promise(resolve=>server.close(resolve)),new Promise(resolve=>other.close(resolve))]);}
}
// Inert source analysis. Fetched modules are parsed, never imported or evaluated.
// Client identity is a complete class AST match to the frozen installed SDK, not a name/string heuristic.
export function publishedAnalyzer(ts,referenceSource){
  const parse=(name,source)=>{const file=ts.createSourceFile(name,source,ts.ScriptTarget.Latest,true,ts.ScriptKind.JS);assert.equal(file.parseDiagnostics.length,0);return file;};
  const visit=(node,fn)=>{fn(node);ts.forEachChild(node,c=>visit(c,fn));};
  const isClass=n=>ts.isClassDeclaration(n)||ts.isClassExpression(n);
  function program(modules){
    const files=new Map([...modules].map(([name,source])=>[name,parse(name,source)]));
    const host={getSourceFile:name=>files.get(name),getDefaultLibFileName:()=>'',writeFile:()=>{},getCurrentDirectory:()=> '/',getDirectories:()=>[],fileExists:name=>files.has(name),readFile:name=>modules.get(name),getCanonicalFileName:n=>n,useCaseSensitiveFileNames:()=>true,getNewLine:()=> '\n',resolveModuleNames:(names,from)=>names.map(n=>{const resolvedFileName=new URL(n,from).href;return files.has(resolvedFileName)?{resolvedFileName,extension:ts.Extension.Js}:undefined;})};
    const p=ts.createProgram([...modules.keys()],{allowJs:true,noLib:true,noResolve:false,target:ts.ScriptTarget.Latest,module:ts.ModuleKind.ESNext},host);
    return {files,checker:p.getTypeChecker()};
  }
  function fingerprint(node,checker){
    const symbols=new Map();
    function encode(n){
      if(ts.isParenthesizedExpression(n))return encode(n.expression);
      if(ts.isIdentifier(n)){
        const property=(ts.isBindingElement(n.parent)&&n.parent.propertyName===n)||(ts.isPropertyAccessExpression(n.parent)&&n.parent.name===n)||((ts.isPropertyAssignment(n.parent)||ts.isMethodDeclaration(n.parent)||ts.isGetAccessorDeclaration(n.parent)||ts.isSetAccessorDeclaration(n.parent))&&n.parent.name===n);
        if(property||['URL','Error','Proxy','Promise','Object','JSON','String','Number','Boolean','Array','Map','Set','Symbol','RegExp','Math','Date','console','globalThis','undefined'].includes(n.text))return ['property',n.text];
        const symbol=checker.getSymbolAtLocation(n);assert(symbol,'Unresolved SDK identifier');if(!symbols.has(symbol))symbols.set(symbol,symbols.size);return ['binding',symbols.get(symbol)];
      }
      if(ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n)||ts.isNumericLiteral(n)||ts.isRegularExpressionLiteral(n))return [n.kind,n.text];
      const children=[];ts.forEachChild(n,c=>{if(c!==node.name&&c.kind!==ts.SyntaxKind.ExportKeyword&&c.kind!==ts.SyntaxKind.DefaultKeyword)children.push(encode(c));});return [n.kind,...children];
    }
    return JSON.stringify(encode(node));
  }
  const reference=program(new Map([[PUBLISHED_ORIGIN+'/assets/reference.js',referenceSource]]));const referenceClasses=[];
  for(const file of reference.files.values())visit(file,n=>{if(isClass(n)&&n.members.some(m=>m.name?.text==='_initSupabaseAuthClient')&&n.members.some(m=>m.name?.text==='_getAccessToken'||m.name?.text==='_getSessionToken'))referenceClasses.push(n);});
  assert.equal(referenceClasses.length,1,'Frozen SDK client implementation unavailable');
  const trustedFingerprint=fingerprint(referenceClasses[0],reference.checker);
  function imports(source){
    const file=parse(PUBLISHED_ORIGIN+'/assets/module.js',source),found=[];
    visit(file,n=>{
      if(ts.isImportDeclaration(n)||ts.isExportDeclaration(n)){if(n.moduleSpecifier){assert(ts.isStringLiteral(n.moduleSpecifier));found.push(n.moduleSpecifier.text);}}
      if(ts.isCallExpression(n)&&n.expression.kind===ts.SyntaxKind.ImportKeyword){assert(n.arguments.length===1&&(ts.isStringLiteral(n.arguments[0])||ts.isNoSubstitutionTemplateLiteral(n.arguments[0])));found.push(n.arguments[0].text);}
      // eval/new Function would hide effective clients from static binding analysis.
      if((ts.isCallExpression(n)||ts.isNewExpression(n))&&ts.isIdentifier(n.expression))assert(!['eval','Function'].includes(n.expression.text));
    });
    for(const name of found)assert(/^(?:\.\.?\/|\/assets\/)/.test(name));return [...new Set(found)];
  }
  function prove(modules,entries){
    assert(entries.length>0&&entries.every(e=>modules.has(e)));const {files,checker}=program(modules),nodes=[];
    for(const file of files.values())visit(file,n=>nodes.push(n));
    const symbol=n=>{let result=checker.getSymbolAtLocation(n);if(result?.flags&ts.SymbolFlags.Alias)result=checker.getAliasedSymbol(result);return result;};
    const unwrap=n=>ts.isParenthesizedExpression(n)?unwrap(n.expression):n;
    const candidates=nodes.filter(n=>isClass(n)&&n.members.some(m=>m.name?.text==='_initSupabaseAuthClient'));assert.equal(candidates.length,1);
    const clients=candidates.filter(n=>fingerprint(n,checker)===trustedFingerprint);
    assert.equal(clients.length,1,'SDK implementation is ambiguous or unsupported');
    const client=clients[0],className=ts.isVariableDeclaration(client.parent)?client.parent.name:client.name;assert(className&&ts.isIdentifier(className));const clientSymbol=symbol(className);assert(clientSymbol);
    const factories=new Map();
    for(const n of nodes){
      if(!ts.isArrowFunction(n)&&!ts.isFunctionExpression(n)&&!ts.isFunctionDeclaration(n))continue;
      let body=n.body;if(ts.isBlock(body)){if(body.statements.length!==1||!ts.isReturnStatement(body.statements[0]))continue;body=body.statements[0].expression;}
      if(!body)continue;body=unwrap(body);
      if(!ts.isNewExpression(body)||symbol(body.expression)!==clientSymbol)continue;
      assert(n.parameters.length>=2&&n.parameters.length<=3&&body.arguments?.length===n.parameters.length);
      assert(n.parameters.every((p,i)=>ts.isIdentifier(p.name)&&ts.isIdentifier(body.arguments[i])&&symbol(p.name)===symbol(body.arguments[i])));
      const name=n.name??(ts.isVariableDeclaration(n.parent)?n.parent.name:null);assert(name&&ts.isIdentifier(name));factories.set(symbol(name),body);
    }
    const instances=nodes.filter(n=>(ts.isCallExpression(n)&&factories.has(symbol(unwrap(n.expression))))||(ts.isNewExpression(n)&&symbol(n.expression)===clientSymbol&&![...factories.values()].includes(n)));
    assert.equal(instances.length,1,'Multiple or unresolved configured clients');const call=instances[0];
    function literal(n,seen=new Set()){
      n=unwrap(n);if(ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n))return n.text;
      assert(ts.isIdentifier(n));const sym=symbol(n);assert(sym&&!seen.has(sym));seen.add(sym);const declarations=sym.declarations??[];assert.equal(declarations.length,1);const d=declarations[0];
      assert(ts.isVariableDeclaration(d)&&d.initializer&&(d.parent.flags&ts.NodeFlags.Const));return literal(d.initializer,seen);
    }
    assert(call.arguments.length>=2&&call.arguments.length<=3);assert.equal(literal(call.arguments[0]),HML_ORIGIN);assert(literal(call.arguments[1]).length>20);
    if(call.arguments[2]){
      const options=unwrap(call.arguments[2]);assert(ts.isObjectLiteralExpression(options));
      for(const prop of options.properties){assert(ts.isPropertyAssignment(prop)&&prop.name.text==='auth'&&ts.isObjectLiteralExpression(prop.initializer));for(const field of prop.initializer.properties)assert(ts.isPropertyAssignment(field)&&['storage','persistSession','autoRefreshToken','detectSessionInUrl','storageKey','flowType'].includes(field.name.text));}
    }
    assert(ts.isVariableDeclaration(call.parent)&&ts.isIdentifier(call.parent.name));const instanceSymbol=symbol(call.parent.name);assert(instanceSymbol);
    const configuredSymbols=new Set([instanceSymbol]),aliases=new Map();
    // Bundlers lower const to var: prove a single initialized binding and reject every write.
    // Every use is checked below; an unused alias or a value escaping as an argument fails closed.
    let added=true;
    while(added){added=false;for(const node of nodes){
      if(!ts.isVariableDeclaration(node)||!ts.isIdentifier(node.name)||!node.initializer||!ts.isIdentifier(node.initializer))continue;
      const source=symbol(node.initializer),target=symbol(node.name);
      if(configuredSymbols.has(source)&&target&&target.declarations?.length===1&&!configuredSymbols.has(target)){configuredSymbols.add(target);aliases.set(target,{declaration:node,used:false});added=true;}
    }}
    const isConfigured=n=>configuredSymbols.has(symbol(n));
    const mutationRoot=n=>{n=unwrap(n);while(ts.isPropertyAccessExpression(n)||ts.isElementAccessExpression(n))n=unwrap(n.expression);return n;};
    const usage=new Set();
    for(const node of nodes){
      if(ts.isStringLiteral(node)&&/^https?:\/\/[^/]+\.supabase\.(co|in)(?:\/|$)/.test(node.text))assert.equal(new URL(node.text).origin,HML_ORIGIN,'Foreign backend configuration');
      const boundRpcCall=ts.isCallExpression(node)&&ts.isPropertyAccessExpression(node.expression)&&['call','bind'].includes(node.expression.name.text)&&ts.isPropertyAccessExpression(node.expression.expression)&&node.expression.expression.name.text==='rpc'&&isConfigured(node.expression.expression.expression);
      if(boundRpcCall)assert((node.expression.name.text==='bind'?node.arguments.length===1:node.arguments.length>=2)&&ts.isIdentifier(node.arguments[0])&&isConfigured(node.arguments[0]),'RPC call receiver must be the configured client');
      if(ts.isIdentifier(node)&&isConfigured(node)){
        const parent=node.parent;
        const ownRpcReceiver=ts.isCallExpression(parent)&&parent.arguments[0]===node&&ts.isPropertyAccessExpression(parent.expression)&&['call','bind'].includes(parent.expression.name.text)&&ts.isPropertyAccessExpression(parent.expression.expression)&&parent.expression.expression.name.text==='rpc'&&isConfigured(parent.expression.expression.expression);
        const aliasInitializer=ts.isVariableDeclaration(parent)&&parent.initializer===node&&aliases.get(symbol(parent.name))?.declaration===parent;
        if(ts.isPropertyAccessExpression(parent)&&parent.expression===node&&aliases.has(symbol(node)))aliases.get(symbol(node)).used=true;
        assert(aliasInitializer||(ts.isVariableDeclaration(parent)&&parent.name===node)||(ts.isPropertyAccessExpression(parent)&&parent.expression===node)||ts.isImportSpecifier(parent)||ts.isExportSpecifier(parent)||ownRpcReceiver,'Unresolved configured client alias or escape');
      }
      if(ts.isCallExpression(node)&&ts.isPropertyAccessExpression(node.expression)&&ts.isPropertyAccessExpression(node.expression.expression)){
        const member=node.expression.expression;if(isConfigured(member.expression))usage.add(member.name.text+'.'+node.expression.name.text);
      }
      if(ts.isDeleteExpression(node)){const target=mutationRoot(node.expression);assert(!configuredSymbols.has(symbol(target)),'Configured client mutation is unsupported');}
      if((ts.isPrefixUnaryExpression(node)||ts.isPostfixUnaryExpression(node))&&[ts.SyntaxKind.PlusPlusToken,ts.SyntaxKind.MinusMinusToken].includes(node.operator)){const target=mutationRoot(node.operand);assert(!configuredSymbols.has(symbol(target)),'Configured client mutation is unsupported');}
      if(ts.isBinaryExpression(node)&&node.operatorToken.kind>=ts.SyntaxKind.FirstAssignment&&node.operatorToken.kind<=ts.SyntaxKind.LastAssignment){
        const target=mutationRoot(node.left);assert(![...configuredSymbols,clientSymbol,...factories.keys()].includes(symbol(target)),'Configured client mutation is unsupported');
      }
    }
    for(const alias of aliases.values())assert(alias.used,'Configured client alias is unused or unresolved');
    assert(usage.has('auth.signInWithPassword')&&usage.has('functions.invoke'),'Client is not bound to login and document flow');
    return {verified:true};
  }
  return {version:ts.version,imports,prove};
}
async function loadPublishedAnalyzer(frontend){
  const require=createRequire(join(frontend,'package.json')),ts=require('typescript'),compiler=require('rolldown/utils');
  assert.equal(require('rolldown').VERSION,'1.2.1','Frozen frontend compiler required');
  assert.equal(require('@supabase/supabase-js/package.json').version,'2.118.0','Frozen frontend SDK required');
  const entry=require.resolve('@supabase/supabase-js');const candidate=entry.replace(/index\.cjs$/, 'index.mjs');
  const original=readFileSync(candidate,'utf8');const transformed=compiler.minifySync('sdk-reference.js',original);assert(!transformed.errors?.length);
  const parser=createRequire(require.resolve('jsdom/package.json'))('parse5');validateHTMLParserFixtures(parser);
  const analyzer=publishedAnalyzer(ts,transformed.code);analyzer.htmlEntries=html=>publicHTMLScripts(parser,html);analyzer.reference_sha256=createHash('sha256').update(original).digest('hex');analyzer.compiler_version='1.2.1';
  // Real parser positive/negative fixtures run in the canonical probe, never a mocked parser PASS.
  // Source remains inert, including the synthetic appended consumer calls.
  assert.deepEqual(analyzer.imports('import(`./constant.js`)'),['./constant.js']);
  for(const code of ['import(`./${unknown}.js`)','import(unknown)'])assert.throws(()=>analyzer.imports(code));
  const referenceName=analyzer; // one parser instance with one frozen class identity
  const file=ts.createSourceFile('reference.js',transformed.code,ts.ScriptTarget.Latest,true,ts.ScriptKind.JS);let ctor;
  function locate(n){if((ts.isClassDeclaration(n)||ts.isClassExpression(n))&&n.members.some(m=>m.name?.text==='_initSupabaseAuthClient'))ctor=n.name?.text??n.parent.name?.text;ts.forEachChild(n,locate);}locate(file);assert(ctor);
  const append=url=>transformed.code+';const proofURL='+JSON.stringify(url)+';const proofClient=new '+ctor+'(proofURL,"public_fixture_key_not_a_secret");proofClient.auth.signInWithPassword({});proofClient.functions.invoke("storage-sign-upload");';
  const name=PUBLISHED_ORIGIN+'/assets/fixture.js',positive=append(HML_ORIGIN);referenceName.prove(new Map([[name,positive]]),[name]);
  const fixtureEntry='\0own-paused-document-fixture';
  const bundled=await require('rolldown').build({cwd:frontend,input:fixtureEntry,write:false,platform:'browser',plugins:[{name:'own-paused-document-fixture',resolveId:id=>id===fixtureEntry?id:null,load:id=>id===fixtureEntry?'import {createClient} from '+JSON.stringify(candidate)+';export function ownInertFixtureConsumer(){const client=createClient('+JSON.stringify(HML_ORIGIN)+',"public_fixture_key_not_a_secret");client.auth.signInWithPassword({});client.functions.invoke("storage-sign-upload");}globalThis.nativeFenceFixture=true;':null}],output:{format:'esm',minify:true}});
  assert.equal(bundled.output.length,1);assert.equal(bundled.output[0].type,'chunk');const fixtureSource=bundled.output[0].code;assert.deepEqual(analyzer.imports(fixtureSource),[]);referenceName.prove(new Map([[name,fixtureSource]]),[name]);Object.defineProperty(analyzer,'fixtureSource',{value:fixtureSource});
  const factory=positive.replace('const proofClient=new '+ctor+'(proofURL,','const proofFactory=(a,b)=>new '+ctor+'(a,b);const proofClient=proofFactory(proofURL,');referenceName.prove(new Map([[name,factory]]),[name]);
  // The real frontend RBAC adapter binds Function.call to the same client receiver.
  const bound=positive+';proofClient.rpc.call(proofClient,"obter_resumo_dashboard",{});';
  referenceName.prove(new Map([[name,bound]]),[name]);
  for(const source of [positive+';unboundClient.rpc.call(proofClient,"other",{});',positive+';proofClient.rpc.call(unboundClient,"other",{});'])assert.throws(()=>referenceName.prove(new Map([[name,source]]),[name]));
  for(const declaration of ['const','var','let']){
    const aliased=positive+';'+declaration+' proofAlias=proofClient;proofAlias.rpc("fixture",{});';
    referenceName.prove(new Map([[name,aliased]]),[name]);
  }
  referenceName.prove(new Map([[name,positive+';const proofBound=proofClient.rpc.bind(proofClient);proofBound("fixture",{});']]),[name]);
  for(const suffix of [';const proofAlias=proofClient;consume(proofAlias);',';const proofAlias=proofClient;proofAlias.rpc=unknown;',';let proofAlias=proofClient;proofAlias=unknown;proofAlias.rpc("fixture",{});',';let proofAlias=proofClient;proofAlias++;proofAlias.rpc("fixture",{});',';const proofAlias=proofClient;delete proofAlias.rpc;proofAlias.rpc("fixture",{});',';const proofAlias=proofClient;proofAlias.rpc.call(unboundClient,"fixture",{});',';const proofAlias=proofClient;(proofAlias.rpc)=unknown;', ';const proofAlias=proofClient;delete (proofAlias.rpc);',';const proofAlias=proofClient;(proofAlias.rpc)++;',';proofClient.rpc.bind(unboundClient);',';unboundClient.rpc.bind(proofClient);'])assert.throws(()=>referenceName.prove(new Map([[name,positive+suffix]]),[name]));
  const negatives=[append('https://foreign.supabase.co')+';const unused='+JSON.stringify(HML_ORIGIN)+';',positive+';const another=new '+ctor+'(proofURL,"public_fixture_key_not_a_secret");',positive.replace('new '+ctor+'(proofURL,','new '+ctor+'(unknownConfiguration,'),positive.replace('proofClient.auth.signInWithPassword','unboundClient.auth.signInWithPassword'),positive.replace('new '+ctor+'(proofURL,','misleadingCreateClient(proofURL,'),positive+';const escaped=proofClient;',positive+';proofClient.auth=unknown;'];
  for(const source of negatives)assert.throws(()=>referenceName.prove(new Map([[name,source]]),[name]));
  return analyzer;
}
export async function fillDocumentUploadForm(dialog,file,version,title,nonce,stage){
  stage('SELECT_FILE');await dialog.getByLabel(version===1?'Arquivos':'Arquivo',{exact:true}).setInputFiles({name:file.name,mimeType:file.mime,buffer:file.bytes});
  if(version===1){
    stage('FILL_TITLE');await dialog.getByLabel('Título de '+file.name,{exact:true}).fill(title);
    stage('FILL_CATEGORY');await dialog.getByLabel('Categoria',{exact:true}).fill('synthetic-'+nonce);
    stage('FILL_START_DATE');await dialog.getByLabel('Início da vigência',{exact:true}).fill('2026-01-01');
  }else{stage('FILL_REASON');await dialog.getByLabel('Motivo da nova versão',{exact:true}).fill('Own synthetic replacement '+nonce);}
}
export async function awaitDocumentTransfer(received,stage,check){
  const names=['WAIT_SIGN_UPLOAD','WAIT_STORAGE_UPLOAD','WAIT_CONFIRM_UPLOAD','WAIT_REGISTER_DOCUMENT'],responses=[];
  for(const [i,wait] of received.entries()){stage(names[i]);const response=await wait;check('DOCUMENT_TRANSFER_STAGE_'+i,response.ok(),response.status());responses.push(response);}
  return responses;
}
export function sanitizeDocumentDiagnostic(value){
  const result={};for(const key of ['upload_button_present','upload_button_enabled','dialog_open','file_input_present','queue_present','title_input_present','form_alert','format_rejected','config_unavailable','upload_busy','upload_complete','config_loaded','txt_allowed','pdf_allowed']){assert.equal(typeof value[key],'boolean');result[key]=value[key];}
  result.network={};for(const key of ['config','sign','storage','confirm','register']){const v=value.network[key];assert(Number.isInteger(v.requests)&&v.requests>=0&&v.requests<=1000);assert(v.http===null||Number.isInteger(v.http)&&v.http>=100&&v.http<=599);assert.equal(typeof v.failed,'boolean');result.network[key]={requests:v.requests,http:v.http,failed:v.failed};}return result;
}
export function recordDocumentVisualAssertion(report,name,pass){
  assert(/^DOCUMENT_(?:ACCESSIBILITY|NO_PAGE_OVERFLOW)_(?:1440|1280|768|390)_(?:light|dark|LIGHT|DARK)$/.test(name));
  const record=publicRecord({name,pass});report.assertions.push(record);
  if(!pass){report.document_visual_failures??=[];report.document_visual_failures.push(name);}
}
export function documentCoverage(){return {completed_scopes:['DOCUMENTOS_UPLOAD_VERSION_WORKER_UI_EDGE_AND_SIGNED_GET_PARTIAL'],remaining_domains:['documentos_contrato','documento_detalhe'],global_complete:false};}
export function documentFixture(nonce,format,version){
  assert(/^[a-f0-9]{32}$/.test(nonce)&&['txt','pdf'].includes(format)&&[1,2].includes(version));
  const text='ContaOS own synthetic document '+nonce+' version '+version+'. No personal data.';
  let bytes=Buffer.from(text+'\n');
  if(format==='pdf'){
    const stream='BT /F1 12 Tf 40 760 Td ('+text+') Tj ET';
    const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>','<< /Length '+Buffer.byteLength(stream)+' >>\nstream\n'+stream+'\nendstream'];
    let pdf='%PDF-1.4\n',offsets=[0];for(const [i,obj] of objects.entries()){offsets.push(Buffer.byteLength(pdf));pdf+=(i+1)+' 0 obj\n'+obj+'\nendobj\n';}
    const start=Buffer.byteLength(pdf);pdf+='xref\n0 6\n0000000000 65535 f \n'+offsets.slice(1).map(x=>String(x).padStart(10,'0')+' 00000 n \n').join('')+'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n'+start+'\n%%EOF\n';bytes=Buffer.from(pdf);
  }
  return {bytes,name:'crudg-'+nonce+'-'+format+'-v'+version+'.'+format,mime:format==='pdf'?'application/pdf':'text/plain',size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};
}
export function validateDocumentReceipt(value,expected){
  const uuid=x=>typeof x==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(x);
  for(const key of ['id_documento','id_arquivo','id_versao'])assert(uuid(value?.[key]));
  assert.equal(value.id_arquivo,expected.file);assert.equal(value.numero_versao,expected.version);
  if(expected.document)assert.equal(value.id_documento,expected.document);
}
export function validateDocumentProgress(value,expected){
  for(const key of ['org','contract','file','sha256','size'])assert.equal(value[key],expected[key]);
  assert.equal(value.security,'aprovado');assert.equal(value.processing,'concluido');assert.equal(value.job,'concluido');
  assert(Number.isInteger(value.pages)&&value.pages>0&&Number.isInteger(value.fragments)&&value.fragments>0);
}
export function validateDocumentDenial(value,kind){
  assert(['upload','download','mutation'].includes(kind));
  assert(kind==='download'?value.status===404&&value.code==='REGISTRO_NAO_ENCONTRADO':kind==='upload'?value.status===403&&value.code==='AUTH_ACESSO_NEGADO':value.status===403&&value.code==='42501');
}
export function browserEnvironment(source){
  const allowed=['PATH','HOME','RUNNER_TEMP','TMPDIR','LANG','TZ','CI','XDG_CACHE_HOME','CONTAOS_TEST_PRIVATE_DIR','CONTAOS_FRONTEND_DIR','CONTAOS_AXE_SOURCE_PATH','CONTAOS_PLAYWRIGHT_MODULE','TESTED_HEAD','FRONTEND_HEAD'];
  return Object.fromEntries(allowed.filter(k=>source[k]!==undefined).map(k=>[k,source[k]]));
}
export function publicRecord({name,pass,http}){
  assert(/^[A-Z0-9_]{1,100}$/.test(name)&&typeof pass==='boolean');
  assert(http===undefined||Number.isInteger(http)&&http>=100&&http<=599);
  return {name,pass,...(http===undefined?{}:{http})};
}
export function validateAuditDenied(result){
  assert(([200,206].includes(result.status)&&result.count===0&&result.code===null)||(result.status===403&&result.code==='42501'&&result.count===null));
}
export function validateAuditRead(raw,rows,org,status=200){
  assert([200,206].includes(status));
  const url=new URL(raw);
  const fields=['id','criado_em','evento','entidade','origem','id_usuario','id_entidade','correlation_id'];
  assert.equal(url.origin,'https://gklhhhyosgasnyoxlrui.supabase.co');
  assert.equal(url.pathname,'/rest/v1/eventos_auditoria');
  assert.equal(url.searchParams.get('select'),fields.join(','));
  assert.equal(url.searchParams.get('id_organizacao'),'eq.'+org);
  assert.equal(url.searchParams.get('limit'),'25');
  assert(/^\d+$/.test(url.searchParams.get('offset')??''));
  assert(Array.isArray(rows)&&rows.length<=25);
  for(const row of rows)assert.deepEqual(Object.keys(row).sort(),[...fields].sort());
}
export function sanitizeUiDiagnostic(value){
  const result={};
  for(const key of ['manage_list','change_state','loading','denied','inconsistent','transient','pending']){
    assert(typeof value[key]==='boolean');result[key]=value[key];
  }
  assert(value.read_http===null||Number.isInteger(value.read_http)&&value.read_http>=100&&value.read_http<=599);
  result.read_http=value.read_http;return result;
}
export function validateReceipt(name,request,data){
  const uuid=x=>typeof x==='string'&&/^[a-f0-9-]{36}$/.test(x);
  if(name==='criar_organizacao'){assert(uuid(data));return;}
  if(name==='atualizar_contratante'){
    assert.equal(data?.schema_versao,'v103-v1');assert.equal(data?.contratante?.id,request.p_id_contratante);
    for(const key of ['nome_fantasia','razao_social','situacao'])assert.equal(data.contratante[key],request['p_'+key]||null);
    return;
  }
  assert(uuid(data?.evento_id));assert.equal(data?.request_id,request.p_request_id);
  if(name==='executar_comando_lista_v1'){
    assert(uuid(data.lista?.id));assert.equal(data.acao,request.p_acao);
    if(request.p_id_lista)assert.equal(data.lista.id,request.p_id_lista);
    assert.equal(data.lista.versao_registro,(request.p_versao_esperada??0)+1);
    const fields=request.p_acao==='alterar_situacao'?['situacao']:['criar_lista','editar_lista'].includes(request.p_acao)?['nome','descricao']:[];
    for(const key of fields)if(key in request.p_payload)assert.equal(data.lista[key],request.p_payload[key]);
  }else{
    assert(data.registro);
    for(const [key,value] of Object.entries(request.p_alteracoes??{situacao:request.p_situacao}))assert.equal(data.registro[key],value);
  }
}
export async function withReadTransportFailure(session,action){
  try{
    await session.send('Network.enable');
    await session.send('Network.setBlockedURLs',{urls:['*gklhhhyosgasnyoxlrui.supabase.co/rest/v1/rpc/obter_lista_operacional_v1*']});
    return await action();
  }finally{try{await session.send('Network.setBlockedURLs',{urls:[]});}finally{await session.detach();}}
}
export async function fillNextVersionDates(page,start){
  await page.getByLabel('Início da vigência',{exact:true}).fill(start);
  await page.getByLabel('Fim da vigência',{exact:true}).fill('');
}
export async function applyDocumentTitleFilter(page,title){
  const form=page.getByRole('form',{name:'Filtros',exact:true});
  await form.getByLabel('Buscar por título',{exact:true}).fill(title);
  await form.getByRole('button',{name:'Aplicar filtros',exact:true}).click();
}
export async function selectListState(page,state){
  assert(['ativa','inativa'].includes(state));
  const form=page.locator('form').filter({has:page.getByRole('heading',{name:'Alterar situação',exact:true})});
  await form.getByRole('combobox').selectOption(state);
}
export function listUiIsSettled(expectedName){
  if(typeof expectedName!=='string'||!expectedName)return false;
  const panel=document.querySelector('section[aria-label="Gestão de listas"]');
  if(!panel)return false;
  const edit=[...panel.querySelectorAll('button')].find(b=>b.textContent.trim()==='Editar lista');
  return !!edit&&!edit.disabled&&!panel.textContent.includes('Enviando operação…')&&panel.textContent.includes(expectedName);
}
export function summarizeAccessibility(raw){
  assert.equal(raw.testEngine?.version,'4.14.0');
  function entry(item,impact){
    assert(typeof item.id==='string'&&/^[a-z0-9-]{1,100}$/.test(item.id));
    const nodes=Array.isArray(item.nodes)?item.nodes.length:item.nodes;assert(Number.isInteger(nodes)&&nodes>=0);
    if(impact)assert(['minor','moderate','serious','critical',null].includes(item.impact));
    return {id:item.id,...(impact?{impact:item.impact}:{}),nodes};
  }
  return {version:raw.testEngine.version,violations:raw.violations.map(x=>entry(x,true)),incomplete:raw.incomplete.map(x=>entry(x,false))};
}
export function loginFormIsInteractive(){const e=document.querySelector('form');return !!e&&Object.keys(e).some(k=>k.startsWith('__reactProps$')&&typeof e[k]?.onSubmit==='function');}
async function stop(server,browser){
  let timer;
  try{if(browser)await Promise.race([browser.close(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Browser close timeout')),2000);})]);}
  finally{clearTimeout(timer);if(server?.pid){try{process.kill(-server.pid,'SIGTERM');}catch(e){if(e.code!=='ESRCH')throw e;}await Promise.race([new Promise(r=>server.once('exit',r)),new Promise(r=>setTimeout(r,1500))]);try{process.kill(-server.pid,'SIGKILL');}catch(e){if(e.code!=='ESRCH')throw e;}}}
}
async function main(){
  assert(!process.env.DATABASE_URL&&!process.env.AUTH_ADMIN_KEY&&!process.env.GH_TOKEN);
  const root=resolve(process.env.CONTAOS_TEST_PRIVATE_DIR||'');assert(root.startsWith(resolve(process.env.RUNNER_TEMP)+'/'));
  const frontend=resolve(process.env.CONTAOS_FRONTEND_DIR||'');const req=createRequire(process.env.CONTAOS_PLAYWRIGHT_MODULE);assert.equal(req('playwright/package.json').version,'1.64.1');const {chromium,expect}=req('playwright/test');
  const probe=process.argv.includes('--public-probe');const f=probe?null:JSON.parse(readFileSync(join(root,'fixture.json'),'utf8'));
  if(f)assert(['CADASTROS_LISTAS','AUDITORIA','DOCUMENTOS'].includes(f.batch));
  const output=join(root,'public-browser');mkdirSync(output,{recursive:true,mode:0o700});
  const report={schema:'contaos.crud-global.browser.v1',backend_head:process.env.TESTED_HEAD,frontend_head:process.env.FRONTEND_HEAD,batch:probe?'PUBLIC_PROBE':f.batch||'CADASTROS_LISTAS',global_complete:false,popup_rendering:'NAO_CERTIFICADO',download_proof_kind:'UI_EDGE_AND_SIGNED_GET',state:'RUNNING',stage:'START',visual:[],assertions:[],runtime_errors:[],limits:['Partial batch; remaining matrix domains are not certified','No physical upload or worker proof in this batch','Automated tests do not certify full manual WCAG','Native Chromium denies new windows; popup rendering is not certified','Unexpected browser Worker aborts and SharedWorker is natively disabled; backend queue worker proof remains required','Official UI Edge response and bounded signed GET integrity are separate proofs','Stable-state contrast does not close historical transient V117 contrast']};
  const save=()=>writeFileSync(join(output,probe?'public-probe.json':'report.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});
  function stage(s){assert(!finalizeUnexpectedBrowserWorker(report),'Unexpected browser Worker');assert(/^[A-Z0-9_]{1,100}$/.test(s));report.stage=s;save();}
  const recorder=createProofRecorder(report,save);const check=(name,pass,http)=>{assert(!finalizeUnexpectedBrowserWorker(report),'Unexpected browser Worker');return recorder.check(name,pass,http);};
  function created(name,id){assert(['organization','contractor','contract','list'].includes(name)&&/^[a-f0-9-]{36}$/.test(id));f.created[name]=id;writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});}
  const base='http://127.0.0.1:4173';const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','4173'],{cwd:frontend,detached:true,stdio:'ignore',env:browserEnvironment(process.env)});let browser;let nativeDeny;let diagnosticPage;let publishedProof;let expectedPublishedDownload=null;let readHttp=null;const publishedFinalizers=[];
  const documentNetwork=Object.fromEntries(['config','sign','storage','confirm','register'].map(k=>[k,{requests:0,http:null,failed:false}]));
  const documentConfig={config_loaded:false,txt_allowed:false,pdf_allowed:false};
  function documentEndpoint(raw){const u=new URL(raw);if(u.origin!=='https://gklhhhyosgasnyoxlrui.supabase.co')return null;const p=u.pathname;if(p==='/rest/v1/configuracao_upload')return 'config';if(p==='/functions/v1/storage-sign-upload')return 'sign';if(p.startsWith('/storage/v1/object/upload/sign/'))return 'storage';if(p==='/rest/v1/rpc/confirmar_upload_arquivo')return 'confirm';if(['/rest/v1/rpc/criar_documento_contrato_completo','/rest/v1/rpc/adicionar_versao_documento_contrato'].includes(p))return 'register';return null;}
  try{
    stage('SERVER_READY');for(let i=0;i<120;i++){try{if((await fetch(base+'/login')).ok)break;}catch{}if(i===119)throw Error('Frontend unavailable');await new Promise(r=>setTimeout(r,1000));}
    const reservation=createServer();await new Promise((resolve,reject)=>{reservation.once('error',reject);reservation.listen(0,'127.0.0.1',resolve);});const debugPort=reservation.address().port;await new Promise(resolve=>reservation.close(resolve));
    browser=await chromium.launch({headless:true,args:['--block-new-web-contents','--disable-blink-features=SharedWorker','--remote-debugging-port='+debugPort,'--remote-debugging-address=127.0.0.1'],env:browserEnvironment(process.env)});browserDebugPorts.set(browser,debugPort);nativeDeny=await startNativeDestinationDeny();report.browser_version=browser.version();assert(/^\d+\.\d+\.\d+\.\d+$/.test(report.browser_version));report.playwright_version='1.64.1';save();
    async function open(role,origin=base){
      const beforeDeny=nativeDeny.snapshot().connections;const context=await browser.newContext({viewport:{width:1440,height:1000},colorScheme:'light',locale:'pt-BR',serviceWorkers:'block',proxy:nativeDestinationProxy([origin,HML_ORIGIN],nativeDeny.port)});
      context.on('page',created=>created.on('worker',()=>{report.unexpected_browser_worker=true;finalizeUnexpectedBrowserWorker(report);save();void context.close().catch(()=>{});}));context.on('serviceworker',()=>{report.unexpected_browser_worker=true;finalizeUnexpectedBrowserWorker(report);save();void context.close().catch(()=>{});});

      const page=await context.newPage();const fence=origin===PUBLISHED_ORIGIN?await installPublishedCDPFence(browser,context,page,publishedProof,(url,navigation)=>publishedRequestAllowed(url,navigation,f?.uploads?.filter(u=>u.provenance==='PUBLISHED'&&u.path).map(u=>u.path)??[]),raw=>{if(!expectedPublishedDownload)return false;try{const url=new URL(raw);return url.origin===HML_ORIGIN&&!url.username&&!url.password&&url.pathname==='/storage/v1/object/sign/contaos-documentos/'+expectedPublishedDownload;}catch{return false;}}):null;page._publishedFenceSnapshot=()=>fence?{...fence.snapshot(),proxy_deny_connections:nativeDeny.snapshot().connections-beforeDeny}:null;page.setDefaultTimeout(30000);diagnosticPage=page;
      if(fence){const record=recorder.fenceRecorder();publishedFinalizers.push(()=>{const snapshot=page._publishedFenceSnapshot();record(snapshot);return snapshot.failed;});context.on('close',()=>record(page._publishedFenceSnapshot()));}
      page.on('response',r=>{if(r.url().endsWith('/rpc/obter_lista_operacional_v1')&&r.request().method()==='POST')readHttp=r.status();});
      if(f?.batch==='DOCUMENTOS'){
        page.on('request',r=>{const key=documentEndpoint(r.url());if(key)documentNetwork[key].requests=Math.min(1000,documentNetwork[key].requests+1);});
        page.on('requestfailed',r=>{const key=documentEndpoint(r.url());if(key)documentNetwork[key].failed=true;});
        page.on('response',async r=>{const key=documentEndpoint(r.url());if(!key)return;documentNetwork[key].http=r.status();if(key==='config'&&r.ok()){try{const raw=await r.json(),v=Array.isArray(raw)?raw[0]:raw;const ext=v?.extensoes_permitidas,mime=v?.mimes_permitidos;if(Array.isArray(ext)&&Array.isArray(mime)){documentConfig.config_loaded=true;documentConfig.txt_allowed=ext.includes('txt')&&mime.includes('text/plain');documentConfig.pdf_allowed=ext.includes('pdf')&&mime.includes('application/pdf');}}catch{}}});
      }

      page.on('pageerror',e=>{report.runtime_errors.push({name:['Error','TypeError','SyntaxError','ReferenceError'].includes(e.name)?e.name:'Other'});save();});
      stage((origin===PUBLISHED_ORIGIN?'PUBLISHED_':'')+'LOGIN_'+role.toUpperCase());await page.goto(origin+'/login');await page.waitForFunction(loginFormIsInteractive);
      if(origin===PUBLISHED_ORIGIN){await page.waitForLoadState('networkidle');assert.equal(new URL(page.url()).origin,PUBLISHED_ORIGIN);fence.assertSafe();recorder.fence(page._publishedFenceSnapshot());}
      page._publishedFence=()=>{if(origin===PUBLISHED_ORIGIN){fence.assertSafe();assert.equal(new URL(page.url()).origin,PUBLISHED_ORIGIN);recorder.fence(page._publishedFenceSnapshot());}};
      if(probe){await page.getByRole('button',{name:'Mostrar senha',exact:true}).click();await expect(page.getByLabel('Senha',{exact:true})).toHaveAttribute('type','text');check('PUBLIC_INTERACTIVITY',true);return{context,page};}
      const u=f.users.find(x=>x.profile===role);assert(u?.id&&u.creation_state==='created');await page.getByLabel('E-mail',{exact:true}).fill(u.email);await page.getByLabel('Senha',{exact:true}).fill(u.password);
      page._publishedFence();const received=page.waitForResponse(r=>r.url().startsWith(HML_ORIGIN+'/auth/v1/token?')&&r.request().method()==='POST');await page.getByRole('button',{name:'Entrar',exact:true}).click();const login=await received;check('LOGIN_'+role.toUpperCase(),login.status()===200,login.status());await page.waitForURL(u=>!u.pathname.includes('/login'));page._publishedFence();return{context,page};
    }
    async function chooseOrg(page,id){
      await page.goto(new URL(page.url()).origin+'/selecionar-organizacao');
      const label=f.prefix+(id===f.org?'A':'B');
      await page.getByRole('radio').filter({hasText:label}).click();
      await page.getByRole('button',{name:'Continuar',exact:true}).click();
      await page.waitForURL(u=>!u.pathname.includes('/selecionar-organizacao'));
      await expect(page.getByRole('navigation').first()).toBeVisible();
    }
    async function mutate(page,code,endpoint,action,method='POST'){
      stage(code);const got=page.waitForResponse(r=>r.url().includes(endpoint)&&r.request().method()===method);await action();const response=await got;check(code,response.status()>=200&&response.status()<300,response.status());let data=null;try{data=await response.json();}catch{}return{data,request:response.request().postDataJSON()};
    }
    const rpc=async(page,code,name,action)=>{const result=await mutate(page,code,'/rpc/'+name,action);validateReceipt(name,result.request,result.data);check(code+'_RECEIPT',true);if(result.request.p_request_id){f.commands??=[];f.commands.push({name,request_id:result.request.p_request_id});writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});}return result;};
    async function manager(page,kind){const name=kind==='org'?'Gerenciar organização selecionada':'Editar e gerenciar contrato';const button=page.getByRole('button',{name,exact:true});const region=page.getByRole('region',{name:kind==='org'?'Gestão da organização':'Gestão do contrato',exact:true});if(!await region.isVisible())await button.click();await expect(region).toBeVisible();return region;}
    async function editCadastro(page,region,kind,field,value,code){await expect(region.getByLabel(field,{exact:true})).toBeEnabled();await region.getByLabel(field,{exact:true}).fill(value);await region.getByLabel('Motivo',{exact:true}).fill('Own synthetic CRUD verification');await region.getByRole('button',{name:'Revisar edição',exact:true}).click();await rpc(page,code,kind==='org'?'atualizar_organizacao_v1':'atualizar_contrato_v1',()=>region.getByRole('button',{name:'Confirmar edição',exact:true}).click());}
    async function stateCadastro(page,region,kind,state,code){await expect(region.getByLabel('Nova situação',{exact:true})).toBeEnabled();await region.getByLabel('Motivo',{exact:true}).fill('Own synthetic lifecycle verification');await region.getByLabel('Nova situação',{exact:true}).selectOption(state);await region.getByRole('button',{name:'Revisar situação',exact:true}).click();await rpc(page,code,kind==='org'?'alterar_situacao_organizacao_v1':'alterar_situacao_contrato_v1',()=>region.getByRole('button',{name:'Confirmar mudança de situação',exact:true}).click());}
    if(probe){
      stage('PREVENTIVE_NETWORK_FENCE_FIXTURES');report.preventive_network_fence=await verifyPublishedCDPFence(browser,phase=>{report.fence_fixture_phase=phase;save();},evidence=>{report.fence_fixture_evidence=evidence;report.fence_fixture_evidences??=[];assert(report.fence_fixture_evidences.length<128);report.fence_fixture_evidences.push(evidence);save();},nativeDeny);check('NATIVE_PREVENTIVE_FENCE_FIXTURES',true);
      stage('PUBLISHED_BACKEND_READONLY_FENCE');const analyzer=await loadPublishedAnalyzer(frontend);await verifyPausedDocumentCDPFence(browser,analyzer,nativeDeny,evidence=>{report.paused_document_evidence??=[];report.paused_document_evidence.push(evidence);save();});report.published_backend=await inspectPublishedBackend(fetch,analyzer,phase=>{report.backend_inspection_phase=phase;save();});publishedProof=report.published_backend.runtimeProof;check('PUBLISHED_REAL_PARSER_FIXTURES',true);check('PUBLISHED_BACKEND_CONFIGURATION',true);
      const published=await open('master',PUBLISHED_ORIGIN);published.page._publishedFence();check('PUBLISHED_NATIVE_FENCE_AND_LOADED_HASHES',true);await published.context.close();
      const x=await open('master');const sample=await x.context.newPage();
      await sample.setContent('<select aria-label="Filtro externo"><option value="ativa">Ativa</option><option value="inativa">Inativa</option></select><form><h3>Alterar situação</h3><label><span>Situação</span><select><option value="ativa">Ativa</option><option value="inativa">Inativa</option></select></label></form>');
      check('WRAPPED_SELECT_EXACT_LABEL_MISMATCH',await sample.getByLabel('Situação',{exact:true}).count()===0);
      await selectListState(sample,'inativa');await expect(sample.locator('form').getByRole('combobox')).toHaveValue('inativa');
      await expect(sample.getByRole('combobox',{name:'Filtro externo',exact:true})).toHaveValue('ativa');check('LIST_STATE_SCOPED_INACTIVE',true);
      await selectListState(sample,'ativa');await expect(sample.locator('form').getByRole('combobox')).toHaveValue('ativa');check('LIST_STATE_SCOPED_ACTIVE',true);
      await sample.setContent('<form aria-label="Filtros"><label>Buscar por título<input></label><button>Aplicar filtros</button></form><ul aria-label="Documentos"><li>Own published txt</li><li>Own local txt</li><li>Own local pdf</li></ul>');
      await sample.evaluate(()=>{document.querySelector('form').onsubmit=e=>{e.preventDefault();const title=document.querySelector('input').value;for(const row of document.querySelectorAll('li'))row.hidden=!row.textContent.includes(title);};});
      await sample.getByLabel('Buscar por título',{exact:true}).fill('Own local ');
      await expect(sample.getByRole('listitem')).toHaveCount(3);check('DOCUMENT_DRAFT_FILTER_NOT_APPLIED',true);
      await applyDocumentTitleFilter(sample,'Own local ');await expect(sample.getByRole('listitem')).toHaveCount(2);check('DOCUMENT_FILTER_SUBMITTED_BEFORE_ROW_ASSERTION',true);
      await x.page.evaluate(()=>sessionStorage.setItem('contaos.public-probe-tab-context','synthetic-own-context'));
      const fresh=await x.context.newPage();await fresh.goto(base+'/login');
      check('NEW_TAB_HAS_SEPARATE_SESSION_STORAGE',await fresh.evaluate(()=>sessionStorage.getItem('contaos.public-probe-tab-context'))===null);
      await sample.setContent('<section aria-label="Gestão de listas"><p>Old list</p><p role="status">Enviando operação…</p><button disabled>Editar lista</button></section>');
      check('VISUAL_REJECTS_BUSY_PANEL',!await sample.evaluate(listUiIsSettled,'Own recovered'));
      const settled=sample.waitForFunction(listUiIsSettled,'Own recovered');
      await sample.evaluate(()=>{setTimeout(()=>{const p=document.querySelector('section');p.innerHTML='<p>Own recovered</p><button>Editar lista</button>';},50);});
      await settled;check('VISUAL_WAITS_FOR_RECOVERED_ENABLED_PANEL',await sample.evaluate(listUiIsSettled,'Own recovered'));
      await x.context.close();assert(!finalizeUnexpectedBrowserWorker(report));report.state='PASS_PUBLIC_PROBE';save();return;
    }
    if(f.batch==='DOCUMENTOS'){
      let admin,ap,docsPath,batchDeadline;let provenance='PUBLISHED';f.uploads??=[];
      const persist=()=>persistBrowserFixture(join(root,'fixture.json'),f);
      const smoke={schema:'contaos.published-document-smoke.v1',popup_rendering:'NAO_CERTIFICADO',download_proof_kind:'UI_EDGE_AND_SIGNED_GET',frontend_head:null,source_parity:'NAO_VERIFICADA',state:'RUNNING',assertions:[]};
      const saveSmoke=()=>writeFileSync(join(output,'published-smoke.json'),JSON.stringify(smoke,null,2)+'\n',{mode:0o600});saveSmoke();
      async function documentPage(origin){admin=await open('administrador',origin);ap=admin.page;await chooseOrg(ap,f.org);docsPath=origin+'/contratos/'+f.contract+'/documentos';await ap.goto(docsPath);await expect(ap.getByRole('heading',{name:'Central de documentos',exact:true})).toBeVisible();ap._publishedFence();}
      async function publishedProgress(intent,deadline){
        const sequence=(f.readiness_control?.sequence??0)+1;
        const request={action:'PUBLISHED_READINESS',nonce:f.nonce,sequence,intent_nonce:intent.intent_nonce,file:intent.file,document:intent.document,id_version:intent.id_version};
        const requestPath=join(root,'document-readiness-request.json'),responsePath=join(root,'document-readiness-response.json');
        assert(!existsSync(requestPath));if(existsSync(responsePath))unlinkSync(responsePath);
        writeFileSync(requestPath+'.tmp',JSON.stringify(request),{mode:0o600});renameSync(requestPath+'.tmp',requestPath);
        while(!existsSync(responsePath)){assert(Date.now()<deadline);await new Promise(r=>setTimeout(r,100));}
        const ack=JSON.parse(readFileSync(responsePath,'utf8'));assert.deepEqual(Object.keys(ack).sort(),['action','nonce','sequence','state']);assert.equal(ack.action,request.action);assert.equal(ack.nonce,f.nonce);assert.equal(ack.sequence,sequence);assert(['READY','PENDING','FAILED'].includes(ack.state));
        f.readiness_control={sequence,state:ack.state};assert.notEqual(ack.state,'FAILED');ap._publishedFence();return ack.state==='READY';
      }
      async function upload(format,version,document){
        stage('DOCUMENT_UPLOAD_'+format.toUpperCase()+'_V'+version);
        const contentNonce=provenance==='PUBLISHED'?createHash('sha256').update(f.nonce+'-published').digest('hex').slice(0,32):f.nonce;const file=documentFixture(contentNonce,format,version);file.name='crudg-'+f.nonce+'-'+provenance.toLowerCase()+'-'+format+'-v'+version+'.'+format;const title=f.prefix+provenance.toLowerCase()+' '+format;
        const intent={provenance,frontend_head:provenance==='PUBLISHED'?null:FRONTEND_PIN,source_parity:provenance==='PUBLISHED'?'NAO_VERIFICADA':'PINNED',intent_nonce:f.nonce+'-'+provenance.toLowerCase()+'-'+format+'-'+version,org:f.org,contract:f.contract,name:file.name,mime:file.mime,sha256:file.sha256,size:file.size,version,title,state:'INTENT',...(document?{document}:{} )};
        f.uploads.push(intent);persist(); // durable before opening the form or making any upload request
        const substage=action=>stage('DOCUMENT_'+provenance+'_'+format.toUpperCase()+'_V'+version+'_'+action);
        substage('OPEN_FORM');await ap.getByRole('button',{name:version===1?'Enviar documentos':'Nova versão de '+title,exact:true}).click();
        const dialog=ap.getByRole('dialog');substage('WAIT_DIALOG');await expect(dialog).toBeVisible();
        await fillDocumentUploadForm(dialog,file,version,title,f.nonce,substage);
        const waits=['/functions/v1/storage-sign-upload','/storage/v1/object/upload/sign/','/rpc/confirmar_upload_arquivo','/rpc/'+(version===1?'criar_documento_contrato_completo':'adicionar_versao_documento_contrato')].map(part=>ap.waitForResponse(r=>r.url().includes(part)&&['POST','PUT'].includes(r.request().method()),{timeout:60000}));
        // Observe all receipts before submitting; consume them in order for precise failure stages.
        for(const wait of waits)wait.catch(()=>{});
        substage('SUBMIT_FORM');await dialog.getByRole('button',{name:version===1?'Enviar e registrar':'Enviar nova versão',exact:true}).click();
        const responses=await awaitDocumentTransfer(waits,substage,check);
        substage('VALIDATE_UPLOAD_RECEIPTS');
        const authorization=await responses[0].json();assert(authorization.ok&&authorization.bucket==='contaos-documentos'&&authorization.path.startsWith(f.org+'/uploads/')&&authorization.path.endsWith('/'+file.name));
        intent.path=authorization.path;intent.state='UPLOADED';persist();
        const request=responses[2].request().postDataJSON();assert.equal(request.p_nome_original,file.name);assert.equal(request.p_mime,file.mime);assert.equal(request.p_sha256,file.sha256);assert.equal(request.p_tamanho,file.size);assert.equal(request.p_path,intent.path);assert.equal(request.p_id_organizacao,f.org);assert.equal(request.p_id_contrato,f.contract);
        intent.file=await responses[2].json();intent.state='CONFIRMED';persist();
        const receipt=await responses[3].json();validateDocumentReceipt(receipt,intent);intent.document=receipt.id_documento;intent.id_version=receipt.id_versao;intent.state='REGISTERED';persist();
        substage('CLOSE_FORM');await expect(dialog.getByRole('button',{name:'Fechar',exact:true})).toBeEnabled();await dialog.getByRole('button',{name:'Fechar',exact:true}).click();
        substage('WAIT_REAL_WORKER');const deadline=Math.min(batchDeadline,Date.now()+300000);let ready=false;
        while(Date.now()<deadline){
          if(provenance==='PUBLISHED'){
            await ap.getByRole('button',{name:'Atualizar lista',exact:true}).click();
            const button=ap.getByRole('button',{name:'Baixar '+file.name,exact:true});
            const uiReady=await button.count()===1&&await button.isEnabled();
            if(await publishedProgress(intent,deadline)&&uiReady){ready=true;break;}
            await new Promise(r=>setTimeout(r,5000));continue;
          }
          const progress=await ap.evaluate(async expected=>{
            const {supabase}=await import('/src/integrations/supabase/client.ts');
            const ar=await supabase.from('arquivos').select('id,id_organizacao,id_contrato,sha256,tamanho,status_seguranca').eq('id',expected.file).single();
            const pr=await supabase.from('processamentos_documento').select('status').eq('id_versao_documento',expected.id_version).eq('etapa','documents').single();
            const jobs=await supabase.from('execucoes_assincronas').select('status').eq('entidade_id',expected.id_version).eq('fila','documents').limit(2);
            const pages=await supabase.from('paginas_documento').select('id',{count:'exact',head:true}).eq('id_versao_documento',expected.id_version);
            const fragments=await supabase.from('fragmentos_documento').select('id',{count:'exact',head:true}).eq('id_versao_documento',expected.id_version);
            if([ar,pr,jobs,pages,fragments].some(r=>r.error))return {read_failed:true};
            const a=ar.data;return {org:a.id_organizacao,contract:a.id_contrato,file:a.id,sha256:a.sha256,size:Number(a.tamanho),security:a.status_seguranca,processing:pr.data.status,job:jobs.data.length===1?jobs.data[0].status:null,pages:pages.count,fragments:fragments.count};
          },intent);
          if(progress.read_failed)throw Error('Document progress read failed');
          if(['bloqueado','quarentena'].includes(progress.security)||['falhou','cancelado'].includes(progress.processing))throw Error('Document worker failed');
          try{validateDocumentProgress(progress,intent);ready=true;break;}catch{}
          await new Promise(r=>setTimeout(r,5000));
        }
        check('DOCUMENT_REAL_WORKER_'+format.toUpperCase()+'_V'+version,ready);intent.state='PROCESSED';persist();
        substage('REFRESH_DOCUMENT_LIST');await ap.getByRole('button',{name:'Atualizar lista',exact:true}).click();
        substage('DOWNLOAD_DOCUMENT');const downloadResponse=ap.waitForResponse(r=>r.url().endsWith('/functions/v1/storage-sign-download')&&r.request().method()==='POST');
        if(provenance==='PUBLISHED')expectedPublishedDownload=intent.path;
        const popup=admin.context.waitForEvent('page',{timeout:1000}).catch(()=>null);
        await ap.getByRole('button',{name:'Baixar '+file.name,exact:true}).click();const signed=await downloadResponse;check('DOCUMENT_OFFICIAL_DOWNLOAD',signed.ok(),signed.status());
        assert.equal(signed.request().postDataJSON().id_arquivo,intent.file);const signedData=await signed.json();assert.equal(signedData.ok,true);const url=new URL(signedData.signed_url);assert.equal(url.origin,'https://gklhhhyosgasnyoxlrui.supabase.co');assert.equal(url.pathname,'/storage/v1/object/sign/contaos-documentos/'+intent.path);
        const bytes=await boundedSignedDownload(fetch,url.href,intent.path,file.size);check('DOCUMENT_SIGNED_GET_HASH_AND_SIZE',bytes.length===file.size&&createHash('sha256').update(bytes).digest('hex')===file.sha256,200);
        const opened=await popup;if(opened)await opened.close();expectedPublishedDownload=null;intent.download_verified=true;intent.download_proof_kind='UI_EDGE_AND_SIGNED_GET';intent.popup_rendering='NAO_CERTIFICADO';persist();ap._publishedFence();return intent.document;
      }
      await runDocumentProvenances({
        proveBackend:async()=>{stage('PUBLISHED_BACKEND_READONLY_FENCE');try{const analyzer=await loadPublishedAnalyzer(frontend);smoke.backend=await inspectPublishedBackend(fetch,analyzer,phase=>{smoke.backend_inspection_phase=phase;saveSmoke();});publishedProof=smoke.backend.runtimeProof;saveSmoke();}catch(e){smoke.state='PUBLICADA_BACKEND_NAO_COMPROVADO';saveSmoke();throw e;}},
        published:async deadline=>recorder.published(smoke,saveSmoke,async()=>{batchDeadline=deadline;
          try{report.local_state='NOT_STARTED';await documentPage(PUBLISHED_ORIGIN);await upload('txt',1);assert.equal(report.runtime_errors.length,0);smoke.state='PASS_SMOKE';smoke.runtime_errors=[];saveSmoke();await admin.context.close();}
          catch(e){smoke.state='FAIL';saveSmoke();throw e;}
        }),
        local:async deadline=>{batchDeadline=deadline;provenance='LOCAL';report.local_state='RUNNING';for(const key of Object.keys(documentNetwork))documentNetwork[key]={requests:0,http:null,failed:false};Object.assign(documentConfig,{config_loaded:false,txt_allowed:false,pdf_allowed:false});assert.equal(process.env.FRONTEND_HEAD,FRONTEND_PIN);await documentPage(base);
      for(const format of ['txt','pdf']){const document=await upload(format,1);await upload(format,2,document);}
      stage('DOCUMENT_LOCAL_RELOAD_AFTER_UPLOADS');await ap.reload();
      stage('DOCUMENT_LOCAL_APPLY_TITLE_FILTER');await applyDocumentTitleFilter(ap,f.prefix+'local ');
      stage('DOCUMENT_LOCAL_VERIFY_FILTERED_ROWS');await expect(ap.getByRole('list',{name:'Documentos',exact:true}).locator(':scope > li')).toHaveCount(2);
      stage('DOCUMENT_LOCAL_ACCESSIBILITY_SETUP');await ap.addScriptTag({path:process.env.CONTAOS_AXE_SOURCE_PATH});
      for(const theme of ['light','dark'])for(const width of [1440,1280,768,390]){
        stage('DOCUMENT_VISUAL_'+width+'_'+theme.toUpperCase());await ap.setViewportSize({width,height:1000});await ap.evaluate(t=>{document.documentElement.classList.toggle('dark',t==='dark');document.documentElement.style.colorScheme=t;},theme);
        await ap.getByRole('button',{name:'Atualizar lista',exact:true}).focus();await expect(ap.getByRole('button',{name:'Atualizar lista',exact:true})).toBeFocused();await ap.keyboard.press('Tab');
        recordDocumentVisualAssertion(report,'DOCUMENT_NO_PAGE_OVERFLOW_'+width+'_'+theme.toUpperCase(),await ap.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));save();
        const raw=await ap.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {testEngine:{version:r.testEngine.version},violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
        const a11y=summarizeAccessibility(raw),name='crud-documents-'+width+'-'+theme+'.png';await ap.screenshot({path:join(output,name),animations:'disabled',fullPage:true});report.visual.push({width,theme,a11y,screenshot:name});save();recordDocumentVisualAssertion(report,'DOCUMENT_ACCESSIBILITY_'+width+'_'+theme.toUpperCase(),a11y.violations.length===0);save();
      }
      stage('DOCUMENT_REVOKE_AUTHORIZED_SESSION');
      const ownAdmin=f.users.find(u=>u.profile==='administrador');
      const control={action:'REVOKE_OWN_ADMIN',nonce:f.nonce,org:f.org,user:ownAdmin.id};
      writeFileSync(join(root,'document-control-request.tmp'),JSON.stringify(control),{mode:0o600});renameSync(join(root,'document-control-request.tmp'),join(root,'document-control-request.json'));
      const controlDeadline=Date.now()+60000;while(!existsSync(join(root,'document-control-response.json'))){assert(Date.now()<controlDeadline,'Revocation controller timeout');await new Promise(r=>setTimeout(r,100));}
      const ack=JSON.parse(readFileSync(join(root,'document-control-response.json'),'utf8'));assert.deepEqual(ack,{action:'REVOKE_OWN_ADMIN',nonce:f.nonce,state:'REVOKED'});
      const revoked=await ap.evaluate(async input=>{
        const {supabase}=await import('/src/integrations/supabase/client.ts');
        const session=await supabase.auth.getUser();
        const mutation=await supabase.rpc('adicionar_versao_documento_contrato',{p_id_documento:input.document,p_id_arquivo:input.file,p_motivo:'Own revoked permission probe',p_chave_idempotencia:crypto.randomUUID()});
        const read=await supabase.from('documentos_contrato').select('id').eq('id_contrato',input.contract).limit(25);
        const download=await supabase.functions.invoke('storage-sign-download',{body:{id_arquivo:input.file}});let code=null,status=download.error?.context?.status??(download.error?0:200);try{code=(await download.error.context.json()).codigo;}catch{}
        return {session_valid:!session.error&&session.data.user?.id===input.user,mutation:{status:mutation.status,code:mutation.error?.code??null},read:{status:read.status,code:read.error?.code??null,count:read.data?.length??null},download:{status,code}};
      },{document:f.uploads.find(u=>u.provenance==='LOCAL').document,file:f.uploads.find(u=>u.provenance==='LOCAL').file,contract:f.contract,user:ownAdmin.id});
      check('DOCUMENT_REVOKED_SESSION_STILL_AUTHENTICATED',revoked.session_valid);
      validateDocumentDenial(revoked.mutation,'mutation');validateDocumentDenial(revoked.download,'download');validateAuditDenied(revoked.read);
      check('DOCUMENT_REVOKED_MUTATION_DENIED',true,revoked.mutation.status);check('DOCUMENT_REVOKED_DOWNLOAD_DENIED',true,revoked.download.status);check('DOCUMENT_REVOKED_READ_DENIED',true,revoked.read.status);
      await admin.context.close();
      for(const role of ['master','leitor','usuario_b']){
        const user=await open(role);await chooseOrg(user.page,role==='usuario_b'?f.org_b:f.org);await user.page.goto(docsPath);
        if(role==='master'){await expect(user.page.getByRole('list',{name:'Documentos',exact:true})).toBeVisible();check('DOCUMENT_MASTER_READ',true);}
        else {
          if(role==='usuario_b')await expect(user.page.getByRole('alert')).toBeVisible();
          const result=await user.page.evaluate(async input=>{
            const {supabase}=await import('/src/integrations/supabase/client.ts');
            const up=await supabase.functions.invoke('storage-sign-upload',{body:{id_organizacao:input.org,id_contrato:input.contract,nome_arquivo:'negative.txt',mime:'text/plain',tamanho:1}});
            async function edgeResult(r){if(!r.error)return {status:200,code:null};const response=r.error.context;if(!response||typeof response.status!=='number')return {status:0,code:null};let data={};try{data=await response.json();}catch{}return {status:response.status,code:data.codigo??null};}
            const upload=await edgeResult(up);
            const mutation=await supabase.rpc('adicionar_versao_documento_contrato',{p_id_documento:input.document,p_id_arquivo:input.file,p_motivo:'Own negative permission probe',p_chave_idempotencia:crypto.randomUUID()});
            const read=await supabase.from('documentos_contrato').select('id').eq('id_contrato',input.contract).limit(25);
            let download=null;if(input.other)download=await edgeResult(await supabase.functions.invoke('storage-sign-download',{body:{id_arquivo:input.file}}));
            return {upload,mutation:{status:mutation.status,code:mutation.error?.code??null},read:{status:read.status,code:read.error?.code??null,count:read.data?.length??null},download};
          },{org:f.org,contract:f.contract,file:f.uploads.find(u=>u.provenance==='LOCAL').file,document:f.uploads.find(u=>u.provenance==='LOCAL').document,other:role==='usuario_b'});
          validateDocumentDenial(result.upload,'upload');validateDocumentDenial(result.mutation,'mutation');check('DOCUMENT_'+role.toUpperCase()+'_VERSION_DENIED',true,result.mutation.status);check('DOCUMENT_'+role.toUpperCase()+'_UPLOAD_DENIED',true,result.upload.status);
          if(role==='usuario_b'){validateAuditDenied(result.read);validateDocumentDenial(result.download,'download');check('DOCUMENT_OTHER_TENANT_READ_DOWNLOAD_DENIED',true,result.download.status);}
          else {assert([200,206].includes(result.read.status)&&result.read.count===3);check('DOCUMENT_READER_READ_ALLOWED',true,result.read.status);}
        }
        await user.context.close();
      }
      report.limits=report.limits.filter(x=>x!=='No physical upload or worker proof in this batch');report.limits.push('TXT/PDF only; other formats, multipart, AI extraction and full manual WCAG remain unverified');check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);assert(!finalizeUnexpectedBrowserWorker(report));report.document_backend_state='PASS_BROWSER_PENDING_SQL';save();if(report.document_visual_failures?.length)throw Object.assign(new Error('Document visual audit failed'),{code:'DOCUMENT_VISUAL_AUDIT_FAILED'});report.state='PASS_BATCH';Object.assign(report,documentCoverage());report.completed_domains=[];report.local_state='PASS';save();}
      });return;
    }
    if(f.batch==='AUDITORIA'){
      const admin=await open('administrador');const ap=admin.page;await chooseOrg(ap,f.org);
      stage('AUDIT_REAL_EVENTS_SETUP');await ap.goto(base+'/contratos/'+f.contract);
      for(let i=0;i<27;i++){
        const region=await manager(ap,'contract');
        await editCadastro(ap,region,'contract','Objeto',f.prefix+'audit-'+i,'AUDIT_SETUP_EDIT_'+i);
      }
      const auditPath=base+'/administracao/auditoria';
      async function readAudit(page,org,action,predicate=()=>true,allowEmpty=false){
        const got=page.waitForResponse(r=>r.request().method()==='GET'&&new URL(r.url()).pathname==='/rest/v1/eventos_auditoria'&&predicate(new URL(r.url())));
        await action();const response=await got;check('AUDIT_READ_HTTP',[200,206].includes(response.status()),response.status());
        const rows=await response.json();validateAuditRead(response.url(),rows,org,response.status());check('AUDIT_SAFE_PROJECTION_AND_SCOPE',true);
        if(!allowEmpty)assert(rows.length>0);
        if(rows.length){f.audit_reads??=[];f.audit_reads.push({org,ids:rows.map(r=>r.id)});writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});}
        await expect(page.getByRole('heading',{name:'Trilha de auditoria',exact:true})).toBeVisible();
        return rows;
      }
      stage('AUDIT_ADMIN_FIRST_PAGE');const rows=await readAudit(ap,f.org,()=>ap.goto(auditPath));assert.equal(rows.length,25);
      await expect(ap.getByRole('region',{name:'Eventos de auditoria',exact:true})).toBeVisible();
      const reference=rows.find(r=>r.id_usuario===f.users.find(u=>u.profile==='administrador').id);assert(reference);
      stage('AUDIT_PAGINATION');await readAudit(ap,f.org,()=>ap.getByRole('button',{name:'Próxima',exact:true}).click(),u=>u.searchParams.get('offset')==='25');
      await expect(ap.getByText('Página 2',{exact:true})).toBeVisible();
      await readAudit(ap,f.org,()=>ap.getByRole('button',{name:'Anterior',exact:true}).click(),u=>u.searchParams.get('offset')==='0');
      check('AUDIT_PAGINATION_REAL',true);
      for(const [label,key,value] of [['Evento','evento',reference.evento],['Entidade','entidade',reference.entidade],['ID do usuário','id_usuario',reference.id_usuario],['Correlation ID','correlation_id',reference.correlation_id]]){
        stage('AUDIT_FILTER_'+key.toUpperCase());assert(value);
        const result=await readAudit(ap,f.org,()=>ap.getByLabel(label,{exact:true}).fill(value),u=>u.searchParams.get(key)==='eq.'+value);
        assert(result.every(r=>r[key]===value));await expect(ap.getByText('Página 1',{exact:true})).toBeVisible();
        await readAudit(ap,f.org,()=>ap.getByLabel(label,{exact:true}).fill(''),u=>!u.searchParams.has(key));
        check('AUDIT_FILTER_'+key.toUpperCase(),true);
      }
      stage('AUDIT_DATE_FILTER');await readAudit(ap,f.org,()=>ap.getByLabel('Data inicial',{exact:true}).fill('2026-01-01'),u=>u.searchParams.getAll('criado_em').some(v=>v==='gte.2026-01-01T03:00:00.000Z'));
      await readAudit(ap,f.org,()=>ap.getByLabel('Data final',{exact:true}).fill('2027-12-31'),u=>u.searchParams.getAll('criado_em').some(v=>v==='lte.2028-01-01T02:59:59.000Z'));check('AUDIT_DATE_FILTER_BOUNDS',true);
      await expect(ap.getByText(reference.correlation_id,{exact:true}).first()).toBeVisible();
      await ap.addScriptTag({path:process.env.CONTAOS_AXE_SOURCE_PATH});
      for(const theme of ['light','dark'])for(const width of [1440,1280,768,390]){
        stage('AUDIT_VISUAL_'+width+'_'+theme.toUpperCase());await ap.setViewportSize({width,height:1000});
        await ap.evaluate(t=>{document.documentElement.classList.toggle('dark',t==='dark');document.documentElement.style.colorScheme=t;},theme);
        const table=ap.getByRole('region',{name:'Eventos de auditoria',exact:true});await table.focus();await expect(table).toBeFocused();await ap.keyboard.press('ArrowRight');
        check('AUDIT_TABLE_KEYBOARD_FOCUS_'+width+'_'+theme.toUpperCase(),true);
        check('AUDIT_NO_PAGE_OVERFLOW_'+width+'_'+theme.toUpperCase(),await ap.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
        await ap.waitForFunction(()=>document.getAnimations().every(a=>a.playState!=='running'||a.effect?.getTiming().iterations===Infinity),undefined,{timeout:5000});
        await ap.evaluate(()=>window.scrollTo({top:0,left:0,behavior:'instant'}));
        const top='crud-audit-'+width+'-'+theme+'-top.png',panel='crud-audit-'+width+'-'+theme+'-panel.png';
        await ap.screenshot({path:join(output,top),animations:'disabled'});
        await table.evaluate(e=>e.scrollIntoView({block:'start',behavior:'instant'}));
        const raw=await ap.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {testEngine:{version:r.testEngine.version},violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
        const a11y=summarizeAccessibility(raw);report.visual.push({width,theme,a11y,screenshots:{top,panel},scope:'Audit table focus and stable screenshots; manual WCAG pending'});save();
        await ap.screenshot({path:join(output,panel),animations:'disabled'});
        check('AUDIT_AUTOMATED_ACCESSIBILITY_'+width+'_'+theme.toUpperCase(),a11y.violations.length===0);
      }
      await admin.context.close();
      for(const role of ['master','auditor','juridico_conformidade']){
        stage('AUDIT_ALLOWED_'+role.toUpperCase());const user=await open(role);await chooseOrg(user.page,f.org);
        await readAudit(user.page,f.org,()=>user.page.goto(auditPath));check('AUDIT_ALLOWED_'+role.toUpperCase(),true);await user.context.close();
      }
      async function assertRlsDenied(page,name){
        const result=await page.evaluate(async org=>{
          const {supabase}=await import('/src/integrations/supabase/client.ts');
          const {data,error,status}=await supabase.from('eventos_auditoria').select('id').eq('id_organizacao',org).limit(25);
          return {count:data?.length??null,code:error?.code??null,status};
        },f.org);
        validateAuditDenied(result);check(name,true,result.status);
      }
      const reader=await open('leitor');await chooseOrg(reader.page,f.org);let deniedReads=0;
      reader.page.on('request',r=>{if(new URL(r.url()).pathname==='/rest/v1/eventos_auditoria')deniedReads++;});
      stage('AUDIT_READER_DENIED');await reader.page.goto(auditPath);await expect(reader.page.getByRole('alert')).toContainText('Você não tem permissão para consultar a auditoria desta organização.');check('AUDIT_READER_NO_QUERY',deniedReads===0);await assertRlsDenied(reader.page,'AUDIT_READER_REAL_RLS_DENIED');await reader.context.close();
      const other=await open('usuario_b');await chooseOrg(other.page,f.org_b);stage('AUDIT_OTHER_TENANT');
      const foreign=await readAudit(other.page,f.org_b,()=>other.page.goto(auditPath),()=>true,true);
      const ownIds=new Set(f.audit_reads.filter(r=>r.org===f.org).flatMap(r=>r.ids));assert(foreign.every(r=>!ownIds.has(r.id)));check('AUDIT_TENANT_ISOLATION',true);await assertRlsDenied(other.page,'AUDIT_OTHER_TENANT_REAL_RLS_DENIED');await other.context.close();
      check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);assert(!finalizeUnexpectedBrowserWorker(report));report.state='PASS_BATCH';report.completed_domains=['auditoria'];save();return;
    }
    const master=await open('master');master.page._crudRole='master';const mp=master.page;
    stage('ORG_CREATE_FORM');await mp.goto(base+'/selecionar-organizacao');await mp.getByRole('button',{name:'Nova organização',exact:true}).click();await mp.getByLabel('Razão social',{exact:true}).fill(f.prefix+'created');
    const org=await rpc(mp,'ORG_CREATE','criar_organizacao',()=>mp.getByRole('button',{name:'Criar organização',exact:true}).click());created('organization',typeof org.data==='string'?org.data:org.data?.id);
    let region=await manager(mp,'org');await editCadastro(mp,region,'org','Nome fantasia',f.prefix+'edited','ORG_EDIT');
    for(const state of ['inativa','ativa','suspensa']){region=await manager(mp,'org');await stateCadastro(mp,region,'org',state,'ORG_STATE_'+state.toUpperCase());}
    await chooseOrg(mp,f.org);
    const admin=await open('administrador');admin.page._crudRole='administrador';const ap=admin.page;await chooseOrg(ap,f.org);
    stage('CONTRACTOR_CREATE_FORM');await ap.goto(base+'/contratantes/novo');await ap.getByLabel(/^Razão social/).fill(f.prefix+'contractor-created');await ap.getByLabel(/^Tipo de pessoa/).selectOption('outro');
    const cr=await mutate(ap,'CONTRACTOR_CREATE','/rest/v1/contratantes',()=>ap.getByRole('button',{name:'Salvar',exact:true}).click());created('contractor',cr.data?.id||cr.data?.[0]?.id||cr.request?.id);
    await ap.goto(base+'/contratantes/'+f.created.contractor+'/editar');await ap.getByLabel(/^Nome fantasia/).fill(f.prefix+'contractor-edited');await rpc(ap,'CONTRACTOR_EDIT','atualizar_contratante',()=>ap.getByRole('button',{name:'Salvar',exact:true}).click());
    for(const state of ['inativo','ativo']){await ap.goto(base+'/contratantes/'+f.created.contractor+'/editar');await ap.getByLabel('Situação',{exact:true}).selectOption(state);await rpc(ap,'CONTRACTOR_STATE_'+state.toUpperCase(),'atualizar_contratante',()=>ap.getByRole('button',{name:'Salvar',exact:true}).click());}
    stage('CONTRACT_CREATE_FORM');await ap.goto(base+'/contratos/novo');await ap.getByLabel(/^Número/).fill('CRUDG-'+f.nonce+'-created');await ap.getByRole('combobox',{name:/Contratante/}).fill(f.prefix+'contractor-created');await ap.getByRole('option',{name:new RegExp(f.prefix+'contractor-created')}).click();await ap.getByLabel(/^Objeto/).fill('Own synthetic CRUD contract');await ap.getByLabel(/^Data de início/).fill('2026-01-01');
    await mutate(ap,'CONTRACT_CREATE','/rest/v1/contratos',()=>ap.getByRole('button',{name:'Salvar',exact:true}).click());await expect(ap.getByText('Contrato cadastrado com sucesso.',{exact:true})).toBeVisible();await ap.waitForURL('**/contratos');const contractLink=ap.getByRole('link',{name:'Abrir contrato CRUDG-'+f.nonce+'-created',exact:true}).first();await expect(contractLink).toBeVisible();const href=await contractLink.getAttribute('href');created('contract',href?.split('/').at(-1));
    await ap.goto(base+'/contratos/'+f.created.contract);region=await manager(ap,'contract');await editCadastro(ap,region,'contract','Objeto','Own synthetic edited contract','CONTRACT_EDIT');
    for(const state of ['ativo','suspenso','ativo','encerrado']){region=await manager(ap,'contract');await stateCadastro(ap,region,'contract',state,'CONTRACT_STATE_'+state.toUpperCase());}
    await admin.context.close();
    const lp=mp;stage('LIST_OPEN');await lp.goto(base+'/contratos/'+f.contract+'/regras');await lp.getByRole('button',{name:'Gerenciar listas',exact:true}).click();
    async function listOp(page,code,button,fill=async()=>{}){diagnosticPage=page;stage(code+'_OPEN');await page.getByRole('button',{name:button,exact:true}).click();stage(code+'_FILL');await fill();await page.getByLabel('Motivo',{exact:true}).fill('Own synthetic list operation');stage(code+'_REVIEW');await page.getByRole('button',{name:'Revisar operação',exact:true}).click();return rpc(page,code,'executar_comando_lista_v1',()=>page.getByRole('button',{name:'Confirmar operação',exact:true}).click());}
    const list=await listOp(lp,'LIST_CREATE','Criar lista',async()=>{await lp.getByLabel('Nome',{exact:true}).fill(f.prefix+'list');await lp.getByLabel('Início da vigência',{exact:true}).fill('2026-01-01');});created('list',list.data?.lista?.id);
    await listOp(lp,'LIST_EDIT','Editar lista',()=>lp.getByLabel('Descrição',{exact:true}).fill('Own initial list description'));
    await listOp(lp,'LIST_ITEM_CREATE','Adicionar item',async()=>{await lp.getByLabel('Código',{exact:true}).fill('OWN1');await lp.getByLabel('Descrição do item',{exact:true}).fill('Own optional item');await lp.getByLabel('Obrigatório',{exact:true}).uncheck();});
    await listOp(lp,'LIST_ITEM_EDIT','Editar item OWN1',()=>lp.getByLabel('Descrição do item',{exact:true}).fill('Own optional item edited'));
    await listOp(lp,'LIST_TEMP_ITEM_CREATE','Adicionar item',async()=>{await lp.getByLabel('Código',{exact:true}).fill('TMP');await lp.getByLabel('Descrição do item',{exact:true}).fill('Own draft item for legitimate removal');await lp.getByLabel('Obrigatório',{exact:true}).uncheck();});
    await listOp(lp,'LIST_ITEM_REMOVE','Remover item TMP');
    await listOp(lp,'LIST_DRAFT_DATES','Editar vigência',()=>lp.getByLabel('Início da vigência',{exact:true}).fill('2026-01-01'));
    await listOp(lp,'LIST_PUBLISH','Publicar versão');
    await listOp(lp,'LIST_END_VALIDITY','Encerrar vigência',()=>lp.getByLabel('Fim da vigência',{exact:true}).fill('2026-06-30'));
    await listOp(lp,'LIST_VERSION_CREATE','Criar versão',()=>fillNextVersionDates(lp,'2026-07-01'));
    await listOp(lp,'LIST_DRAFT_DISCARD','Descartar rascunho');
    await listOp(lp,'LIST_STATE_INACTIVE','Alterar situação',()=>selectListState(lp,'inativa'));
    await listOp(lp,'LIST_STATE_ACTIVE','Alterar situação',()=>selectListState(lp,'ativa'));
    // Two real pages produce a real CAS conflict; offline toggles transport, never API responses.
    stage('LIST_SECOND_PAGE_CREATE');const second=await master.context.newPage();diagnosticPage=second;second.setDefaultTimeout(30000);stage('LIST_SECOND_TAB_ORG');await chooseOrg(second,f.org);stage('LIST_SECOND_PAGE_NAVIGATE');await second.goto(base+'/contratos/'+f.contract+'/regras');stage('LIST_SECOND_MANAGER_OPEN');await second.getByRole('button',{name:'Gerenciar listas',exact:true}).click();stage('LIST_SECOND_MANAGER_VISIBLE');await expect(second.getByRole('region',{name:'Gestão de listas',exact:true})).toBeVisible();
    diagnosticPage=lp;stage('LIST_FIRST_EDIT_OPEN');await lp.getByRole('button',{name:'Editar lista',exact:true}).click();stage('LIST_FIRST_EDIT_FILL');await lp.getByLabel('Nome',{exact:true}).fill(f.prefix+'recovered');await lp.getByLabel('Motivo',{exact:true}).fill('Own conflict recovery draft');
    await listOp(second,'LIST_CONCURRENT_EDIT','Editar lista',()=>second.getByLabel('Descrição',{exact:true}).fill('Own concurrent real edit'));
    await lp.getByRole('button',{name:'Revisar operação',exact:true}).click();stage('LIST_REAL_CONFLICT');const conflict=lp.waitForResponse(r=>r.url().endsWith('/rpc/executar_comando_lista_v1')&&r.request().method()==='POST');await lp.getByRole('button',{name:'Confirmar operação',exact:true}).click();const conflictResponse=await conflict;check('LIST_REAL_CONFLICT',conflictResponse.status()===409,conflictResponse.status());
    // Browser transport fails for the real read URL while navigator remains online.
    // Context offline would pause React Query before any read, so it cannot prove read failure.
    stage('LIST_TRANSIENT_READ');let writesDuringFault=0;const countWrite=r=>{if(r.url().includes('/rpc/executar_comando_lista_v1')&&r.method()==='POST')writesDuringFault++;};lp.on('request',countWrite);
    await withReadTransportFailure(await master.context.newCDPSession(lp),async()=>{
      await lp.getByRole('button',{name:'Atualizar dados e revisar rascunho',exact:true}).click();
      await expect(lp.getByText(/Seu rascunho foi preservado/)).toBeVisible();await expect(lp.getByLabel('Nome',{exact:true})).toHaveValue(f.prefix+'recovered');await expect(lp.getByRole('button',{name:'Confirmar operação',exact:true})).toBeDisabled();
      check('LIST_TRANSIENT_DRAFT_PRESERVED',true);check('LIST_NO_WRITE_DURING_FAILED_READ',writesDuringFault===0);
    });lp.off('request',countWrite);
    await lp.getByRole('button',{name:'Tentar novamente',exact:true}).click();await expect(lp.getByRole('button',{name:'Confirmar operação',exact:true})).toBeEnabled();await lp.getByRole('button',{name:'Revisar campos',exact:true}).click();await lp.getByRole('button',{name:'Revisar operação',exact:true}).click();await rpc(lp,'LIST_RECOVERED_WRITE','executar_comando_lista_v1',()=>lp.getByRole('button',{name:'Confirmar operação',exact:true}).click());await second.close();
    stage('VISUAL_UI_SETTLED');await lp.waitForFunction(listUiIsSettled,f.prefix+'recovered');
    const panel=lp.getByRole('region',{name:'Gestão de listas',exact:true});
    await lp.addScriptTag({path:process.env.CONTAOS_AXE_SOURCE_PATH});
    async function waitStable(){
      await lp.waitForFunction(()=>document.getAnimations().every(a=>a.playState!=='running'||a.effect?.getTiming().iterations===Infinity),undefined,{timeout:5000});
      await lp.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    }
    for(const width of [1440,1280,768,390])for(const theme of ['light','dark']){
      const key=width+'_'+theme.toUpperCase();stage('VISUAL_'+key);await lp.setViewportSize({width,height:1000});await lp.emulateMedia({colorScheme:theme});await lp.evaluate(t=>document.documentElement.classList.toggle('dark',t==='dark'),theme);
      await lp.waitForFunction(listUiIsSettled,f.prefix+'recovered');await waitStable();
      await panel.getByRole('button',{name:'Editar lista',exact:true}).focus();check('FOCUS_EDIT_'+key,await panel.getByRole('button',{name:'Editar lista',exact:true}).evaluate(e=>e===document.activeElement));
      await lp.keyboard.press('Tab');check('KEYBOARD_NEXT_ACTION_'+key,await panel.getByRole('button',{name:'Criar versão',exact:true}).evaluate(e=>e===document.activeElement));
      await lp.evaluate(()=>window.scrollTo({top:0,left:0,behavior:'instant'}));await waitStable();
      const top='crud-list-'+width+'-'+theme+'-top.png',body='crud-list-'+width+'-'+theme+'-panel.png';
      await lp.screenshot({path:join(output,top),fullPage:false,animations:'disabled'});
      await panel.evaluate(e=>e.scrollIntoView({block:'start',behavior:'instant'}));await waitStable();
      const raw=await lp.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {testEngine:{version:r.testEngine.version},violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
      const a11y=summarizeAccessibility(raw),overflow=await lp.evaluate(()=>Math.max(0,document.documentElement.scrollWidth-innerWidth));
      await lp.screenshot({path:join(output,body),fullPage:false,animations:'disabled'});
      report.visual.push({width,height:1000,theme,stable:true,overflow,a11y,screenshots:{top,panel:body},scope:'Stable page and list panel; not a full manual WCAG certification'});save();
      check('OVERFLOW_'+key,overflow<=2);check('AUTOMATED_ACCESSIBILITY_'+key,a11y.violations.length===0);
    }

    await master.context.close();
    const reader=await open('leitor');reader.page._crudRole='leitor';await chooseOrg(reader.page,f.org);await reader.page.goto(base+'/contratos/'+f.contract+'/regras');await reader.page.getByRole('button',{name:'Gerenciar listas',exact:true}).click();await expect(reader.page.getByRole('button',{name:'Criar lista',exact:true})).toHaveCount(0);await expect(reader.page.getByRole('button',{name:'Editar lista',exact:true})).toHaveCount(0);check('READER_MUTATIONS_ABSENT',true);await reader.context.close();
    const other=await open('usuario_b');other.page._crudRole='usuario_b';await chooseOrg(other.page,f.org_b);await other.page.goto(base+'/contratos/'+f.contract+'/regras');await expect(other.page.getByRole('alert')).toContainText(/não.*acesso|não.*permissão|não encontrad|indisponível/i);await expect(other.page.getByText(f.prefix+'recovered',{exact:true})).toHaveCount(0);check('CROSS_TENANT_UI_DENIED',true);await other.context.close();
    check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);assert(!finalizeUnexpectedBrowserWorker(report));report.state='PASS_BATCH';report.completed_domains=['organizacoes','contratantes','contratos','listas'];save();
   }catch(e){
    if(diagnosticPage&&!probe&&f?.batch==='DOCUMENTOS'){try{
      const flags=await diagnosticPage.evaluate(()=>{
        const button=[...document.querySelectorAll('button')].find(e=>e.textContent.trim()==='Enviar documentos'),dialog=document.querySelector('[role="dialog"]');
        const alerts=[...document.querySelectorAll('[role="alert"]')].map(e=>e.textContent??''),text=dialog?.textContent??'';
        return {upload_button_present:!!button,upload_button_enabled:!!button&&!button.disabled,dialog_open:!!dialog,file_input_present:!!dialog?.querySelector('input[type="file"]'),queue_present:!!dialog?.querySelector('[aria-label="Fila de envio"]'),title_input_present:!!dialog&&[...dialog.querySelectorAll('label')].some(e=>e.textContent.trim().startsWith('Título de ')),form_alert:!!dialog?.querySelector('[role="alert"]'),format_rejected:alerts.some(t=>t.includes('Este formato de arquivo não é aceito pelo ContaOS.')||t.includes('A extensão e o tipo do arquivo não são compatíveis.')),config_unavailable:alerts.some(t=>t.includes('Não foi possível carregar as regras de envio de arquivos.')),upload_busy:!!dialog?.querySelector('[aria-busy="true"]'),upload_complete:text.includes('Concluído')};
      });
      report.document_diagnostic=sanitizeDocumentDiagnostic({...flags,...documentConfig,network:documentNetwork});
    }catch{report.document_diagnostic_unavailable=true;}}
    if(diagnosticPage&&!probe){try{
      const flags=await diagnosticPage.evaluate(()=>{
        const buttons=[...document.querySelectorAll('button')].map(e=>e.textContent.trim());
        const text=[...document.querySelectorAll('[role="alert"],[role="status"]')].map(e=>e.textContent);
        return {
          manage_list:buttons.includes('Gerenciar listas'),change_state:buttons.includes('Alterar situação'),
          loading:text.some(t=>t.includes('Carregando listas e permissões')),
          denied:text.some(t=>t.includes('Você não tem permissão para esta operação.')),
          inconsistent:text.some(t=>t.includes('O servidor retornou dados incompatíveis com o contexto.')),
          transient:text.some(t=>t.includes('Seu rascunho foi preservado')),
          pending:buttons.includes('Repetir exatamente o mesmo comando'),
        };
      });
      report.ui_diagnostic=sanitizeUiDiagnostic({...flags,read_http:readHttp});
    }catch{report.ui_diagnostic_unavailable=true;}}
    if(diagnosticPage?._publishedFenceSnapshot){const snapshot=diagnosticPage._publishedFenceSnapshot();if(snapshot)report.published_fence=snapshot;}report.state='FAIL';if(report.stage==='PUBLISHED_BACKEND_READONLY_FENCE')report.failure_code='PUBLICADA_BACKEND_NAO_COMPROVADO';if(typeof e.code==='string'&&/^(?:CDP_[A-Z0-9_]{1,80}|FENCE_[A-Z0-9_]{1,80}|ENOENT|DOCUMENT_VISUAL_AUDIT_FAILED)$/.test(e.code))report.failure_code=e.code;if(e.protocol_failure&&Number.isInteger(e.protocol_failure.code)&&['UNSUPPORTED','TARGET_CLOSED','OTHER_CDP_ERROR'].includes(e.protocol_failure.reason))report.protocol_failure=e.protocol_failure;report.failure_class=['Error','AssertionError','TimeoutError','TypeError'].includes(e.name)?e.name:'Other';save();process.exitCode=1;}
  finally{let closed=false,drained=false;try{await stop(server,browser);closed=Boolean(browser);}finally{try{if(nativeDeny){await nativeDeny.close();drained=true;}}finally{for(const finalize of publishedFinalizers){if(finalize()){finalizePublishedFence(report,{failed:true});process.exitCode=1;}}if(finalizeUnexpectedBrowserWorker(report))process.exitCode=1;if(closed&&drained)report.browser_finalization='CLOSED_AND_DRAINED';save();}}}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)await main();
