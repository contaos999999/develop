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
  const rag=source.indexOf("admin.rpc('worker_buscar_fragmentos_temporais'");
  const chamada=source.lastIndexOf('await sintetizarComOpenAI(pergunta, fontes');
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
  assert.match(source,/respostaIA \? .* : resumoDeterministico/);
  assert.match(source,/return null \/\/ fallback determinístico/);
  assert.match(source,/sujeita à revisão humana/);
});


// Executa o handler real. Somente I/O externo é substituído, sem credenciais reais.
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
const ORIGINS=['http://127.0.0.1:4173','https://scope-and-approval-keeper.lovable.app','https://contaos-41-hml.vercel.app'];
const evil='https://untrusted.invalid';
function runtime(options={}) {
  const calls=[]; let handler;
  const fragment={id:'fragment',id_versao_documento:'version',pagina_inicio:2,pagina_fim:2,texto:'Obrigação documental válida.',similaridade:0.8,fonte_temporal:'documento_contratual_ou_evidencia'};
  const precedent={id:'precedent',id_contrato_origem:'contract',competencia_origem:'2026-10-01',problema:'Documentação',solucao:'Apresentada',desfecho:'rejeitado',score_final:0.8,similaridade:0.8,escopo_resultado:'MESMO CONTRATO'};
  function client(admin=false) {
    return {
      auth:{getUser:async()=>{calls.push(['auth']);if(options.pauseAuth) await options.pauseAuth;return {data:{user:options.invalidAuth?null:{id:'synthetic-user'}},error:options.invalidAuth?{}:null};}},
      from(table){
        const state={operation:'select',value:null};
        const chain={};
        for(const method of ['select','eq','insert','update']) chain[method]=(...args)=>{if(method==='insert'||method==='update'){state.operation=method;state.value=args[0];}calls.push([admin?'admin':'user',table,method,...args]);return chain;};
        function result(){
          if(!admin&&table==='contratos') return {data:options.denied?null:{id:'contract',id_organizacao:'org',id_contratante:'contractor',numero:'123'},error:options.denied?{}:null};
          if(options.dbError&&table===options.dbError) return {data:null,error:{message:'internal fixture error'}};
          return {data:{id:table+'-id'},error:null};
        }
        chain.single=async()=>result();chain.maybeSingle=async()=>result();chain.then=(resolve,reject)=>Promise.resolve(result()).then(resolve,reject);return chain;
      },
      rpc:async(name,args)=>{calls.push(['rpc',name,args]);return {data:options.noSources?[]:name==='worker_buscar_fragmentos_temporais'?[fragment]:(options.conflict?[precedent,{...precedent,id:'other',desfecho:'aprovado'}]:[]),error:options.ragError?{message:'private error'}:null};},
    };
  }
  const compiled=stripTypeScriptTypes(source.replace(/^import .*\n/gm,''),{mode:'strip'});
  runInNewContext(compiled,{
    Request,Response,Headers,TextDecoder,Uint8Array,AbortSignal,
    Deno:{env:{get:key=>({SUPABASE_URL:'https://fixture.invalid',SUPABASE_ANON_KEY:'public-fixture',SUPABASE_SERVICE_ROLE_KEY:'private-fixture',OPENAI_API_KEY:options.noKey?'':'ai-fixture'})[key]},serve:fn=>{handler=fn;}},
    Supabase:{ai:{Session:class {async run(){calls.push(['embedding']);return [0.1,0.2];}}}},
    createClient:(_url,key)=>client(key==='private-fixture'),
    fetch:async(url,init)=>{calls.push(['fetch',url,JSON.parse(init.body),init]);if(options.fetchError) throw new Error('private provider error');return Response.json(options.output??{status:'completed',output:[{type:'message',status:'completed',role:'assistant',content:[{type:'output_text',text:'A fonte registra obrigação documental [F1].',annotations:[]}]}]},{status:options.providerStatus??200});},
  });
  const request=(method='POST',origin=ORIGINS[2],extra={},body={id_contrato:'contract',pergunta:'Quais obrigações?'})=>new Request('https://fixture.invalid/copilot-query',{method,headers:{...(origin===null?{}:{origin}),...(method==='POST'?{authorization:'Bearer synthetic-jwt','content-type':'application/json'}:{}),...extra},...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})});
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
 for(const call of r.calls.filter(c=>c[0]==='rpc')){assert.equal(call[2].p_id_organizacao,'org');assert.equal(call[2].p_id_contrato,'contract');}
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
