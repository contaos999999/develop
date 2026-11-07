// HML real; no request mocks, traces, HAR or storageState artifacts.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {spawn} from 'node:child_process';

export function publicProbeError(error) {
  return {
    name:['Error','TypeError','SyntaxError','ReferenceError','EvalError','TimeoutError'].includes(error?.name)?error.name:'Other',
    message:String(error?.message||'').split('\n')[0].replace(/https?:\/\/\S+/g,'[url]').replace(/[\w.+-]+@[\w.-]+/g,'[email]').replace(/\/(?:home|workspace|tmp)\/[^\s]*/g,'[path]').replace(/[A-Za-z0-9_-]{32,}/g,'[redacted]').slice(0,300),
  };
}
export function browserEnvironment(source) {
  const allowed=['PATH','HOME','RUNNER_TEMP','TMPDIR','LANG','TZ','CI','XDG_CACHE_HOME','CONTAOS_TEST_PRIVATE_DIR','CONTAOS_FRONTEND_DIR','CONTAOS_AXE_SOURCE_PATH','CONTAOS_PLAYWRIGHT_MODULE','TESTED_HEAD','FRONTEND_HEAD'];
  return Object.fromEntries(allowed.filter(k=>source[k]!==undefined).map(k=>[k,source[k]]));
}
export async function finishRunner(save,browser,server) {
  let timer;
  try {save();} finally {
    try {
      if(browser) await Promise.race([browser.close(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Browser shutdown timeout')),2000);})]);
    } finally {clearTimeout(timer);await stopServer(server);}
  }
}
export async function stopServer(server) {
  if (!server?.pid) return;
  try {process.kill(-server.pid,'SIGTERM');} catch(e) {if(e.code!=='ESRCH') throw e;}
  await Promise.race([new Promise(r=>server.once('exit',r)),new Promise(r=>setTimeout(r,1500))]);
  try {process.kill(-server.pid,'SIGKILL');} catch(e) {if(e.code!=='ESRCH') throw e;}
  if(server.exitCode===null && server.signalCode===null) await Promise.race([new Promise(r=>server.once('exit',r)),new Promise((_,reject)=>setTimeout(()=>reject(Error('Server shutdown timeout')),1500))]);
}
export function publicRecord({name,pass,http}) {
  assert(/^[A-Za-z0-9 _:-]{1,100}$/.test(name));
  assert(typeof pass==='boolean');
  assert(http===undefined || Number.isInteger(http) && http>=100 && http<=599);
  return {name,pass,...(http===undefined?{}:{http})};
}
export function a11yNodeMetrics(node) {
  const own=(o,k)=>o && typeof o==='object'?Object.getOwnPropertyDescriptor(o,k)?.value:undefined;
  const tag=own(node,'tag');
  const out={tag:typeof tag==='string'&&/^(DT|DD|P|SPAN|DIV|LABEL|BUTTON|A|INPUT|TEXTAREA|SELECT|OPTION|H[1-6]|LI|TD|TH)$/.test(tag)?tag:null,inside_dialog:own(node,'inside_dialog')===true};
  const d=own(node,'data');
  for(const [key,source] of [['foreground','fgColor'],['background','bgColor']]) {const v=own(d,source);if(typeof v==='string'&&/^#[0-9a-f]{3,8}$/i.test(v))out[key]=v;}
  const ratio=own(d,'contrastRatio');if(typeof ratio==='number'&&Number.isFinite(ratio)&&ratio>=0&&ratio<=21)out.contrast=ratio;
  const required=own(d,'expectedContrastRatio');if(typeof required==='string'&&/^(3|4\.5|7):1$/.test(required))out.required=required;
  const size=own(d,'fontSize');if(typeof size==='string'&&/^\d+(?:\.\d+)?pt \(\d+(?:\.\d+)?px\)$/.test(size))out.font_size=size;
  const weight=own(d,'fontWeight');if(typeof weight==='string'&&/^(normal|bold|[1-9]00)$/.test(weight))out.font_weight=weight;
  return out;
}
if(process.argv.includes('--self-test')) {
  const metricInput={tag:'DT',inside_dialog:true,data:{fgColor:'#94a3b8',bgColor:'#020617',contrastRatio:7.8,expectedContrastRatio:'4.5:1',fontSize:'10.5pt (14px)',fontWeight:'normal',message:'PRIVATE_CANARY',html:'PRIVATE_CANARY'}};
  const metric=a11yNodeMetrics(metricInput);
  assert.deepEqual(metric,{tag:'DT',inside_dialog:true,foreground:'#94a3b8',background:'#020617',contrast:7.8,required:'4.5:1',font_size:'10.5pt (14px)',font_weight:'normal'});
  assert(!JSON.stringify(metric).includes('PRIVATE_CANARY'));
  // Preserve the failing HML ratio too: diagnostics must never discard low contrast.
  assert.equal(a11yNodeMetrics({...metricInput,data:{...metricInput.data,contrastRatio:2.1}}).contrast,2.1);
  const hostile={};Object.defineProperty(hostile,'data',{get(){throw Error('private getter');}});
  assert.deepEqual(a11yNodeMetrics(hostile),{tag:null,inside_dialog:false});
  assert.deepEqual(a11yNodeMetrics({tag:'PRIVATE_CANARY',data:{fgColor:'PRIVATE_CANARY',contrastRatio:Infinity}}),{tag:null,inside_dialog:false});

  assert(!JSON.stringify(publicProbeError({name:'Error',message:'https://host.invalid/token?secret='+ 's'.repeat(40)+' own@example.invalid /home/runner/private'})).includes('private'));
  assert.deepEqual(browserEnvironment({PATH:'/bin',AUTH_ADMIN_KEY:'private',UNEXPECTED_SECRET:'private'}),{PATH:'/bin'});
  assert.deepEqual(publicRecord({name:'Review persisted',pass:true,password:'private',access_token:'private'}),{name:'Review persisted',pass:true});
  assert.throws(()=>publicRecord({name:'token@example.invalid',pass:true}));
  assert.throws(()=>publicRecord({name:'Review',pass:'yes'}));
  const child=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{detached:true,stdio:'ignore'});
  await new Promise(r=>child.once('spawn',r));
  await stopServer(child);
  assert.throws(()=>process.kill(child.pid,0),e=>e.code==='ESRCH');
  const group=spawn(process.execPath,['-e',`const {spawn}=require('node:child_process');const grandchild=spawn(process.execPath,['-e','process.on("SIGTERM",()=>{});console.log("READY");setInterval(()=>{},1000)'],{stdio:['ignore','pipe','ignore']});grandchild.stdout.once('data',()=>console.log(grandchild.pid));process.on('SIGTERM',()=>{});setInterval(()=>{},1000);`],{detached:true,stdio:['ignore','pipe','ignore']});
  const grandchild=Number(await new Promise(r=>group.stdout.once('data',b=>r(b.toString().trim()))));
  try {
    await assert.rejects(()=>finishRunner(()=>{}, {close:async()=>{throw Error('SIMULATED_CLOSE_FAILURE');}},group),/SIMULATED_CLOSE_FAILURE/);
    assert(group.exitCode!==null || group.signalCode!==null,'close rejection cannot skip process cleanup');
    try {assert.equal(readFileSync('/proc/'+grandchild+'/stat','utf8').split(' ')[2],'Z','grandchild must not remain alive');} catch(e) {if(e.code!=='ENOENT')throw e;}
  } finally {await stopServer(group);}
  console.log('V117_BROWSER_PROTOCOL_SELF_TEST_PASS');
} else {
  assert(!process.env.AUTH_ADMIN_KEY && !process.env.DATABASE_URL && !process.env.GH_TOKEN);
  const root=resolve(process.env.CONTAOS_TEST_PRIVATE_DIR||'');
  assert(root.startsWith(process.env.RUNNER_TEMP+'/'));
  const frontend=resolve(process.env.CONTAOS_FRONTEND_DIR||'');
  const req=createRequire(process.env.CONTAOS_PLAYWRIGHT_MODULE);
  const engineVersion=req('playwright/package.json').version;
  assert.equal(engineVersion,'1.64.1');
  const {chromium,expect}=req('playwright/test');
  const probe=process.argv.includes('--public-probe');
  mkdirSync(root,{recursive:true,mode:0o700});
  const f=probe?null:JSON.parse(readFileSync(join(root,'fixture.json'),'utf8'));
  const admin=f?.users.find(u=>u.profile==='administrador');
  assert(probe||admin?.creation_state==='created');
  const output=join(root,'public-browser');mkdirSync(output,{recursive:true,mode:0o700});
  const report={schema:'contaos.v117.private-browser.v1',backend_head:process.env.TESTED_HEAD,frontend_head:process.env.FRONTEND_HEAD,state:'RUNNING',browser_engine_version:engineVersion,mode:probe?'PUBLIC_INTERACTIVITY_PROBE':'PRIVATE_ACCEPTANCE',stage:'START',runtime_errors:[],assertions:[],visual:[],limits:['Synthetic document metadata, no physical upload or worker proof','Automated accessibility is not a full manual WCAG certification']};
  function save(){writeFileSync(join(output,probe?'public-probe.json':'report.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});}
  function check(name,pass,http){report.assertions.push(publicRecord({name,pass,http}));save();assert(pass,name);}
  const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','4173'],{cwd:frontend,detached:true,stdio:'ignore',env:browserEnvironment(process.env)});
  let browser,page;
  function stage(value){report.stage=value;save();}
  try {
    stage('SERVER_READY_WAIT');
    for(let i=0;i<120;i++){try{if((await fetch('http://127.0.0.1:4173/login')).ok)break;}catch{} if(i===119)throw Error('Frontend unavailable');await new Promise(r=>setTimeout(r,1000));}
    stage('CHROMIUM_LAUNCH');
    browser=await chromium.launch({headless:true,env:browserEnvironment(process.env)});
    const context=await browser.newContext({viewport:{width:1440,height:1000},colorScheme:'light'});
    // Login uses the product form and GoTrue, never a forged JWT or admin token.
    page=await context.newPage();page.setDefaultTimeout(30000);
    page.on('pageerror',error=>{const msg=String(error.message);report.runtime_errors.push({name:['Error','TypeError','SyntaxError','ReferenceError'].includes(error.name)?error.name:'Other',flags:['Hydration','Failed to fetch','does not provide an export','Cannot read properties','Unexpected'].filter(x=>msg.includes(x)),export_identifier:/does not provide an export named ['"]([A-Za-z_]\w{0,60})['"]/.exec(msg)?.[1]||null});save();});
    stage('LOGIN_NAVIGATE');
    await page.goto('http://127.0.0.1:4173/login');
    stage('CLIENT_INTERACTIVITY');
    report.initial_form_bound=await page.locator('form').evaluate(e=>Object.keys(e).some(k=>k.startsWith('__reactProps$')));
    save();
    await page.waitForFunction(()=>{const e=document.querySelector('form');return e&&Object.keys(e).some(k=>k.startsWith('__reactProps$'));});
    if(probe) {
      await page.getByRole('button',{name:'Mostrar senha',exact:true}).click();
      await expect(page.getByLabel('Senha',{exact:true})).toHaveAttribute('type','text');
      await page.getByRole('button',{name:'Ocultar senha',exact:true}).click();
      await expect(page.getByLabel('Senha',{exact:true})).toHaveAttribute('type','password');
      check('Public login interaction without credentials',true);
      report.state='PASS';
    } else {
    stage('LOGIN_EMAIL');
    await page.getByLabel('E-mail',{exact:true}).fill(admin.email);
    stage('LOGIN_PASSWORD');
    await page.getByLabel('Senha',{exact:true}).fill(admin.password);
    stage('LOGIN_SUBMIT');
    const login=page.waitForResponse(r=>r.url().includes('/auth/v1/token?')&&r.request().method()==='POST');
    await page.getByRole('button',{name:'Entrar',exact:true}).click();
    check('Browser GoTrue login',(await login).status()===200,200);
    stage('LOGIN_REDIRECT');
    await page.waitForURL(u=>!u.pathname.includes('/login'));
    await page.evaluate(({user,org})=>sessionStorage.setItem('contaos.preferenciaOrganizacao',JSON.stringify({idUsuario:user,idOrganizacao:org})),{user:admin.id,org:f.org});
    const route='http://127.0.0.1:4173/competencias/'+f.competence+'/analise';
    stage('ANALYSIS_NAVIGATE');
    await page.goto(route);
    const open=page.getByRole('button',{name:'Abrir requisito '+f.requirement,exact:true});
    stage('OPEN_REQUIREMENT');
    const detailResponse=page.waitForResponse(r=>r.url().endsWith('/rpc/obter_detalhe_requisito_v117')&&r.request().method()==='POST');
    await open.click();
    const detail=await detailResponse;check('Authorized detail HTTP',detail.status()===200,detail.status());
    const detailData=await detail.json();report.detail_field_types=Object.fromEntries(['fonte_detalhe','regra_validacao','condicao_aplicabilidade','efeito_portao'].map(k=>[k,typeof detailData.requisito?.[k]]));save();
    await expect(page.getByRole('heading',{name:'Detalhe do requisito',exact:true})).toBeVisible();
    stage('OPEN_REVIEW');
    await page.getByRole('button',{name:'Revisar resultado',exact:true}).click();
    await expect(page.getByLabel('Justificativa da revisão')).toBeVisible();
    check('Private drawer and review editor',true);
    stage('APPROVED_EVIDENCE');
    const choice=page.getByRole('checkbox',{name:'Selecionar evidence.pdf versão 1',exact:true});
    await expect(choice).toBeVisible();check('RLS approved evidence query',true);
    stage('CROSS_TENANT_DENIAL');
    const denied=f.users.find(u=>u.profile==='usuario_b');
    const other=await browser.newContext({viewport:{width:1280,height:900}});
    const otherPage=await other.newPage();otherPage.setDefaultTimeout(30000);
    stage('CROSS_TENANT_LOGIN_NAVIGATE');
    await otherPage.goto('http://127.0.0.1:4173/login');
    report.denied_login_form_bound=await otherPage.locator('form').evaluate(e=>Object.keys(e).some(k=>k.startsWith('__reactProps$')));save();
    otherPage.on('response',r=>{if(r.url().includes('/auth/v1/token?')&&r.request().method()==='POST'){report.denied_login_http=r.status();save();}});
    stage('CROSS_TENANT_LOGIN_EMAIL');
    await otherPage.getByLabel('E-mail',{exact:true}).fill(denied.email);
    stage('CROSS_TENANT_LOGIN_PASSWORD');
    await otherPage.getByLabel('Senha',{exact:true}).fill(denied.password);
    stage('CROSS_TENANT_LOGIN_SUBMIT');
    await otherPage.getByRole('button',{name:'Entrar',exact:true}).click();
    stage('CROSS_TENANT_LOGIN_REDIRECT');
    await otherPage.waitForURL(u=>!u.pathname.includes('/login'));
    await otherPage.evaluate(({user,org})=>sessionStorage.setItem('contaos.preferenciaOrganizacao',JSON.stringify({idUsuario:user,idOrganizacao:org})),{user:denied.id,org:f.org_b});
    stage('CROSS_TENANT_ANALYSIS_NAVIGATE');
    await otherPage.goto(route);
    stage('CROSS_TENANT_DENIAL_VISIBLE');
    await expect(otherPage.getByText('Você não tem acesso a esta competência.',{exact:true})).toBeVisible();
    check('Cross tenant UI denies private competence',true);
    check('Denied tenant has no review button',await otherPage.getByRole('button',{name:'Revisar resultado',exact:true}).count()===0);
    await other.close();
    stage('VISUAL_AUDIT');
    for(const width of [1440,1280,768,390])for(const theme of ['light','dark']){
      await page.setViewportSize({width,height:1000});
      await page.emulateMedia({colorScheme:theme});
      await page.evaluate(t=>document.documentElement.classList.toggle('dark',t==='dark'),theme);
      await page.getByLabel('Justificativa da revisão').focus();
      check('Focus editor '+width+' '+theme,await page.getByLabel('Justificativa da revisão').evaluate(e=>e===document.activeElement));
      await page.keyboard.press('Tab');
      check('Keyboard editor '+width+' '+theme,await page.getByLabel('Fundamento da revisão').evaluate(e=>e===document.activeElement));
      const overflow=await page.evaluate(()=>Math.max(0,document.documentElement.scrollWidth-innerWidth));
      await page.addScriptTag({path:process.env.CONTAOS_AXE_SOURCE_PATH});
      const a11y=await page.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {version:r.testEngine.version,violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length,metrics:v.id==='color-contrast'?v.nodes.map(n=>{const selector=n.target?.[0];const el=typeof selector==='string'?document.querySelector(selector):null;return {tag:el?.tagName,inside_dialog:!!el?.closest('[role=dialog]'),data:n.any.find(c=>c.id==='color-contrast')?.data};}):[]})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
      for(const violation of a11y.violations) violation.metrics=violation.metrics.map(a11yNodeMetrics);
      const prefix='v117-'+width+'-'+theme;
      const screenshots={review:prefix+'-review.png',top:prefix+'-top.png',actions:prefix+'-actions.png'};
      await page.screenshot({path:join(output,screenshots.review),fullPage:false,animations:'disabled'});
      await page.getByRole('dialog').evaluate(e=>{e.scrollTop=0;});
      await page.screenshot({path:join(output,screenshots.top),fullPage:false,animations:'disabled'});
      await page.getByRole('button',{name:'Revisar e confirmar',exact:true}).scrollIntoViewIfNeeded();
      await page.screenshot({path:join(output,screenshots.actions),fullPage:false,animations:'disabled'});
      report.visual.push({width,height:1000,theme,overflow,a11y,screenshots,capture_mode:'VIEWPORT_FIXED_DRAWER'});save();
      check('No horizontal overflow '+width+' '+theme,overflow<=2);
      check('Automated accessibility '+width+' '+theme,a11y.violations.length===0);
    }
    stage('REVIEW_WRITE');
    await page.setViewportSize({width:1440,height:1000});
    await page.getByLabel('Resultado da revisão').selectOption('conforme');
    await page.getByLabel('Justificativa da revisão').fill('Synthetic UI review '+f.scope);
    await page.getByLabel('Fundamento da revisão').fill('Controlled synthetic evidence metadata');
    await choice.check();
    await page.getByRole('button',{name:'Revisar e confirmar',exact:true}).click();
    const received=page.waitForResponse(r=>r.url().endsWith('/rpc/registrar_revisao_requisito_v117')&&r.request().method()==='POST');
    const refreshed=page.waitForResponse(r=>r.url().endsWith('/rpc/obter_detalhe_requisito_v117')&&r.request().method()==='POST');
    await page.getByRole('button',{name:'Confirmar revisão',exact:true}).click();
    const response=await received;check('Review browser RPC success',response.status()===200,response.status());
    const receipt=await response.json();assert(receipt.schema_versao==='revisao-v117'&&receipt.id_competencia===f.competence&&receipt.id_requisito===f.requirement);
    writeFileSync(join(root,'browser-receipt.json'),JSON.stringify(receipt),{mode:0o600});
    check('Drawer refresh after protected receipt',(await refreshed).status()===200);
    await expect(page.getByText('Justificativa: Synthetic UI review '+f.scope,{exact:true}).first()).toBeVisible();
    check('UI displays persisted justification',true);
    await context.close();report.state='PASS';
    }
  }catch(error){
    report.state='FAIL';
    if(probe) report.public_error=publicProbeError(error);
    report.failure_flags=['Timeout','locator.fill','locator.click','waitForResponse','strict mode violation','ERR_CONNECTION','browserType.launch'].filter(x=>String(error?.message||'').includes(x));
    if(page && !page.isClosed()) {
      try {
        await page.locator('input').evaluateAll(es=>es.forEach(e=>e.value=''));
        report.failure_surface=await page.evaluate(()=>({path:location.pathname.split('/').map(x=>/^[a-z-]+$/.test(x)?x:'[id]').join('/'),headings:[...document.querySelectorAll('h1,h2')].map(e=>e.textContent).filter(x=>['Acesso ao ContaOS','Entrar no ContaOS','ContaOS','Entrar'].includes(x)),email_field:!!document.querySelector('#login-email'),password_field:!!document.querySelector('#login-senha')}));
        await page.screenshot({path:join(output,'failure-cleared-inputs.png'),fullPage:false});
      }catch{}
    }
    throw Error('Private browser acceptance failed; sanitized report contains the completed checks');}
  finally{await finishRunner(save,browser,server);}
}
