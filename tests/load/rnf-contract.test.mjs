// Testes estáticos do contrato RNF. Não acessam rede/Supabase nem simulam evidência operacional.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const k6 = readFileSync(new URL('./k6-hml.js', import.meta.url), 'utf8');
const matriz = readFileSync(new URL('../../docs/rnf/RNF_001_012_CRITERIOS_E_EVIDENCIAS_4_1.md', import.meta.url), 'utf8');

test('NFR-012: as duas rotas GET têm limite p95 próprio de 500ms', () => {
  for (const rota of ['contratos_lista', 'catalogo_status']) {
    assert.ok(k6.includes(`'http_req_duration{rota:${rota}}': ['p(95)<500']`), `Threshold ausente para ${rota}`);
    assert.ok(k6.includes(`tags: { rota: '${rota}' }`), `Tag de rota ausente: ${rota}`);
  }
  assert.doesNotMatch(k6, /'http_req_duration'\s*:\s*\['p\(95\)<1000'\]/);
});

test('NFR-012: roteiro de carga recusa PROD e URLs desconhecidas', () => {
  assert.match(k6, /gklhhhyosgasnyoxlrui/);
  assert.match(k6, /const HML = \/\^https:/);
  assert.match(k6, /const LOCAL = \/\^http:/);
  assert.match(k6, /if \(!HML\.test\(BASE\) && !LOCAL\.test\(BASE\)\)/);
  assert.match(k6, /Carga recusada/);
});

test('NFR-012: o cenário é de leitura, com POST somente para login', () => {
  assert.equal((k6.match(/\bhttp\.get\s*\(/g) || []).length, 2, 'Apenas duas rotas GET de leitura');
  assert.equal((k6.match(/\bhttp\.post\s*\(/g) || []).length, 1, 'POST deve existir somente no Auth');
  assert.match(k6, /auth\/v1\/token\?grant_type=password/);
  assert.doesNotMatch(k6, /\bhttp\.(?:put|patch|del|delete|request)\s*\(/i);
  assert.doesNotMatch(k6, /rest\/v1\/rpc\//);
});

test('NFR-009: lista limitada a 25 registros, sem carga completa', () => {
  assert.match(k6, /rest\/v1\/contratos\?[^\n]*limit=25/);
  assert.match(k6, /http_req_failed: \['rate<0\.01'\]/);
  assert.match(k6, /checks: \['rate>0\.99'\]/);
});

test('NFR-001 a 012: matriz preserva IDs e objetivos originais sem declaração de prova falsa', () => {
  for (let i = 1; i <= 12; i++) {
    assert.match(matriz, new RegExp('NFR-' + String(i).padStart(3, '0')));
  }
  assert.match(matriz, /p95.*500 ms/);
  assert.match(matriz, /p95.*800 ms/);
  assert.match(matriz, /99,9%/);
  assert.match(matriz, /não houve ensaio HML ou PROD/);
  assert.match(matriz, /NÃO.*mede|não mede/i);
});
