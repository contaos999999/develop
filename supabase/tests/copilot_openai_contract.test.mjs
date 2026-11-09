import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const source=readFileSync(new URL('../functions/copilot-query/index.ts',import.meta.url),'utf8');
test('C-CHAT-001: segredo OpenAI e chamada somente na Edge',()=>{
  assert.match(source,/Deno\.env\.get\('OPENAI_API_KEY'\)/);
  assert.match(source,/https:\/\/api\.openai\.com\/v1\/responses/);
  assert.match(source,/store:false/);
  assert.match(source,/max_output_tokens:500/);
  assert.match(source,/AbortSignal\.timeout\(12000\)/);
  assert.match(source,/if\(!OPENAI_API_KEY \|\| fontes\.length===0\) return null/);
});
test('C-CHAT-001: autorização e escopo precedem chamada externa',()=>{
  const auth=source.indexOf('userClient.auth.getUser()');
  const contrato=source.indexOf("userClient.from('contratos')");
  const rag=source.indexOf("admin.rpc('worker_buscar_fragmentos_copiloto'");
  const chamada=source.search(/await sintetizarComOpenAI\(pergunta\s*,\s*fontes/);
  assert.ok(auth>=0 && auth<contrato && contrato<rag && rag<chamada);
  assert.match(source,/p_id_organizacao:contrato\.id_organizacao/);
  assert.match(source,/p_id_contrato:idContrato/);
});
test('C-CHAT-001: prompt injection, limites, fallback e decisão humana',()=>{
  assert.match(source,/DADOS NÃO CONFIÁVEIS/);
  assert.match(source,/Não aprove, valide, libere apresentação/);
  assert.match(source,/MAX_FONTE_COUNT = 8/);
  assert.match(source,/MAX_FONTE_CHARS = 600/);
  assert.match(source,/pergunta\.slice\(0,3000\)/);
  assert.match(source,/respostaIA\s*\?[\s\S]*?:resumoDeterministico/);
  assert.match(source,/return null \/\/ fallback determinístico/);
  assert.match(source,/sujeita à revisão humana/);
});


// Executa o handler real. Somente I/O externo é substituído, sem credenciais reais.
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
const ORIGINS=['http://127.0.0.1:4173','https://scope-and-approval-keeper.lovable.app','https://contaos-41-hml.vercel.app'];
const evil='https://untrusted.invalid';
function runtime(options={}) {
  const calls=[]; let handler; let ranked=false;
  const fragment={id:'fragment',id_versao_documento:'version',pagina_inicio:2,pagina_fim:2,texto:'Obrigação documental válida.',similaridade:0.8,fonte_temporal:'documento_contratual_ou_evidencia'};
  const precedent={id:'precedent',id_contrato_origem:'contract',competencia_origem:'2026-10-01',problema:'Documentação',solucao:'Apresentada',desfecho:options.conflictNegative??'rejeitado',score_final:0.8,similaridade:0.8,escopo_resultado:'MESMO CONTRATO'};
  const versionRow={id:'version',id_organizacao:'org',id_contrato:'contract',arquivos:{id:'file',id_organizacao:'org',id_contrato:'contract',status_seguranca:options.unsafeSource?'quarentena':'aprovado'},processamentos_documento:[{id_organizacao:'org',id_contrato:'contract',etapa:'documents',status:options.incompleteSource?'processando':'concluido',concluido_em:'2026-11-08T00:00:00Z'}]};
  const precRows=options.conflict?[precedent,{...precedent,id:'other',desfecho:'aprovado'}]:[];
  function client(admin=false) {
    return {
      auth:{getUser:async()=>{calls.push(['auth']);if(options.pauseAuth) await options.pauseAuth;return {data:{user:options.invalidAuth?null:{id:'synthetic-user'}},error:options.invalidAuth?{}:null};}},
      from(table){
        const state={operation:'select',value:null,filters:{},after:null};
        const chain={};
        for(const method of ['select','eq','insert','update','order','limit','gt','in','abortSignal']) chain[method]=(...args)=>{if(method==='insert'||method==='update'){state.operation=method;state.value=args[0];}if(method==='eq')state.filters[args[0]]=args[1];if(method==='gt')state.after=args[1];if(method==='in')state.many=true;calls.push([admin?'admin':'user',table,method,...args]);return chain;};
        function result(){
          if(admin&&table==='mensagens_copiloto'&&state.operation==='insert'){options.afterMessage?.();}
          if(!admin&&table==='sessoes_copiloto'&&options.foreignSession&&state.filters.criado_por) return {data:null,error:null};
          if(!admin&&table==='fragmentos_documento') return {data:options.noSources||state.after?[]:[{id:'fragment',id_organizacao:'org',id_contrato:'contract',id_versao_documento:'version'}],error:null};
          if(!admin&&table==='versoes_documento') return {data:[{...versionRow,arquivos:{...versionRow.arquivos,status_seguranca:options.unsafeSource?'quarentena':'aprovado'},processamentos_documento:versionRow.processamentos_documento.map(p=>({...p,status:options.incompleteSource?'processando':'concluido'}))}],error:null};
          if(!admin&&table==='precedentes') return {data:options.noSources||state.after?[]:precRows.map(p=>({...p,id_organizacao:'org',id_contratante:'contractor'})).sort((a,b)=>a.id.localeCompare(b.id)),error:null};
          if(!admin&&table==='contratos'&&state.many) return {data:options.deniedOrigin?[]:[{id:'contract',id_organizacao:'org',id_contratante:'contractor'}],error:null};
          if(!admin&&table==='contratos') return {data:options.denied?null:{id:'contract',id_organizacao:'org',id_contratante:'contractor',numero:'123'},error:options.denied?{}:null};
          if(options.dbError&&table===options.dbError) return {data:null,error:{message:'internal fixture error'}};
          return {data:{id:table+'-id'},error:null};
        }
        chain.single=async()=>result();chain.maybeSingle=async()=>result();chain.then=(resolve,reject)=>Promise.resolve(result()).then(resolve,reject);return chain;
      },
      rpc:async(name,args)=>{calls.push(['rpc',name,args]);if(name==='worker_buscar_precedentes_copiloto'&&!ranked){ranked=true;options.afterRanking?.();}if(name==='worker_reservar_consulta_copiloto')return {data:options.quotaDenied?{autorizado:false,codigo:options.quotaDenied,retry_after:60}:{autorizado:true,id_consulta:'consultas_semanticas-id',token:'11111111-1111-4111-8111-111111111111',deadline_at:new Date(Date.now()+45000).toISOString(),expires_at:new Date(Date.now()+90000).toISOString()},error:null};if(name==='worker_validar_lease_copiloto')return {data:!options.invalidLease&&!options.leaseRevoked?.(),error:null};if(name==='worker_concluir_consulta_copiloto')return {data:{id_mensagem:'mensagens_copiloto-id',id_retorno:'retornos_modelo-id'},error:options.finalizeError?{code:'42501'}:null};if(name==='worker_falhar_consulta_copiloto')return {data:true,error:null};if(name==='consultar_permissoes_efetivas')return {data:{permissoes:[{recurso:'contratos',acao:'consultar'},{recurso:'arquivos',acao:'consultar'},...(!options.denyHistory?[{recurso:'historico',acao:'consultar'}]:[])]},error:null};return {data:options.noSources?[]:(name==='worker_buscar_fragmentos_temporais'||name==='worker_buscar_fragmentos_copiloto')?(args.p_ids_fragmentos&&args.p_ids_fragmentos.length===0?[]:[fragment]):(args.p_ids_precedentes&&args.p_ids_precedentes.length===0?[]:precRows),error:options.ragError?{message:'private error'}:null};},
    };
  }
  const compiled=stripTypeScriptTypes(source.replace(/^import .*\n/gm,''),{mode:'strip'});
  runInNewContext(compiled,{
    Request,Response,Headers,TextDecoder,Uint8Array,AbortSignal,atob,
    Deno:{env:{get:key=>({SUPABASE_URL:'https://fixture.invalid',SUPABASE_ANON_KEY:'public-fixture',SUPABASE_SERVICE_ROLE_KEY:'private-fixture',OPENAI_API_KEY:options.noKey?'':'ai-fixture'})[key]},serve:fn=>{handler=fn;}},
    Supabase:{ai:{Session:class {async run(){calls.push(['embedding']);return [0.1,0.2];}}}},
    createClient:(_url,key)=>client(key==='private-fixture'),
    fetch:async(url,init)=>{calls.push(['fetch',url,JSON.parse(init.body),init]);if(options.fetchError) throw new Error('private provider error');return Response.json(options.output??{status:'completed',output:[{type:'message',status:'completed',role:'assistant',content:[{type:'output_text',text:'A fonte registra obrigação documental [F1].',annotations:[]}]}]},{status:options.providerStatus??200});},
  });
  const request=(method='POST',origin=ORIGINS[2],extra={},body={id_contrato:'contract',pergunta:'Quais obrigações?'})=>new Request('https://fixture.invalid/copilot-query',{method,headers:{...(origin===null?{}:{origin}),...(method==='POST'?{authorization:'Bearer '+btoa(JSON.stringify({alg:'HS256'}))+'.'+btoa(JSON.stringify({sub:'synthetic-user',role:'authenticated',session_id:'22222222-2222-4222-8222-222222222222',exp:Math.floor(Date.now()/1000)+3600}))+'.fixture-signature','content-type':'application/json'}:{}),...extra},...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})});
  return {handler,calls,request};
}
function cors(response,origin){assert.equal(response.headers.get('access-control-allow-origin'),origin);assert.equal(response.headers.get('access-control-allow-credentials'),null);assert.match(response.headers.get('vary')??'',/Origin/);assert.equal(response.headers.get('cache-control'),'no-store');}
for(const origin of ORIGINS) test(`runtime preflight autorizado ${origin} não toca Auth/DB/IA`,async()=>{
  const r=runtime();const response=await r.handler(r.request('OPTIONS',origin,{'access-control-request-method':'POST','access-control-request-headers':'Authorization, apikey, Content-Type, x-client-info'}));
  assert.equal(response.status,204);cors(response,origin);assert.equal(await response.text(),'');assert.equal(response.headers.get('access-control-allow-methods'),'POST, OPTIONS');assert.deepEqual(r.calls,[]);
});
for(const [origin,method,headers] of [[evil,'POST','authorization'],['null','POST','authorization'],[ORIGINS[2]+'/', 'POST','authorization'],[ORIGINS[2],'DELETE','authorization'],[ORIGINS[2],'POST','x-internal-token'],[ORIGINS[2],'POST','authorization,'],[null,'POST','authorization']]) test(`runtime preflight nega origem/método/header ${origin}/${method}/${headers}`,async()=>{
 const r=runtime();const response=await r.handler(r.request('OPTIONS',origin,{'access-control-request-method':method,'access-control-request-headers':headers}));assert.ok([403,405].includes(response.status));assert.equal(response.headers.get('access-control-allow-origin'),null);assert.deepEqual(r.calls,[]);
});
test('runtime POST de origem desconhecida nega antes de Auth',async()=>{const r=runtime();const response=await r.handler(r.request('POST',evil));assert.equal(response.status,403);assert.equal(response.headers.get('access-control-allow-origin'),null);assert.deepEqual(r.calls,[]);});
for(const [label,options,body,status] of [['sessão inválida',{invalidAuth:true},null,401],['contrato negado',{denied:true},null,403],['JSON inválido',{},'{',400],['pergunta ausente',{}, {id_contrato:'contract'},400],['payload grande',{},'x'.repeat(66000),413],['pergunta grande',{}, {id_contrato:'contract',pergunta:'x'.repeat(12001)},413],['falha RAG',{ragError:true},null,500],['falha sessão',{dbError:'sessoes_copiloto'},null,500]]) test(`runtime ${label} mantém CORS e impede chamada OpenAI`,async()=>{
 const r=runtime(options);const response=await r.handler(body===null?r.request():r.request('POST',ORIGINS[2],{},body));assert.equal(response.status,status);cors(response,ORIGINS[2]);assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);
});
test('runtime POST sem JWT preserva 401 com CORS',async()=>{const r=runtime();const request=r.request();request.headers.delete('authorization');const response=await r.handler(request);assert.equal(response.status,401);cors(response,ORIGINS[2]);assert.deepEqual(r.calls,[]);});
test('runtime sucesso preserva escopo, fontes e contrato OpenAI backend',async()=>{
 const r=runtime();const response=await r.handler(r.request());assert.equal(response.status,200);cors(response,ORIGINS[2]);const body=await response.json();assert.match(body.resposta,/obrigação documental \[F1\]/);assert.equal(body.fontes[0].fonte_id,'fragment');
 const auth=r.calls.findIndex(c=>c[0]==='auth'),contract=r.calls.findIndex(c=>c[0]==='user'&&c[1]==='contratos'),rag=r.calls.findIndex(c=>c[0]==='rpc'),external=r.calls.findIndex(c=>c[0]==='fetch');assert.ok(auth<contract&&contract<rag&&rag<external);
 for(const call of r.calls.filter(c=>c[0]==='rpc'&&c[1].startsWith('worker_buscar_'))){assert.equal(call[2].p_id_organizacao,'org');assert.equal(call[2].p_id_contrato,'contract');}
 const call=r.calls[external];assert.equal(call[1],'https://api.openai.com/v1/responses');assert.equal(call[2].store,false);assert.equal(call[2].max_output_tokens,500);const input=JSON.parse(call[2].input[1].content);assert.equal(input.evidencias[0].referencia,'F1');assert.doesNotMatch(JSON.stringify(input),/private-fixture|synthetic-jwt|synthetic-user|ai-fixture/);
});
for(const options of [{noSources:true},{noKey:true},{fetchError:true},{providerStatus:429}]) test(`runtime fallback seguro ${JSON.stringify(options)}`,async()=>{const r=runtime(options);const response=await r.handler(r.request());assert.equal(response.status,200);const body=await response.json();assert.match(body.resposta,/Pergunta analisada no contrato/);if(options.noSources||options.noKey) assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);});
for(const output of [
 {status:'incomplete',incomplete_details:{reason:'max_output_tokens'},output:[{type:'message',status:'incomplete',content:[{type:'output_text',text:'Conclusão interrompida [F1]'}]}]},
 {status:'completed',output:[{type:'message',status:'completed',content:[{type:'output_text',text:'Fonte inexistente [F9].'}]}]},
 {status:'completed',output:[{type:'message',status:'completed',content:[{type:'output_text',text:'Conclusão sem qualquer citação.'}]}]},
 {status:'completed',output:[{type:'message',status:'completed',content:[{type:'refusal',refusal:'Não posso responder.'}]}]},
]) test(`runtime saída insegura usa fallback ${JSON.stringify(output).slice(0,95)}`,async()=>{const r=runtime({output});const response=await r.handler(r.request());assert.equal(response.status,200);const body=await response.json();assert.match(body.resposta,/Pergunta analisada no contrato/);assert.doesNotMatch(body.resposta,/interrompida|inexistente|sem qualquer citação/);});
test('runtime síntese não oculta conflito determinístico',async()=>{const r=runtime({conflict:true});const response=await r.handler(r.request());const body=await response.json();assert.equal(body.conflito_historico,true);assert.match(body.resposta,/desfechos divergentes/);assert.match(body.resposta,/revisão humana/);});
test('runtime requisições concorrentes não compartilham origem CORS',async()=>{let release;const paused=new Promise(resolve=>{release=resolve;});const r=runtime({pauseAuth:paused});const allowed=r.handler(r.request());const pendingDenied=r.handler(r.request('POST',evil));release();const denied=await pendingDenied;const response=await allowed;assert.equal(denied.headers.get('access-control-allow-origin'),null);cors(response,ORIGINS[2]);});

for(const desfecho of ['desfavorável','desfavoravel','indeferido','improcedente']) test(`runtime conflito com aprovado e ${desfecho} exige revisão humana`,async()=>{const r=runtime({conflict:true,conflictNegative:desfecho});const response=await r.handler(r.request());const body=await response.json();assert.equal(body.conflito_historico,true);assert.equal(body.incerteza,true);assert.match(body.resposta,/desfechos divergentes/);assert.match(body.resposta,/revisão humana/);});

for(const codigo of ['COPILOTO_LIMITE_TAXA','COPILOTO_LIMITE_CONCORRENCIA'])test(`runtime quota ${codigo} retorna429 semembedding/OpenAI`,async()=>{const r=runtime({quotaDenied:codigo});const response=await r.handler(r.request());assert.equal(response.status,429);cors(response,ORIGINS[2]);assert.equal(response.headers.get('retry-after'),'60');assert.equal(r.calls.filter(c=>c[0]==='fetch'||c[0]==='embedding').length,0);});
test('runtime sessão de terceiro exige owner explícito mesmo se RLS for ampla',async()=>{const r=runtime({foreignSession:true});const response=await r.handler(r.request('POST',ORIGINS[2],{},{id_contrato:'contract',pergunta:'Pergunta',id_sessao:'foreign-session'}));assert.equal(response.status,403);assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);});
test('runtime lease revogada impede chamada externa e publicação',async()=>{const r=runtime({invalidLease:true});const response=await r.handler(r.request());assert.equal(response.status,409);assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);});
test('runtime persistência só usa finalizador fenced, sem INSERT privilegiado de resposta',async()=>{const r=runtime();const response=await r.handler(r.request());assert.equal(response.status,200);assert.ok(r.calls.some(c=>c[0]==='rpc'&&c[1]==='worker_concluir_consulta_copiloto'));assert.equal(r.calls.filter(c=>c[0]==='admin'&&['retornos_modelo','fontes_resposta_copiloto'].includes(c[1])&&c[2]==='insert').length,0);});

for(const option of ['unsafeSource','incompleteSource'])test(`runtime fonte ${option} não chega a ranking externo/OpenAI`,async()=>{const r=runtime({[option]:true});const response=await r.handler(r.request());assert.equal(response.status,200);assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);const body=await response.json();assert.equal(body.fontes.length,0);});
test('runtime reserva usa session_id do JWT validado e ignora session_id do body',async()=>{const r=runtime();await r.handler(r.request('POST',ORIGINS[2],{},{id_contrato:'contract',pergunta:'Pergunta',session_id:'33333333-3333-4333-8333-333333333333'}));const call=r.calls.find(c=>c[0]==='rpc'&&c[1]==='worker_reservar_consulta_copiloto');assert.ok(call);assert.equal(call[2].p_filtros.session_id,'22222222-2222-4222-8222-222222222222');});

for(const abort of [false,true])test(`runtime fence após mensagem impede embedding com ${abort?'abort':'lease revogada'}`,async()=>{let revoked=false;const controller=new AbortController();const r=runtime({afterMessage:()=>{revoked=true;if(abort)controller.abort();},leaseRevoked:()=>revoked});const request=new Request(r.request(),{signal:controller.signal});const response=await r.handler(request);assert.equal(response.status,abort?504:409);assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
for(const date of ['2026-02-30','2026-11-09T00:00:00Z',123,'2026-2-01'])test(`runtime data estrita rejeita ${date}`,async()=>{const r=runtime();const response=await r.handler(r.request('POST',ORIGINS[2],{},{id_contrato:'contract',pergunta:'Teste',data_referencia:date}));assert.equal(response.status,400);assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
test('runtime nonce e identificador contratual não alcançam provedor/browser',async()=>{const r=runtime();const response=await r.handler(r.request());assert.equal(response.status,200);const raw=await response.text();const provider=JSON.stringify(r.calls.find(c=>c[0]==='fetch')[2]);for(const text of [raw,provider])assert.ok(!text.includes('11111111-1111-4111-8111-111111111111'));assert.ok(!provider.includes('123'));assert.ok(!provider.includes('contractor'));});
test('runtime sem permissão histórico exclui precedentes antes ranking',async()=>{const r=runtime({conflict:true,denyHistory:true});const response=await r.handler(r.request());assert.equal(response.status,200);const reserve=r.calls.find(c=>c[0]==='rpc'&&c[1]==='worker_reservar_consulta_copiloto');assert.equal(reserve[2].p_filtros.ids_precedentes.length,0);});

for(const flag of ['denyHistory','deniedOrigin','unsafeSource','incompleteSource'])test(`runtime revogação ${flag} após ranking bloqueia envio externo`,async()=>{const options={conflict:true,afterRanking:()=>{options[flag]=true;},finalizeError:true};const r=runtime(options);const response=await r.handler(r.request());assert.equal(response.status,403);assert.equal(r.calls.filter(c=>c[0]==='fetch').length,0);assert.equal(r.calls.filter(c=>c[0]==='rpc'&&c[1]==='worker_concluir_consulta_copiloto').length,0);});

test('C13 listar sessões próprias não inicia inferência ou reserva',async()=>{const r=runtime();const response=await r.handler(r.request('POST',ORIGINS[2],{},{action:'listar_sessoes',id_contrato:'contract'}));assert.equal(response.status,200);const body=await response.json();assert.equal(body.ok,true);assert.ok(Array.isArray(body.sessoes));assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch'||c[0]==='rpc'&&c[1]==='worker_reservar_consulta_copiloto').length,0);});
test('C13 histórico próprio sem pergunta usa DTO paginado e nenhuma IA',async()=>{const r=runtime();const response=await r.handler(r.request('POST',ORIGINS[2],{},{action:'historico',id_contrato:'contract',id_sessao:'33333333-3333-4333-8333-333333333333'}));assert.equal(response.status,200);const body=await response.json();assert.equal(body.ok,true);assert.ok(Array.isArray(body.mensagens));assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
test('C13 encerrar sessão é operação sem inferência',async()=>{const r=runtime();const response=await r.handler(r.request('POST',ORIGINS[2],{},{action:'encerrar_sessao',id_contrato:'contract',id_sessao:'33333333-3333-4333-8333-333333333333'}));assert.equal(response.status,200);assert.equal((await response.json()).status,'encerrada');assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
for(const action of ['listar_sessoes','historico','encerrar_sessao'])test(`C13 ${action} contrato negado preserva403/CORS`,async()=>{const r=runtime({denied:true});const response=await r.handler(r.request('POST',ORIGINS[2],{},{action,id_contrato:'contract',id_sessao:'33333333-3333-4333-8333-333333333333'}));assert.equal(response.status,403);cors(response,ORIGINS[2]);assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
test('C13 ação desconhecida não reutiliza perguntar',async()=>{const r=runtime();const response=await r.handler(r.request('POST',ORIGINS[2],{},{action:'administrar',id_contrato:'contract',pergunta:'Não executar'}));assert.equal(response.status,400);assert.equal(r.calls.filter(c=>c[0]==='embedding'||c[0]==='fetch').length,0);});
