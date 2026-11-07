import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
export function browserEnvironment(source){
  const allowed=['PATH','HOME','RUNNER_TEMP','TMPDIR','LANG','TZ','CI','XDG_CACHE_HOME','CONTAOS_TEST_PRIVATE_DIR','CONTAOS_FRONTEND_DIR','CONTAOS_AXE_SOURCE_PATH','CONTAOS_PLAYWRIGHT_MODULE','TESTED_HEAD','FRONTEND_HEAD'];
  return Object.fromEntries(allowed.filter(k=>source[k]!==undefined).map(k=>[k,source[k]]));
}
export function publicRecord({name,pass,http}){
  assert(/^[A-Z0-9_]{1,100}$/.test(name)&&typeof pass==='boolean');
  assert(http===undefined||Number.isInteger(http)&&http>=100&&http<=599);
  return {name,pass,...(http===undefined?{}:{http})};
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
  const output=join(root,'public-browser');mkdirSync(output,{recursive:true,mode:0o700});
  const report={schema:'contaos.crud-global.browser.v1',backend_head:process.env.TESTED_HEAD,frontend_head:process.env.FRONTEND_HEAD,batch:'CADASTROS_LISTAS',global_complete:false,state:'RUNNING',stage:'START',assertions:[],runtime_errors:[],limits:['Partial batch; remaining matrix domains are not certified','No physical upload or worker proof in this batch','Automated tests do not certify full manual WCAG']};
  const save=()=>writeFileSync(join(output,probe?'public-probe.json':'report.json'),JSON.stringify(report,null,2)+'\n',{mode:0o600});
  function stage(s){assert(/^[A-Z0-9_]{1,100}$/.test(s));report.stage=s;save();}
  function check(name,pass,http){report.assertions.push(publicRecord({name,pass,http}));save();assert(pass,name);}
  function created(name,id){assert(['organization','contractor','contract','list'].includes(name)&&/^[a-f0-9-]{36}$/.test(id));f.created[name]=id;writeFileSync(join(root,'fixture.json'),JSON.stringify(f,null,2)+'\n',{mode:0o600});}
  const base='http://127.0.0.1:4173';const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','4173'],{cwd:frontend,detached:true,stdio:'ignore',env:browserEnvironment(process.env)});let browser;let diagnosticPage;let readHttp=null;
  try{
    stage('SERVER_READY');for(let i=0;i<120;i++){try{if((await fetch(base+'/login')).ok)break;}catch{}if(i===119)throw Error('Frontend unavailable');await new Promise(r=>setTimeout(r,1000));}
    browser=await chromium.launch({headless:true,env:browserEnvironment(process.env)});
    async function open(role){
      const context=await browser.newContext({viewport:{width:1440,height:1000},colorScheme:'light'});const page=await context.newPage();page.setDefaultTimeout(30000);diagnosticPage=page;
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
      await x.context.close();report.state='PASS_PUBLIC_PROBE';save();return;
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
    const second=await master.context.newPage();second.setDefaultTimeout(30000);await second.goto(base+'/contratos/'+f.contract+'/regras');await second.getByRole('button',{name:'Gerenciar listas',exact:true}).click();
    await lp.getByRole('button',{name:'Editar lista',exact:true}).click();await lp.getByLabel('Nome',{exact:true}).fill(f.prefix+'recovered');await lp.getByLabel('Motivo',{exact:true}).fill('Own conflict recovery draft');
    await listOp(second,'LIST_CONCURRENT_EDIT','Editar lista',()=>second.getByLabel('Descrição',{exact:true}).fill('Own concurrent real edit'));
    await lp.getByRole('button',{name:'Revisar operação',exact:true}).click();stage('LIST_REAL_CONFLICT');const conflict=lp.waitForResponse(r=>r.url().endsWith('/rpc/executar_comando_lista_v1')&&r.request().method()==='POST');await lp.getByRole('button',{name:'Confirmar operação',exact:true}).click();check('LIST_REAL_CONFLICT',(await conflict).status()===409,409);
    // Browser transport fails for the real read URL while navigator remains online.
    // Context offline would pause React Query before any read, so it cannot prove read failure.
    stage('LIST_TRANSIENT_READ');let writesDuringFault=0;const countWrite=r=>{if(r.url().includes('/rpc/executar_comando_lista_v1')&&r.method()==='POST')writesDuringFault++;};lp.on('request',countWrite);
    await withReadTransportFailure(await master.context.newCDPSession(lp),async()=>{
      await lp.getByRole('button',{name:'Atualizar dados e revisar rascunho',exact:true}).click();
      await expect(lp.getByText(/Seu rascunho foi preservado/)).toBeVisible();await expect(lp.getByLabel('Nome',{exact:true})).toHaveValue(f.prefix+'recovered');await expect(lp.getByRole('button',{name:'Confirmar operação',exact:true})).toBeDisabled();
      check('LIST_TRANSIENT_DRAFT_PRESERVED',true);check('LIST_NO_WRITE_DURING_FAILED_READ',writesDuringFault===0);
    });lp.off('request',countWrite);
    await lp.getByRole('button',{name:'Tentar novamente',exact:true}).click();await expect(lp.getByRole('button',{name:'Confirmar operação',exact:true})).toBeEnabled();await lp.getByRole('button',{name:'Revisar campos',exact:true}).click();await lp.getByRole('button',{name:'Revisar operação',exact:true}).click();await rpc(lp,'LIST_RECOVERED_WRITE','executar_comando_lista_v1',()=>lp.getByRole('button',{name:'Confirmar operação',exact:true}).click());await second.close();
    for(const width of [1440,1280,768,390])for(const theme of ['light','dark']){stage('VISUAL_'+width+'_'+theme.toUpperCase());await lp.setViewportSize({width,height:1000});await lp.emulateMedia({colorScheme:theme});await lp.evaluate(t=>document.documentElement.classList.toggle('dark',t==='dark'),theme);const overflow=await lp.evaluate(()=>Math.max(0,document.documentElement.scrollWidth-innerWidth));check('OVERFLOW_'+width+'_'+theme.toUpperCase(),overflow<=2);await lp.screenshot({path:join(output,'crud-list-'+width+'-'+theme+'.png'),fullPage:false,animations:'disabled'});}
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
