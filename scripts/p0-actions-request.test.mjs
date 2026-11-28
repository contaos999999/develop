import assert from 'node:assert/strict';
import { test } from 'node:test';
import { existsSync } from 'node:fs';

const repo = 'contaos999999/develop';
const disabled = 'HML_DEPLOY_ONE';
const guard = "guard";
const requiredChecks = ["guard"];
const id = '11111111-1111-4111-8111-111111111111';
const sha = (c) => c.repeat(40);
const source = sha('a'), req = sha('b'), plan = sha('c'), auth = sha('d');
const path = 'docs/executor/requests/' + id + '.json';
const raw = (value) => JSON.stringify(value) + '\n';
const request = () => ({
  schema: 'contaos.p0.actions-request.v1',
  request_id: id, repository: repo, mission_id: 'P0-ORQ-ACTIONS-001',
  operation: 'CANARY_CODE', environment: 'CODE', source_sha: source,
  source_pr: 1, request_pr: 2, plan_ref: plan, plan_blob: sha('e'),
  authorization_ref: auth, predecessor_checkpoint_ref: 123
});
const catalog = () => ({
  schema: 'contaos.p0.actions-catalog.v1', repository: repo,
  operations: [
    { operation: 'CANARY_CODE', environment: 'CODE', mode: 'CODE_FIXTURE_ONLY', enabled: true },
    { operation: disabled, environment: 'HML', mode: 'DISABLED', enabled: false }
  ]
});
const merge = (number, mergeSha, headSha, baseSha) => ({
  number, repository: repo, headRepository: repo, baseRef: 'main',
  merged: true, mergeSha, headSha, baseSha, parents: [baseSha, headSha],
  tree: sha('f'), author: 'author', createdAt: '2026-11-27T16:00:00Z', mergedAt: '2026-11-27T18:00:00Z',
  reviews: [{ actor: 'Edivan5002', eligible: true, state: 'APPROVED', commit: headSha, submittedAt: '2026-11-27T17:00:00Z' }],
  checks: requiredChecks.map(name => ({ name, sha: headSha, appId: 15368, status: 'completed', conclusion: 'success', startedAt: '2026-11-27T16:10:00Z', completedAt: '2026-11-27T17:00:00Z' }))
});
const evidence = () => ({
  repository: repo, requestCommit: req, main: { sha: req, tree: sha('f'), protected: true },
  ruleset: { id: 28271968, active: true, target: 'branch', defaultBranch: true,
    bypassActors: [], canBypass: 'never', pullRequest: true, approvals: 1, strictChecks: true,
    checks: requiredChecks.map(name => ({ name, appId: 15368 })), deletion: true, nonFastForward: true,
    dismissStale: true, lastPushApproval: true, reviewThreadResolution: true },
  source: merge(1, source, sha('1'), sha('2')),
  request: { ...merge(2, req, sha('3'), sha('4')), files: [{ path, status: 'added' }], previousExists: false, raw: raw(request()) },
  plan: { commit: plan, blob: sha('e'), protected: true, beforeRequest: true, descendantOfSource: true },
  authorization: { commit: auth, protected: true, beforeRequest: true, descendantOfSource: true,
    path, intent: Object.fromEntries(Object.entries(request()).filter(([key]) => key !== 'request_pr')),
    expiresAt: '2026-11-28T00:00:00Z', reviewed: true, allowedDelta: [] },
  sourceAncestor: true, changedPaths: [], consumedIds: [], now: '2026-11-27T19:00:00Z'
});
async function api() {
  assert.ok(existsSync(new URL('./p0-actions-request.mjs', import.meta.url)), 'RED_CAUSAL_TRANSPORT_VALIDATOR_ABSENT');
  const module = await import('./p0-actions-request.mjs');
  for (const name of ['parseRequest','validateCatalog','authorizeRequest','collectEvidence']) assert.equal(typeof module[name], 'function', name);
  return module;
}
test('positive: canonical closed request and fixed catalog', async () => {
  const m = await api();
  assert.deepEqual(m.parseRequest(raw(request()), repo), request());
  assert.deepEqual(m.validateCatalog(raw(catalog()), repo), catalog());
});
for (const [name, change] of [
  ['extra key', r => {r.command = 'anything';}], ['missing key', r => {delete r.plan_blob;}],
  ['wrong repo', r => {r.repository = 'another/repo';}], ['unknown operation', r => {r.operation = 'RUN_ANY';}],
  ['PROD', r => {r.environment = 'PROD';}], ['unsafe PR', r => {r.source_pr = Number.MAX_SAFE_INTEGER + 1;}],
  ['string PR', r => {r.request_pr = '2';}], ['path traversal', r => {r.mission_id = '../x';}],
  ['invalid UUID', r => {r.request_id = '../x';}], ['uppercase SHA', r => {r.source_sha = sha('A');}],
  ['invalid checkpoint', r => {r.predecessor_checkpoint_ref = 'https://example.org';}]
]) test('schema rejects ' + name, async () => {
  const m = await api(), r = request(); change(r); assert.throws(() => m.parseRequest(raw(r), repo));
});
for (const [name, value] of [
  ['duplicate key', raw(request()).replace('"source_pr":1','"source_pr":1,"source_pr":1')],
  ['noncanonical whitespace', JSON.stringify(request(), null, 2)],
  ['oversize', ' '.repeat(8193)],
  ['invalid JSON', '{bad']
]) test('raw rejects ' + name, async () => {const m = await api(); assert.throws(() => m.parseRequest(value, repo));});
test('catalog rejects enabled operational action and arbitrary keys', async () => {
  const m = await api(); const c = catalog(); c.operations[1].enabled = true;
  assert.throws(() => m.validateCatalog(raw(c), repo));
  const c2 = catalog(); c2.operations[0].command = 'anything';
  assert.throws(() => m.validateCatalog(raw(c2), repo));
});
test('positive fixture validation is not operational authority', async () => {
  const m = await api(); const result = await m.authorizeRequest(request(), catalog(), evidence());
  assert.equal(result.status, 'VALIDATED_FIXTURE'); assert.equal(result.executionAllowed, false);
});
test('disabled operation never authorizes execution', async () => {
  const m = await api(), r = request(); r.operation = disabled; r.environment = 'HML';
  r.migration_version = '20261127233223'; r.migration_sha256 = 'a'.repeat(64);
  const result = await m.authorizeRequest(r, catalog(), evidence()); assert.equal(result.status, 'BLOCKED');
});
const negatives = [
  ['missing authorization', e => {delete e.authorization;}],
  ['authorization mismatch', e => {e.authorization.intent.operation = 'OTHER';}],
  ['authorization expired', e => {e.authorization.expiresAt = '2026-11-26T00:00:00Z';}],
  ['authorization not protected', e => {e.authorization.protected = false;}],
  ['authorization not prior', e => {e.authorization.beforeRequest = false;}],
  ['authorization outside source ancestry', e => {e.authorization.descendantOfSource = false;}],
  ['authorization wrong path', e => {e.authorization.path = '../other';}],
  ['authorization not reviewed', e => {e.authorization.reviewed = false;}],
  ['plan blob mismatch', e => {e.plan.blob = sha('0');}],
  ['plan not prior', e => {e.plan.beforeRequest = false;}],
  ['plan unprotected', e => {e.plan.protected = false;}],
  ['plan outside source ancestry', e => {e.plan.descendantOfSource = false;}],
  ['stale main', e => {e.main.sha = sha('0');}],
  ['wrong tree', e => {e.main.tree = sha('0');}],
  ['unprotected main', e => {e.main.protected = false;}],
  ['missing ruleset', e => {delete e.ruleset;}],
  ['inactive ruleset', e => {e.ruleset.active = false;}],
  ['wrong ruleset target', e => {e.ruleset.defaultBranch = false;}],
  ['bypass actor', e => {e.ruleset.bypassActors = ['actor'];}],
  ['user bypass', e => {e.ruleset.canBypass = 'always';}],
  ['PR not required', e => {e.ruleset.pullRequest = false;}],
  ['missing strict check', e => {e.ruleset.strictChecks = false;}],
  ['missing guard', e => {e.ruleset.checks = [];}],
  ['wrong guard app', e => {e.ruleset.checks[0].appId = 1;}],
  ['no deletion protection', e => {e.ruleset.deletion = false;}],
  ['force push allowed', e => {e.ruleset.nonFastForward = false;}],
  ['source not merged', e => {e.source.merged = false;}],
  ['source wrong repo', e => {e.source.headRepository = 'another/repo';}],
  ['source wrong base', e => {e.source.baseRef = 'other';}],
  ['source wrong merge', e => {e.source.mergeSha = sha('0');}],
  ['source wrong parent', e => {e.source.parents[0] = sha('0');}],
  ['source not ancestor', e => {e.sourceAncestor = false;}],
  ['unapproved delta', e => {e.changedPaths = ['supabase/migrations/extra.sql'];}],
  ['request not merged', e => {e.request.merged = false;}],
  ['request wrong number', e => {e.request.number = 3;}],
  ['request wrong merge', e => {e.request.mergeSha = sha('0');}],
  ['request wrong parents', e => {e.request.parents = [sha('0')];}],
  ['request wrong head repo', e => {e.request.headRepository = 'another/repo';}],
  ['self review', e => {e.request.reviews[0].actor = 'author';}],
  ['ineligible review', e => {e.request.reviews[0].eligible = false;}],
  ['stale approval', e => {e.request.reviews[0].commit = sha('0');}],
  ['later review blocks', e => {e.request.reviews.push({actor:'reviewer',eligible:true,state:'CHANGES_REQUESTED',commit:e.request.headSha,submittedAt:'2026-11-27T17:30:00Z'});}],
  ['approval after merge', e => {e.request.reviews[0].submittedAt = '2026-11-28T00:00:00Z';}],
  ['missing check', e => {e.source.checks = [];}],
  ['failed check', e => {e.request.checks[0].conclusion = 'failure';}],
  ['skipped check', e => {e.request.checks[0].conclusion = 'skipped';}],
  ['neutral check', e => {e.request.checks[0].conclusion = 'neutral';}],
  ['wrong check SHA', e => {e.request.checks[0].sha = sha('0');}],
  ['wrong check app', e => {e.request.checks[0].appId = 1;}],
  ['extra file', e => {e.request.files.push({path:'other',status:'added'});}],
  ['edited request', e => {e.request.files[0].status = 'modified';}],
  ['prior request exists', e => {e.request.previousExists = true;}],
  ['wrong request bytes', e => {e.request.raw += ' ';}],
  ['replay', e => {e.consumedIds = [id];}]
];
negatives.push(['missing required approval', e => {e.ruleset.approvals = 0;}], ['stale not dismissed', e => {e.ruleset.dismissStale = false;}], ['last push not approved', e => {e.ruleset.lastPushApproval = false;}], ['threads unresolved', e => {e.ruleset.reviewThreadResolution = false;}]);
for (const [name, mutate] of negatives) test('evidence rejects ' + name, async () => {
  const m = await api(), e = evidence(); mutate(e); const result = await m.authorizeRequest(request(), catalog(), e);
  assert.equal(result.status, 'BLOCKED'); assert.equal(result.executionAllowed, false); assert.ok(result.reason);
});
for (const [name, response] of [
  ['HTTP error', () => new Response('{}',{status:403})],
  ['redirect', () => new Response('',{status:302,headers:{location:'https://example.org'}})],
  ['oversize', () => new Response('x'.repeat(2_000_001),{status:200})],
  ['pagination outside API', () => new Response('[]',{status:200,headers:{link:'<https://example.org/next>; rel="next"'}})],
  ['timeout', () => {throw new Error('AbortError');}]
]) test('collector fails closed on ' + name, async () => {
  const m = await api(); let calls = 0;
  const result = await m.collectEvidence({request:request(), repository:repo, requestCommit:req, token:'fixture-only', fetcher:async (url, options) => {
    calls++; assert.equal(new URL(url).origin,'https://api.github.com'); assert.equal(options.method,'GET'); assert.equal(options.redirect,'error');
    return response();
  }});
  assert.ok(calls > 0); assert.equal(result.status,'BLOCKED');
});

test('collector rejects incomplete or untrusted evidence without exposing token', async () => {
  const m = await api();
  let calls = 0;
  const result = await m.collectEvidence({
    request: request(), repository: repo, requestCommit: req, token: 'fixture-only',
    fetcher: async (url, options) => {
      calls++;
      assert.equal(new URL(url).origin, 'https://api.github.com');
      assert.equal(options.method, 'GET');
      assert.equal(options.redirect, 'error');
      assert.ok(options.signal);
      return new Response(JSON.stringify({protected:true,commit:{sha:req}}), {status:200});
    }
  });
  assert.ok(calls > 0);
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.executionAllowed, false);
  assert.ok(!JSON.stringify(result).includes('fixture-only'));
});
for (const [name, mutate] of [
  ['source invalid author', e => {e.source.author = '';}],
  ['source invalid tree', e => {e.source.tree = 'not-a-sha';}],
  ['wrong plan commit', e => {e.plan.commit = sha('0');}],
  ['wrong authorization commit', e => {e.authorization.commit = sha('0');}],
  ['ambiguous duplicate check', e => {e.request.checks.push({...e.request.checks[0]});}],
  ['check after merge', e => {e.request.checks[0].completedAt = '2026-11-28T00:00:00Z';}],
  ['dangerous authorized delta', e => {e.changedPaths = ['supabase/migrations/x.sql']; e.authorization.allowedDelta = [...e.changedPaths];}],
  ['unknown request commit', e => {e.requestCommit = sha('0');}],
  ['missing required checks', e => {e.ruleset.checks.pop();}],
  ['invalid rule id', e => {e.ruleset.id = 999;}],
  ['expired authorization malformed date', e => {e.authorization.expiresAt = 'invalid';}],
  ['self-authorized review', e => {e.source.reviews[0].actor = e.source.author;}],
  ['invalid evidence timestamp', e => {e.now = 'invalid';}]
]) test('additional evidence rejects ' + name, async () => {
  const m = await api(), e = evidence(); mutate(e);
  const result = await m.authorizeRequest(request(), catalog(), e);
  assert.equal(result.status, 'BLOCKED');
  assert.equal(result.executionAllowed, false);
});
