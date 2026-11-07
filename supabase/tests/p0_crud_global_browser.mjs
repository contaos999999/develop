import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync,renameSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
export function documentCoverage(){return {completed_scopes:['DOCUMENTOS_TXT_PDF_UPLOAD_VERSION_DOWNLOAD_WORKER'],remaining_domains:['documentos_contrato','documento_detalhe'],global_complete:false};}
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
  const report={schema:'contaos.crud-global.browser.v1',backend_head:process.env.TESTED_HEAD,frontend_head:process.env.FRONTEND_HEAD,batch:probe?'PUBLIC_PROBE':f.batch||'CADASTROS_LISTAS',global_complete:false,state:'RUNNING',stage:'START',visual:[],assertions:[],runtime_errors:[],limits:['Partial batch; remaining matrix domains are not certified','No physical upload or worker proof in this batch','Automated tests do not certify full manual WCAG','Stable-state contrast does not close historical transient V117 contrast']};
  const save=()=>writeFileSync(join(output,probe?'public-probe.json':'report.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});
  function stage(s){assert(/^[A-Z0-9_]{1,100}$/.test(s));report.stage=s;save();}
  function check(name,pass,http){report.assertions.push(publicRecord({name,pass,http}));save();assert(pass,name);}
  function created(name,id){assert(['organization','contractor','contract','list'].includes(name)&&/^[a-f0-9-]{36}$/.test(id));f.created[name]=id;writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});}
  const base='http://127.0.0.1:4173';const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','4173'],{cwd:frontend,detached:true,stdio:'ignore',env:browserEnvironment(process.env)});let browser;let diagnosticPage;let readHttp=null;
  try{
    stage('SERVER_READY');for(let i=0;i<120;i++){try{if((await fetch(base+'/login')).ok)break;}catch{}if(i===119)throw Error('Frontend unavailable');await new Promise(r=>setTimeout(r,1000));}
    browser=await chromium.launch({headless:true,env:browserEnvironment(process.env)});
    async function open(role){
      const context=await browser.newContext({viewport:{width:1440,height:1000},colorScheme:'light',locale:'pt-BR'});const page=await context.newPage();page.setDefaultTimeout(30000);diagnosticPage=page;
      page.on('response',r=>{if(r.url().endsWith('/rpc/obter_lista_operacional_v1')&&r.request().method()==='POST')readHttp=r.status();});
      page.on('pageerror',e=>{report.runtime_errors.push({name:['Error','TypeError','SyntaxError','ReferenceError'].includes(e.name)?e.name:'Other'});save();});
      stage('LOGIN_'+role.toUpperCase());await page.goto(base+'/login');await page.waitForFunction(loginFormIsInteractive);
      if(probe){await page.getByRole('button',{name:'Mostrar senha',exact:true}).click();await expect(page.getByLabel('Senha',{exact:true})).toHaveAttribute('type','text');check('PUBLIC_INTERACTIVITY',true);return{context,page};}
      const u=f.users.find(x=>x.profile===role);assert(u?.id&&u.creation_state==='created');await page.getByLabel('E-mail',{exact:true}).fill(u.email);await page.getByLabel('Senha',{exact:true}).fill(u.password);
      const received=page.waitForResponse(r=>r.url().includes('/auth/v1/token?')&&r.request().method()==='POST');await page.getByRole('button',{name:'Entrar',exact:true}).click();const login=await received;check('LOGIN_'+role.toUpperCase(),login.status()===200,login.status());await page.waitForURL(u=>!u.pathname.includes('/login'));return{context,page};
    }
    async function chooseOrg(page,id){
      await page.goto(base+'/selecionar-organizacao');
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
      const x=await open('master');const sample=await x.context.newPage();
      await sample.setContent('<select aria-label="Filtro externo"><option value="ativa">Ativa</option><option value="inativa">Inativa</option></select><form><h3>Alterar situação</h3><label><span>Situação</span><select><option value="ativa">Ativa</option><option value="inativa">Inativa</option></select></label></form>');
      check('WRAPPED_SELECT_EXACT_LABEL_MISMATCH',await sample.getByLabel('Situação',{exact:true}).count()===0);
      await selectListState(sample,'inativa');await expect(sample.locator('form').getByRole('combobox')).toHaveValue('inativa');
      await expect(sample.getByRole('combobox',{name:'Filtro externo',exact:true})).toHaveValue('ativa');check('LIST_STATE_SCOPED_INACTIVE',true);
      await selectListState(sample,'ativa');await expect(sample.locator('form').getByRole('combobox')).toHaveValue('ativa');check('LIST_STATE_SCOPED_ACTIVE',true);
      await x.page.evaluate(()=>sessionStorage.setItem('contaos.public-probe-tab-context','synthetic-own-context'));
      const fresh=await x.context.newPage();await fresh.goto(base+'/login');
      check('NEW_TAB_HAS_SEPARATE_SESSION_STORAGE',await fresh.evaluate(()=>sessionStorage.getItem('contaos.public-probe-tab-context'))===null);
      await sample.setContent('<section aria-label="Gestão de listas"><p>Old list</p><p role="status">Enviando operação…</p><button disabled>Editar lista</button></section>');
      check('VISUAL_REJECTS_BUSY_PANEL',!await sample.evaluate(listUiIsSettled,'Own recovered'));
      const settled=sample.waitForFunction(listUiIsSettled,'Own recovered');
      await sample.evaluate(()=>{setTimeout(()=>{const p=document.querySelector('section');p.innerHTML='<p>Own recovered</p><button>Editar lista</button>';},50);});
      await settled;check('VISUAL_WAITS_FOR_RECOVERED_ENABLED_PANEL',await sample.evaluate(listUiIsSettled,'Own recovered'));
      await x.context.close();report.state='PASS_PUBLIC_PROBE';save();return;
    }
    if(f.batch==='DOCUMENTOS'){
      const admin=await open('administrador');const ap=admin.page;await chooseOrg(ap,f.org);
      const docsPath=base+'/contratos/'+f.contract+'/documentos';await ap.goto(docsPath);
      await expect(ap.getByRole('heading',{name:'Central de documentos',exact:true})).toBeVisible();
      const persist=()=>writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});
      const batchDeadline=Date.now()+900000;f.uploads??=[];
      async function upload(format,version,document){
        stage('DOCUMENT_UPLOAD_'+format.toUpperCase()+'_V'+version);
        const file=documentFixture(f.nonce,format,version),title=f.prefix+format;
        const intent={intent_nonce:f.nonce+'-'+format+'-'+version,org:f.org,contract:f.contract,name:file.name,mime:file.mime,sha256:file.sha256,size:file.size,version,title,state:'INTENT',...(document?{document}:{} )};
        f.uploads.push(intent);persist(); // durable before opening the form or making any upload request
        await ap.getByRole('button',{name:version===1?'Enviar documentos':'Nova versão de '+title,exact:true}).click();
        const dialog=ap.getByRole('dialog');await dialog.getByLabel(version===1?'Arquivos':'Arquivo',{exact:true}).setInputFiles({name:file.name,mimeType:file.mime,buffer:file.bytes});
        if(version===1){await dialog.getByLabel('Título de '+file.name,{exact:true}).fill(title);await dialog.getByLabel('Categoria',{exact:true}).fill('synthetic-'+f.nonce);await dialog.getByLabel('Início da vigência',{exact:true}).fill('2026-01-01');}
        else await dialog.getByLabel('Motivo da nova versão',{exact:true}).fill('Own synthetic replacement '+f.nonce);
        const waits=['/functions/v1/storage-sign-upload','/storage/v1/object/upload/sign/','/rpc/confirmar_upload_arquivo','/rpc/'+(version===1?'criar_documento_contrato_completo':'adicionar_versao_documento_contrato')].map(part=>ap.waitForResponse(r=>r.url().includes(part)&&['POST','PUT'].includes(r.request().method()),{timeout:60000}));
        // Observers settle together so a failed stage never leaves an unhandled waiter.
        const receive=Promise.all(waits);receive.catch(()=>{});
        await dialog.getByRole('button',{name:version===1?'Enviar e registrar':'Enviar nova versão',exact:true}).click();
        const responses=await receive;
        for(const [i,response] of responses.entries())check('DOCUMENT_TRANSFER_STAGE_'+i,response.ok(),response.status());
        const authorization=await responses[0].json();assert(authorization.ok&&authorization.bucket==='contaos-documentos'&&authorization.path.startsWith(f.org+'/uploads/')&&authorization.path.endsWith('/'+file.name));
        intent.path=authorization.path;intent.state='UPLOADED';persist();
        const request=responses[2].request().postDataJSON();assert.equal(request.p_nome_original,file.name);assert.equal(request.p_mime,file.mime);assert.equal(request.p_sha256,file.sha256);assert.equal(request.p_tamanho,file.size);assert.equal(request.p_path,intent.path);assert.equal(request.p_id_organizacao,f.org);assert.equal(request.p_id_contrato,f.contract);
        intent.file=await responses[2].json();intent.state='CONFIRMED';persist();
        const receipt=await responses[3].json();validateDocumentReceipt(receipt,intent);intent.document=receipt.id_documento;intent.id_version=receipt.id_versao;intent.state='REGISTERED';persist();
        await expect(dialog.getByRole('button',{name:'Fechar',exact:true})).toBeEnabled();await dialog.getByRole('button',{name:'Fechar',exact:true}).click();
        const deadline=Math.min(batchDeadline,Date.now()+300000);let ready=false;
        while(Date.now()<deadline){
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
        await ap.getByRole('button',{name:'Atualizar lista',exact:true}).click();
        const downloadResponse=ap.waitForResponse(r=>r.url().endsWith('/functions/v1/storage-sign-download')&&r.request().method()==='POST');
        const popup=admin.context.waitForEvent('page',{timeout:10000}).catch(()=>null);
        await ap.getByRole('button',{name:'Baixar '+file.name,exact:true}).click();const signed=await downloadResponse;check('DOCUMENT_OFFICIAL_DOWNLOAD',signed.ok(),signed.status());
        assert.equal(signed.request().postDataJSON().id_arquivo,intent.file);const signedData=await signed.json();assert.equal(signedData.ok,true);const url=new URL(signedData.signed_url);assert.equal(url.origin,'https://gklhhhyosgasnyoxlrui.supabase.co');assert.equal(url.pathname,'/storage/v1/object/sign/contaos-documentos/'+intent.path);
        const downloaded=await admin.context.request.get(url.href);const bytes=await downloaded.body();check('DOCUMENT_PHYSICAL_HASH_AND_SIZE',downloaded.ok()&&bytes.length===file.size&&createHash('sha256').update(bytes).digest('hex')===file.sha256,downloaded.status());
        const opened=await popup;if(opened)await opened.close();intent.download_verified=true;persist();return intent.document;
      }
      for(const format of ['txt','pdf']){const document=await upload(format,1);await upload(format,2,document);}
      await ap.reload();await expect(ap.getByRole('list',{name:'Documentos',exact:true}).locator(':scope > li')).toHaveCount(2);
      await ap.addScriptTag({path:process.env.CONTAOS_AXE_SOURCE_PATH});
      for(const theme of ['light','dark'])for(const width of [1440,1280,768,390]){
        stage('DOCUMENT_VISUAL_'+width+'_'+theme.toUpperCase());await ap.setViewportSize({width,height:1000});await ap.evaluate(t=>{document.documentElement.classList.toggle('dark',t==='dark');document.documentElement.style.colorScheme=t;},theme);
        await ap.getByRole('button',{name:'Atualizar lista',exact:true}).focus();await expect(ap.getByRole('button',{name:'Atualizar lista',exact:true})).toBeFocused();await ap.keyboard.press('Tab');
        check('DOCUMENT_NO_PAGE_OVERFLOW_'+width+'_'+theme.toUpperCase(),await ap.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
        const raw=await ap.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {testEngine:{version:r.testEngine.version},violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
        const a11y=summarizeAccessibility(raw),name='crud-documents-'+width+'-'+theme+'.png';await ap.screenshot({path:join(output,name),animations:'disabled',fullPage:true});report.visual.push({width,theme,a11y,screenshot:name});save();check('DOCUMENT_ACCESSIBILITY_'+width+'_'+theme.toUpperCase(),a11y.violations.length===0);
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
      },{document:f.uploads[0].document,file:f.uploads[0].file,contract:f.contract,user:ownAdmin.id});
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
          },{org:f.org,contract:f.contract,file:f.uploads[0].file,document:f.uploads[0].document,other:role==='usuario_b'});
          validateDocumentDenial(result.upload,'upload');validateDocumentDenial(result.mutation,'mutation');check('DOCUMENT_'+role.toUpperCase()+'_VERSION_DENIED',true,result.mutation.status);check('DOCUMENT_'+role.toUpperCase()+'_UPLOAD_DENIED',true,result.upload.status);
          if(role==='usuario_b'){validateAuditDenied(result.read);validateDocumentDenial(result.download,'download');check('DOCUMENT_OTHER_TENANT_READ_DOWNLOAD_DENIED',true,result.download.status);}
          else {assert([200,206].includes(result.read.status)&&result.read.count===2);check('DOCUMENT_READER_READ_ALLOWED',true,result.read.status);}
        }
        await user.context.close();
      }
      report.limits=report.limits.filter(x=>x!=='No physical upload or worker proof in this batch');report.limits.push('TXT/PDF only; other formats, multipart, AI extraction and full manual WCAG remain unverified');check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);report.state='PASS_BATCH';Object.assign(report,documentCoverage());report.completed_domains=[];save();return;
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
      check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);report.state='PASS_BATCH';report.completed_domains=['auditoria'];save();return;
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
    check('NO_RUNTIME_ERRORS',report.runtime_errors.length===0);report.state='PASS_BATCH';report.completed_domains=['organizacoes','contratantes','contratos','listas'];save();
   }catch(e){
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
    report.state='FAIL';report.failure_class=['Error','AssertionError','TimeoutError','TypeError'].includes(e.name)?e.name:'Other';save();process.exitCode=1;}
  finally{save();await stop(server,browser);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href)await main();
