import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { webcrypto } from 'node:crypto';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const origins = ['http://127.0.0.1:4173', 'https://scope-and-approval-keeper.lovable.app', 'https://contaos-41-hml.vercel.app'];
const requestHeaders = ['authorization', 'x-client-info', 'apikey', 'content-type'];
const endpoints = ['upload', 'download'];
const uploadBody = { id_organizacao: 'org-fixture', id_contrato: 'contract-fixture', nome_arquivo: 'Relatório final.pdf', mime: 'application/pdf', tamanho: 12 };
const downloadBody = { id_arquivo: 'file-fixture' };
const defaultConfig = { extensoes_permitidas: ['pdf'], mimes_permitidos: ['application/pdf'], tamanho_maximo_bytes: 1000, limiar_upload_resumivel_bytes: 100 };
const clone = value => JSON.parse(JSON.stringify(value));

// Execute each complete real handler, substituting only external Supabase transport.
// Calls record the boundary at which auth, RLS, RBAC or Storage would execute.
function load(endpoint, fixture = {}) {
  let handler;
  const calls = []; const clients = [];
  const result = (data, error = null) => ({ data, error });
  const storage = sender => ({ from(bucket) {
    calls.push({ op: 'storage', sender, bucket });
    return {
      async createSignedUploadUrl(path, options) {
        calls.push({ op: 'sign-upload', sender, path, options: clone(options) });
        return fixture.signError ? result(null, { code: 'fixture-denied' }) : result({ token: 'synthetic-token', signedUrl: 'https://example.invalid/upload' });
      },
      async createSignedUrl(path, seconds, options) {
        calls.push({ op: 'sign-download', sender, path, seconds, options: clone(options) });
        return fixture.signError ? result(null, { code: 'fixture-denied' }) : result({ signedUrl: 'https://example.invalid/download' });
      },
    };
  } });
  const caller = {
    auth: { async getUser() {
      calls.push({ op: 'getUser' });
      return fixture.invalidSession ? result({ user: null }, { code: 'fixture-expired' }) : result({ user: { id: 'user-fixture' } });
    } },
    async rpc(name, payload) {
      calls.push({ op: 'rpc', name, payload: clone(payload) });
      if (fixture.rpcThrows) throw new Error('synthetic transport failure');
      return result(fixture.rbac ?? { permissoes: [{ recurso: 'arquivos', acao: 'criar' }] }, fixture.rpcError ?? null);
    },
    from(table) {
      calls.push({ op: 'from', table });
      const chain = {
        select(columns) { calls.push({ op: 'select', table, columns }); return chain; },
        eq(column, value) { calls.push({ op: 'eq', table, column, value }); return chain; },
        async maybeSingle() {
          calls.push({ op: 'maybeSingle', table });
          if (table === 'organizacoes') return result(fixture.noOrg ? null : { id: 'org-fixture' });
          if (table === 'contratos') return result(fixture.noContract ? null : { id: 'contract-fixture', id_organizacao: 'org-fixture' });
          if (table === 'arquivos') return result(fixture.noFile ? null : { id: 'file-fixture', bucket: 'contaos-documentos', path: 'fixture-only/object', nome_original: fixture.filename ?? 'Relatório final.pdf' }, fixture.fileError ?? null);
          throw new Error('Unexpected fixture table');
        },
        async single() {
          calls.push({ op: 'single', table });
          assert.equal(table, 'configuracao_upload');
          return fixture.noConfig ? result(null, { code: 'fixture-missing' }) : result(fixture.config ?? defaultConfig);
        },
      };
      return chain;
    },
    storage: storage('caller'),
  };
  const admin = { storage: storage('admin') };
  let source = readFileSync(new URL(`../functions/storage-sign-${endpoint}/index.ts`, import.meta.url), 'utf8');
  source = source.split('\n').filter(line => !line.startsWith('import ')).join('\n');
  runInNewContext(stripTypeScriptTypes(source), {
    Deno: { env: { get: name => ({ SUPABASE_URL: 'https://supabase.example.invalid', SUPABASE_ANON_KEY: 'public-fixture', SUPABASE_SERVICE_ROLE_KEY: 'private-fixture' })[name] }, serve: fn => { handler = fn; } },
    createClient(url, key, options) { clients.push(clone({ url, key, options })); return key === 'private-fixture' ? admin : caller; },
    Response, Request, TextDecoder, Uint8Array, crypto: webcrypto,
  });
  return { calls, clients, async invoke(options = {}) {
    const { method = 'POST', origin, headers = {}, body = endpoint === 'upload' ? uploadBody : downloadBody, raw, auth = true } = options;
    const combined = { ...(auth ? { authorization: 'Bearer synthetic-session' } : {}), ...headers };
    if (origin !== undefined) combined.origin = origin;
    const req = new Request('https://example.invalid/function', { method, headers: combined,
      ...(!['GET', 'HEAD'].includes(method) ? { body: raw ?? JSON.stringify(body) } : {}) });
    return handler(req);
  } };
}
function common(response) {
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(response.headers.get('access-control-allow-credentials'), null);
  assert.equal(response.headers.get('access-control-expose-headers'), null);
  assert.equal(response.headers.get('access-control-max-age'), null);
  assert.ok(response.headers.get('vary')?.toLowerCase().split(/\s*,\s*/).includes('origin'));
}
function cors(response, origin) {
  common(response);
  assert.equal(response.headers.get('access-control-allow-origin'), origin ?? null);
}
async function jsonError(response, status, code, origin) {
  assert.equal(response.status, status);
  cors(response, origin);
  assert.match(response.headers.get('content-type'), /^application\/json/);
  const body = await response.json();
  assert.equal(body.ok, false);
  assert.equal(body.codigo, code);
  assert.equal(body.signed_url, undefined);
  assert.equal(body.token, undefined);
  return body;
}
const invalidOrigins = [
  'http://contaos-41-hml.vercel.app', 'https://contaos-41-hml.vercel.app:444',
  'https://contaos-41-hml.vercel.app.evil.invalid', 'https://contaos-41-hml.vercel.app/',
  'https://contaos-41-hml.vercel.app/path', 'https://user@contaos-41-hml.vercel.app',
  'https://CONTAOS-41-HML.vercel.app', 'https://contaos-41-gracjjtr1-contaos9999.vercel.app',
  '', 'null', 'undefined', '*', 'http://localhost:4173', 'http://127.0.0.1:4174', 'https://127.0.0.1:4173',
  'http://127.0.0.1:4173/', 'http://127.0.0.1:4173/path', 'http://user@127.0.0.1:4173',
  'http://scope-and-approval-keeper.lovable.app', 'https://scope-and-approval-keeper.lovable.app:444',
  'https://scope-and-approval-keeper.lovable.app.evil.invalid', 'https://preview--scope-and-approval-keeper.lovable.app',
  'https://scope-and-approval-keeper.lovable.app/', 'https://SCOPE-AND-APPROVAL-KEEPER.lovable.app',
  origins.join(', '), origins.join(' '), 'not-an-origin',
];

for (const endpoint of endpoints) {
  for (const origin of origins) {
    // Removing OPTIONS handling, widening a method/header, or executing auth before
    // negotiation must fail these literal HTTP and external-effect assertions.
    for (let mask = 0; mask < 16; mask++) {
      test(`${endpoint}: exact origin ${origins.indexOf(origin)} preflight accepts header subset ${mask}`, async () => {
        const app = load(endpoint);
        const subset = requestHeaders.filter((_, bit) => mask & (1 << bit));
        const response = await app.invoke({ method: 'OPTIONS', origin, auth: false, headers: {
          'access-control-request-method': 'POST', ...(subset.length ? { 'access-control-request-headers': subset.join(', ') } : {}),
        } });
        assert.equal(response.status, 204);
        assert.equal(await response.text(), '');
        cors(response, origin);
        assert.equal(response.headers.get('access-control-allow-methods'), 'POST, OPTIONS');
        assert.deepEqual(response.headers.get('access-control-allow-headers')?.split(/\s*,\s*/), requestHeaders);
        const vary = response.headers.get('vary').toLowerCase().split(/\s*,\s*/);
        assert.ok(vary.includes('access-control-request-method'));
        assert.ok(vary.includes('access-control-request-headers'));
        assert.deepEqual(app.calls, []);
        assert.equal(app.clients.length, endpoint === 'upload' ? 1 : 0, 'Only module initialization can create admin client');
      });
    }
    test(`${endpoint}: requested header names are case insensitive`, async () => {
      const app = load(endpoint);
      const response = await app.invoke({ method: 'OPTIONS', origin, headers: { 'access-control-request-method': 'POST', 'access-control-request-headers': 'Authorization, X-Client-Info, APIKEY, Content-Type' } });
      assert.equal(response.status, 204); cors(response, origin); assert.deepEqual(app.calls, []);
    });
  }
  for (const origin of invalidOrigins) {
    test(`${endpoint}: rejects unapproved origin ${JSON.stringify(origin)} without effects`, async () => {
      for (const method of ['OPTIONS', 'POST']) {
        const app = load(endpoint);
        const response = await app.invoke({ method, origin, headers: { 'access-control-request-method': 'POST', 'access-control-request-headers': requestHeaders.join(', ') } });
        assert.equal(response.status, 403);
        cors(response);
        if (method === 'POST') assert.equal((await response.json()).codigo, 'AUTH_ACESSO_NEGADO');
        assert.deepEqual(app.calls, []);
      }
    });
  }
  for (const headers of [
    {}, { 'access-control-request-method': 'GET' }, { 'access-control-request-method': 'OPTIONS' },
    { 'access-control-request-method': 'post' }, { 'access-control-request-method': 'POST, PUT' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': 'authorization, x-region' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': '*' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': 'content-type,,apikey' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': 'authorization, ' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': '' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': 'authorization apikey' },
    { 'access-control-request-method': 'POST', 'access-control-request-headers': 'x-trace-id' },
  ]) {
    test(`${endpoint}: invalid negotiation ${JSON.stringify(headers)} has no allow-origin or effects`, async () => {
      for (const origin of origins) {
        const app = load(endpoint);
        const response = await app.invoke({ method: 'OPTIONS', origin, headers });
        assert.equal(response.status, 403); cors(response); assert.deepEqual(app.calls, []);
      }
    });
  }
  for (const method of ['GET', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS']) {
    test(`${endpoint}: actual ${method} preserves 405 and its JSON contract`, async () => {
      for (const origin of [...origins, undefined, 'https://evil.invalid']) {
        if (method === 'OPTIONS' && origin !== undefined) continue;
        const app = load(endpoint);
        const response = await app.invoke({ method, origin });
        const body = await jsonError(response, 405, 'METODO_INVALIDO', origins.includes(origin) ? origin : undefined);
        assert.equal(body.mensagem, `Use esta função apenas para solicitar autorização de ${endpoint}.`);
        assert.deepEqual(app.calls, []);
      }
    });
  }
  const errors = [
    ['missing authorization', { auth: false }, {}, 401, 'AUTH_NAO_AUTENTICADO'],
    ['invalid JSON', { raw: '{' }, {}, 400, 'DADOS_INVALIDOS'],
    ['required fields', { body: {} }, {}, 400, 'CAMPO_OBRIGATORIO'],
    ['stream body above 8 KiB', { raw: ' '.repeat(8193) }, {}, 413, 'REQUISICAO_MUITO_GRANDE'],
    ['declared body above 8 KiB', { headers: { 'content-length': '8193' } }, {}, 413, 'REQUISICAO_MUITO_GRANDE'],
    ['Storage denial', {}, { signError: true }, 400, 'ARQUIVO_UPLOAD_FALHOU'],
    ...(endpoint === 'upload' ? [
      ['invalid session', {}, { invalidSession: true }, 401, 'AUTH_SESSAO_INVALIDA'],
      ['organization denial', {}, { noOrg: true }, 403, 'AUTH_ACESSO_NEGADO'],
      ['contract denial', {}, { noContract: true }, 403, 'AUTH_ACESSO_NEGADO'],
      ['revoked RBAC', {}, { rbac: { permissoes: [] } }, 403, 'AUTH_ACESSO_NEGADO'],
      ['RBAC error', {}, { rpcError: { code: '42501' } }, 403, 'AUTH_ACESSO_NEGADO'],
      ['RBAC transport error', {}, { rpcThrows: true }, 403, 'AUTH_ACESSO_NEGADO'],
      ['missing upload config', {}, { noConfig: true }, 503, 'CONFIGURACAO_INDISPONIVEL'],
      ['extension denied', { body: { ...uploadBody, nome_arquivo: 'fixture.exe' } }, {}, 400, 'ARQUIVO_TIPO_NAO_SUPORTADO'],
      ['MIME denied', { body: { ...uploadBody, mime: 'application/octet-stream' } }, {}, 400, 'ARQUIVO_TIPO_NAO_SUPORTADO'],
      ['size denied', { body: { ...uploadBody, tamanho: 1001 } }, {}, 400, 'ARQUIVO_MUITO_GRANDE'],
    ] : [
      ['RLS invisibility', {}, { noFile: true }, 404, 'REGISTRO_NAO_ENCONTRADO'],
      ['RLS transport denial', {}, { fileError: { code: '42501' } }, 404, 'REGISTRO_NAO_ENCONTRADO'],
    ]),
  ];
  for (const [name, options, fixture, status, code] of errors) {
    test(`${endpoint}: ${name} preserves status/code with both CORS origins and no Origin`, async () => {
      for (const origin of [...origins, undefined]) {
        const app = load(endpoint, fixture);
        await jsonError(await app.invoke({ ...options, origin }), status, code, origin);
        if (name !== 'Storage denial') assert.ok(!app.calls.some(call => call.op.startsWith('sign-')));
      }
    });
  }
  test(`${endpoint}: 8 KiB exact JSON boundary remains accepted`, async () => {
    const raw = JSON.stringify(endpoint === 'upload' ? uploadBody : downloadBody);
    const bytes = new TextEncoder().encode(raw).byteLength;
    for (const origin of [...origins, undefined]) {
      const app = load(endpoint);
      const response = await app.invoke({ origin, raw: raw + ' '.repeat(8192 - bytes) });
      assert.equal(response.status, 200); cors(response, origin);
    }
  });
  test(`${endpoint}: Host and Referer cannot authorize an unapproved Origin`, async () => {
    const app = load(endpoint);
    const response = await app.invoke({ origin: 'https://evil.invalid', headers: { host: '127.0.0.1:4173', referer: origins[0] } });
    await jsonError(response, 403, 'AUTH_ACESSO_NEGADO'); assert.deepEqual(app.calls, []);
  });
  test(`${endpoint}: approved Origin never bypasses missing authorization`, async () => {
    for (const origin of origins) {
      const app = load(endpoint);
      await jsonError(await app.invoke({ origin, auth: false }), 401, 'AUTH_NAO_AUTENTICADO', origin);
      assert.deepEqual(app.calls, []);
    }
  });
  test(`${endpoint}: successful POST keeps payload and caller authorization`, async () => {
    for (const origin of [...origins, undefined]) {
      const app = load(endpoint);
      const response = await app.invoke({ origin });
      assert.equal(response.status, 200); cors(response, origin);
      assert.equal(response.headers.get('access-control-allow-methods'), null);
      assert.equal(response.headers.get('access-control-allow-headers'), null);
      const body = await response.json();
      assert.equal(body.ok, true);
      const publicClient = app.clients.find(client => client.key === 'public-fixture');
      assert.equal(publicClient.options.global.headers.Authorization, 'Bearer synthetic-session');
      assert.deepEqual(publicClient.options.auth, { persistSession: false, autoRefreshToken: false });
      if (endpoint === 'upload') {
        assert.equal(body.bucket, 'contaos-documentos'); assert.equal(body.token, 'synthetic-token');
        assert.equal(body.signed_url, 'https://example.invalid/upload'); assert.equal(body.usar_upload_resumivel, false);
        assert.equal(body.limiar_upload_resumivel_bytes, 100);
        assert.match(body.path, /^org-fixture\/uploads\/[0-9a-f-]{36}\/Relatorio-final.pdf$/);
        const signed = app.calls.find(call => call.op === 'sign-upload');
        assert.equal(signed.sender, 'admin'); assert.equal(signed.path, body.path); assert.deepEqual(signed.options, { upsert: false });
        assert.deepEqual(app.calls.find(call => call.op === 'rpc'), { op: 'rpc', name: 'consultar_permissoes_efetivas', payload: { p_id_organizacao: 'org-fixture', p_id_contrato: 'contract-fixture' } });
        const steps = app.calls.map(call => call.op);
        assert.ok(steps.indexOf('getUser') < steps.indexOf('rpc'));
        assert.ok(steps.indexOf('rpc') < steps.indexOf('sign-upload'));
        assert.deepEqual(app.calls.filter(call => call.op === 'eq').map(({ table, column, value }) => ({ table, column, value })), [
          { table: 'organizacoes', column: 'id', value: 'org-fixture' },
          { table: 'contratos', column: 'id', value: 'contract-fixture' },
          { table: 'contratos', column: 'id_organizacao', value: 'org-fixture' },
          { table: 'configuracao_upload', column: 'id', value: true },
        ]);
      } else {
        assert.equal(app.clients.length, 1); assert.equal(body.signed_url, 'https://example.invalid/download');
        assert.equal(body.nome_arquivo, 'Relatório final.pdf'); assert.equal(body.timezone, 'Horário de Brasília');
        assert.match(body.valido_ate, /^\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}$/);
        assert.deepEqual(app.calls.find(call => call.op === 'select'), { op: 'select', table: 'arquivos', columns: 'id,bucket,path,nome_original' });
        assert.deepEqual(app.calls.find(call => call.op === 'eq'), { op: 'eq', table: 'arquivos', column: 'id', value: 'file-fixture' });
        assert.deepEqual(app.calls.find(call => call.op === 'sign-download'), { op: 'sign-download', sender: 'caller', path: 'fixture-only/object', seconds: 600, options: { download: 'Relatório final.pdf' } });
        assert.ok(app.calls.findIndex(call => call.op === 'maybeSingle') < app.calls.findIndex(call => call.op === 'sign-download'));
      }
    }
  });
}
test('upload: resumable threshold and optional contract remain unchanged', async () => {
  const app = load('upload');
  const response = await app.invoke({ origin: origins[0], body: { ...uploadBody, id_contrato: null, tamanho: 100 } });
  assert.equal(response.status, 200); assert.equal((await response.json()).usar_upload_resumivel, true);
  assert.equal(app.calls.find(call => call.op === 'rpc').payload.p_id_contrato, null);
  assert.ok(!app.calls.some(call => call.table === 'contratos'));
});
test('download: expiry clamps and filename sanitization preserve safe Storage arguments', async () => {
  for (const [requested, seconds] of [[0, 60], [59, 60], [3601, 3600]]) {
    const app = load('download', { filename: '../../relatorio.pdf\r\nX-Test: injected' });
    const response = await app.invoke({ origin: origins[1], body: { ...downloadBody, validade_segundos: requested } });
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.nome_arquivo, '_.._relatorio.pdf_X-Test_ injected');
    assert.deepEqual(app.calls.find(call => call.op === 'sign-download').options, { download: '_.._relatorio.pdf_X-Test_ injected' });
    assert.equal(app.calls.find(call => call.op === 'sign-download').seconds, seconds);
  }
});
