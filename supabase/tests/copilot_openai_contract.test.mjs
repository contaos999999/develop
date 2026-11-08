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
