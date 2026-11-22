import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const root = 'supabase/functions/';
const expected = [
  'admin-invite-user', 'contaos-worker', 'copilot-query', 'deliver-webhook',
  'evidence-access', 'export-migration-history', 'generate-report',
  'notify-user', 'openai-capabilities-healthcheck', 'openai-healthcheck',
  'openai-model-healthcheck', 'process-document', 'queue-worker-ai',
  'queue-worker-documents', 'queue-worker-embeddings', 'queue-worker-finance',
  'queue-worker-historico', 'queue-worker-ocr', 'storage-sign-download',
  'storage-sign-upload'
];
const js = new Set(['evidence-access','generate-report','notify-user','queue-worker-documents']);
const fileOf = slug => root + slug + '/index.' + (js.has(slug) ? 'js' : 'ts');
test('GREEN source inventory: all twenty HML Edge entrypoints are versioned', () => {
  assert.equal(expected.length, 20);
  assert.equal(new Set(expected).size, 20);
  for (const slug of expected) assert.equal(existsSync(fileOf(slug)), true, slug);
});
test('GREEN provenance: historic worker retains internal-token check and service-role isolation', () => {
  const s = readFileSync(fileOf('queue-worker-historico'), 'utf8');
  assert.match(s, /req\.method\s*!==\s*'POST'/);
  assert.match(s, /x-contaos-internal-token/);
  assert.match(s, /validar_token_interno/);
  assert.match(s, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.match(s, /worker_pull_historico_hml/);
  assert.doesNotMatch(s, /(?:sb_secret_|sb_service_role_|sk-)[A-Za-z0-9_-]{20,}/);
});
test('GREEN finance: canonical worker rejects literal RTF signature with real backslash', () => {
  const s = readFileSync(fileOf('queue-worker-finance'), 'utf8');
  const slash = String.fromCharCode(92), rtf = String.fromCharCode(123,92,114,116,102,49);
  const good = "inicio.startsWith('{"+slash+slash+"rtf')";
  const bad = "inicio.startsWith('{"+slash+"rtf')";
  assert.equal(s.includes(good), true, 'source must carry two escape backslashes');
  assert.equal(s.includes(bad), false, 'single escaped CR literal would fail to reject RTF');
  assert.equal(rtf.startsWith('{'+slash+'rtf'), true);
  assert.equal(rtf.startsWith('{'+String.fromCharCode(13)+'tf'), false);
});
test('GREEN notify-user: no functional source drift due to missing final line feed', () => {
  const s = readFileSync(fileOf('notify-user'), 'utf8');
  assert.ok(s.endsWith(String.fromCharCode(10)));
  assert.equal(s.endsWith(String.fromCharCode(10,10)), false);
});
