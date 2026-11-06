import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { webcrypto } from 'node:crypto';
import { test } from 'node:test';
import assert from 'node:assert/strict';

// Test the real handler. Only external Supabase transport is substituted.
async function invoke(rbac, rpcError = null) {
  let handler; let signed = 0;
  const admin = { storage: { from: () => ({ createSignedUploadUrl: async () => {
    signed++; return { data: { token: 'test-upload-token', signedUrl: 'https://example.invalid/upload' }, error: null };
  } }) } };
  const caller = {
    auth: { getUser: async () => ({ data: { user: { id: 'fixture' } }, error: null }) },
    rpc: async () => ({ data: rbac, error: rpcError }),
    from: (table) => {
      const chain = { select: () => chain, eq: () => chain,
        maybeSingle: async () => ({ data: { id: 'org' } }),
        single: async () => ({ data: table === 'configuracao_upload' ? {
          extensoes_permitidas: ['pdf'], mimes_permitidos: ['application/pdf'], tamanho_maximo_bytes: 1000, limiar_upload_resumivel_bytes: 100
        } : null, error: null }) };
      return chain;
    }
  };
  let clients = 0;
  let source = readFileSync(new URL('../functions/storage-sign-upload/index.ts', import.meta.url), 'utf8');
  source = source.split('\n').filter(line => !line.startsWith('import ')).join('\n');
  runInNewContext(stripTypeScriptTypes(source), {
    Deno: { env: { get: () => 'test-configuration' }, serve: (fn) => { handler = fn; } },
    createClient: () => clients++ === 0 ? admin : caller,
    Response, Request, TextDecoder, Uint8Array, crypto: webcrypto,
  });
  const response = await handler(new Request('https://example.invalid', { method: 'POST',
    headers: { authorization: 'Bearer test-session', 'content-type': 'application/json' },
    body: JSON.stringify({ id_organizacao: 'org', nome_arquivo: 'test.pdf', mime: 'application/pdf', tamanho: 12 }) }));
  return { status: response.status, body: await response.json(), signed };
}
for (const [name, data, error] of [
  ['permission revoked', { permissoes: [] }, null],
  ['backend permission error', null, { code: '42501' }],
  ['malformed permission response', {}, null],
  ['wrong action', { permissoes: [{ recurso: 'arquivos', acao: 'consultar' }] }, null],
  ['wrong resource', { permissoes: [{ recurso: 'contratos', acao: 'criar' }] }, null],
]) {
  test('upload signer denies ' + name, async () => {
    const result = await invoke(data, error);
    assert.equal(result.status, 403);
    assert.equal(result.body.ok, false);
    assert.equal(result.signed, 0, 'No privileged signed-upload call on denial');
    assert.equal(result.body.signed_url, undefined);
    assert.equal(result.body.token, undefined);
  });
}
test('upload signer allows confirmed contextual create permission', async () => {
  const result = await invoke({ permissoes: [{ recurso: 'arquivos', acao: 'criar' }] });
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.signed, 1);
});
