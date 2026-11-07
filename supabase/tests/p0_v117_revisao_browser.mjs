// HML real; no request mocks, traces, HAR or storageState artifacts.
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {spawn} from 'node:child_process';

export function publicRecord({name,pass,http}) {
  assert(/^[A-Za-z0-9 _:-]{1,100}$/.test(name));
  assert(typeof pass==='boolean');
  assert(http===undefined || Number.isInteger(http) && http>=100 && http<=599);
  return {name,pass,...(http===undefined?{}:{http})};
}
if(process.argv.includes('--self-test')) {
  assert.deepEqual(publicRecord({name:'Review persisted',pass:true,password:'private',access_token:'private'}),{name:'Review persisted',pass:true});
  assert.throws(()=>publicRecord({name:'token@example.invalid',pass:true}));
  assert.throws(()=>publicRecord({name:'Review',pass:'yes'}));
  console.log('V117_BROWSER_PROTOCOL_SELF_TEST_PASS');
} else {
  assert(!process.env.AUTH_ADMIN_KEY && !process.env.DATABASE_URL && !process.env.GH_TOKEN);
  const root=resolve(process.env.CONTAOS_TEST_PRIVATE_DIR||'');
  assert(root.startsWith(process.env.RUNNER_TEMP+'/'));
  const frontend=resolve(process.env.CONTAOS_FRONTEND_DIR||'');
  const req=createRequire(join(frontend,'package.json'));
  const {expect}=req('@playwright/test');
  const {chromium}=await import(process.env.CONTAOS_PLAYWRIGHT_MODULE);
  const f=JSON.parse(readFileSync(join(root,'fixture.json'),'utf8'));
  const admin=f.users.find(u=>u.profile==='administrador');
  assert(admin?.creation_state==='created');
  const output=join(root,'public-browser');mkdirSync(output,{recursive:true,mode:0o700});
  const report={schema:'contaos.v117.private-browser.v1',backend_head:process.env.TESTED_HEAD,frontend_head:process.env.FRONTEND_HEAD,state:'RUNNING',assertions:[],visual:[],limits:['Synthetic document metadata, no physical upload or worker proof','Automated accessibility is not a full manual WCAG certification']};
  function save(){writeFileSync(join(output,'report.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});}
  function check(name,pass,http){report.assertions.push(publicRecord({name,pass,http}));save();assert(pass,name);}
  const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','4173'],{cwd:frontend,stdio:'ignore',env:Object.fromEntries(Object.entries(process.env).filter(([k])=>!['DATABASE_URL','AUTH_ADMIN_KEY','GH_TOKEN'].includes(k)))});
  let browser;
  try {
    for(let i=0;i<120;i++){try{if((await fetch('http://127.0.0.1:4173/login')).ok)break;}catch{} if(i===119)throw Error('Frontend unavailable');await new Promise(r=>setTimeout(r,1000));}
    browser=await chromium.launch({headless:true,env:{...process.env}});
    const context=await browser.newContext({viewport:{width:1440,height:1000},colorScheme:'light'});
    // Login uses the product form and GoTrue, never a forged JWT or admin token.
    const page=await context.newPage();page.setDefaultTimeout(30000);
    await page.goto('http://127.0.0.1:4173/login');
    await page.getByLabel('E-mail',{exact:true}).fill(admin.email);
    await page.getByLabel('Senha',{exact:true}).fill(admin.password);
    const login=page.waitForResponse(r=>r.url().includes('/auth/v1/token?')&&r.request().method()==='POST');
    await page.getByRole('button',{name:'Entrar',exact:true}).click();
    check('Browser GoTrue login',(await login).status()===200,200);
    await page.waitForURL(u=>!u.pathname.includes('/login'));
    await page.evaluate(({user,org})=>sessionStorage.setItem('contaos.preferenciaOrganizacao',JSON.stringify({idUsuario:user,idOrganizacao:org})),{user:admin.id,org:f.org});
    const route='http://127.0.0.1:4173/competencias/'+f.competence+'/analise';
    await page.goto(route);
    const open=page.getByRole('button',{name:'Abrir requisito '+f.requirement,exact:true});
    await open.click();
    await expect(page.getByRole('heading',{name:'Detalhe do requisito',exact:true})).toBeVisible();
    await page.getByRole('button',{name:'Revisar resultado',exact:true}).click();
    await expect(page.getByLabel('Justificativa da revisão')).toBeVisible();
    check('Private drawer and review editor',true);
    const choice=page.getByRole('checkbox',{name:'Selecionar evidence.pdf versão 1',exact:true});
    await expect(choice).toBeVisible();check('RLS approved evidence query',true);
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
      const a11y=await page.evaluate(async()=>{const r=await window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']}});return {version:r.testEngine.version,violations:r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),incomplete:r.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};});
      const screenshot='v117-'+width+'-'+theme+'.png';await page.screenshot({path:join(output,screenshot),fullPage:true});
      report.visual.push({width,theme,overflow,a11y,screenshot});save();
      check('No horizontal overflow '+width+' '+theme,overflow<=2);
      check('Automated accessibility '+width+' '+theme,a11y.violations.length===0);
    }
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
    await expect(page.getByText('Synthetic UI review '+f.scope,{exact:true}).first()).toBeVisible();
    check('UI displays persisted justification',true);
    await context.close();
    const denied=f.users.find(u=>u.profile==='usuario_b');
    const other=await browser.newContext({viewport:{width:1280,height:900}});
    const otherPage=await other.newPage();otherPage.setDefaultTimeout(30000);
    await otherPage.goto('http://127.0.0.1:4173/login');
    await otherPage.getByLabel('E-mail',{exact:true}).fill(denied.email);
    await otherPage.getByLabel('Senha',{exact:true}).fill(denied.password);
    await otherPage.getByRole('button',{name:'Entrar',exact:true}).click();
    await otherPage.waitForURL(u=>!u.pathname.includes('/login'));
    await otherPage.evaluate(({user,org})=>sessionStorage.setItem('contaos.preferenciaOrganizacao',JSON.stringify({idUsuario:user,idOrganizacao:org})),{user:denied.id,org:f.org_b});
    await otherPage.goto(route);
    await expect(otherPage.getByText('Você não tem acesso a esta competência.',{exact:true})).toBeVisible();
    check('Cross tenant UI denies private competence',true);
    check('Denied tenant has no review button',await otherPage.getByRole('button',{name:'Revisar resultado',exact:true}).count()===0);
    await other.close();report.state='PASS';
  }catch{report.state='FAIL';throw Error('Private browser acceptance failed; sanitized report contains the completed checks');}
  finally{save();await browser?.close();server.kill('SIGTERM');}
}
