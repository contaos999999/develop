// P0-ORQ-ACTIONS-001 — CODE fixture only. Never grants execution authority.
import { createHash } from "node:crypto";

const REPO = "contaos999999/develop";
const BACKEND = true;
const ROOT = "docs/executor/";
const PLAN_ROOT = "docs/backend/";
const DISABLED = "HML_DEPLOY_ONE";
const RULESET = 28271968;
const REQUIRED = Object.freeze(["guard"]);
const APP = 15368;
const KEYS = [
  "schema", "request_id", "repository", "mission_id", "operation", "environment",
  "source_sha", "source_pr", "request_pr", "plan_ref", "plan_blob",
  "authorization_ref", "predecessor_checkpoint_ref",
];
const SHA = /^[0-9a-f]{40}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const RAW_LIMIT = 8192;
const MAX_BODY = 2_000_000;
const MAX_PAGES = 10;
const ORIGIN = "https://api.github.com";
const PREFIX = "/repos/" + REPO + "/";
const CHECK_NAMES = new Set(REQUIRED);
const text = (v) => typeof v === "string";
const obj = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
const sha = (v) => text(v) && SHA.test(v);
const uuid = (v) => text(v) && UUID.test(v);
const pos = (v) => Number.isSafeInteger(v) && v > 0;
const time = (v) => text(v) && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(v) ? Date.parse(v) : NaN;
const raw = (v) => JSON.stringify(v) + "\n";
const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const unique = (a) => Array.isArray(a) && new Set(a).size === a.length;
const own = (o, k) => Object.hasOwn(o, k);
class Denial extends Error {
  constructor(reason) { super(reason); this.reason = reason; }
}
const demand = (ok, reason) => { if (!ok) throw new Denial(reason); };
const blocked = (error) => ({
  status: "BLOCKED", executionAllowed: false,
  reason: error instanceof Denial ? error.reason : "UNVERIFIED_EVIDENCE",
});
const fixedCatalog = () => ({
  schema: "contaos.p0.actions-catalog.v1",
  repository: REPO,
  operations: [
    {operation: "CANARY_CODE", environment: "CODE", mode: "CODE_FIXTURE_ONLY", enabled: true},
    {operation: DISABLED, environment: BACKEND ? "HML" : "CODE", mode: "DISABLED", enabled: false},
  ],
});
function decode(input, max = RAW_LIMIT) {
  demand(text(input) && Buffer.byteLength(input, "utf8") <= max, "INVALID_BYTES");
  let value;
  try { value = JSON.parse(input); } catch { throw new Denial("INVALID_JSON"); }
  demand(obj(value), "INVALID_OBJECT");
  return value;
}
function exactKeys(value, keys) {
  return obj(value) && equal(Object.keys(value), keys) && keys.every((k) => own(value, k));
}
export function parseRequest(input, repository) {
  demand(repository === REPO, "WRONG_REPOSITORY");
  const q = decode(input);
  const keys = q.operation === "HML_DEPLOY_ONE" && BACKEND
    ? [...KEYS, "migration_version", "migration_sha256"] : KEYS;
  demand(exactKeys(q, keys) && raw(q) === input, "NONCANONICAL_REQUEST");
  demand(q.schema === "contaos.p0.actions-request.v1" && q.repository === REPO, "REQUEST_IDENTITY");
  demand(uuid(q.request_id) && text(q.mission_id) && /^[A-Z0-9][A-Z0-9_-]{0,79}$/.test(q.mission_id), "INVALID_ID");
  demand([q.source_sha, q.plan_ref, q.plan_blob, q.authorization_ref].every(sha), "INVALID_SHA");
  demand([q.source_pr, q.request_pr, q.predecessor_checkpoint_ref].every(pos) && q.source_pr !== q.request_pr, "INVALID_REFERENCE");
  demand((q.operation === "CANARY_CODE" && q.environment === "CODE") ||
    (q.operation === DISABLED && q.environment === (BACKEND ? "HML" : "CODE")), "INVALID_OPERATION");
  if (BACKEND && q.operation === DISABLED) {
    demand(text(q.migration_version) && /^\d{14}$/.test(q.migration_version) &&
      text(q.migration_sha256) && /^[0-9a-f]{64}$/.test(q.migration_sha256), "INVALID_MIGRATION");
  }
  return q;
}
export function validateCatalog(input, repository) {
  demand(repository === REPO, "WRONG_REPOSITORY");
  decode(input);
  const c = fixedCatalog();
  demand(input === raw(c), "CATALOG_MISMATCH");
  return c;
}
function intent(q) {
  return Object.fromEntries(Object.entries(q).filter(([key]) => key !== "request_pr"));
}
function safePath(p) {
  return text(p) && p.length <= 256 && /^[A-Za-z0-9._/-]+$/.test(p) &&
    !p.startsWith("/") && !p.includes("..") && !p.includes("//") &&
    p.split("/").every((s) => s && s !== ".");
}
function adminPath(p) {
  if (!safePath(p)) return false;
  if ([
    "scripts/p0-actions-request.mjs",
    "scripts/p0-actions-request.test.mjs",
    ".github/workflows/p0-actions-orchestrator-code.yml",
  ].includes(p)) return true;
  return (p.startsWith(ROOT) || p.startsWith(PLAN_ROOT) ||
    (BACKEND && p === "docs/tasks/active-task.json")) && /\.(json|md)$/.test(p);
}
function validateRules(r) {
  demand(obj(r) && r.id === RULESET && r.active === true && r.target === "branch" &&
    r.defaultBranch === true && Array.isArray(r.bypassActors) && r.bypassActors.length === 0 &&
    r.canBypass === "never" && r.pullRequest === true &&
    Number.isSafeInteger(r.approvals) && r.approvals >= (BACKEND ? 1 : 0) &&
    r.strictChecks === true && r.deletion === true && r.nonFastForward === true, "RULESET_UNPROVEN");
  if (BACKEND) demand(r.dismissStale === true && r.lastPushApproval === true &&
    r.reviewThreadResolution === true, "REVIEW_PROTECTION");
  demand(Array.isArray(r.checks) && r.checks.length === REQUIRED.length &&
    unique(r.checks.map((c) => c?.name)) && r.checks.every((c) =>
      CHECK_NAMES.has(c?.name) && c.appId === APP), "REQUIRED_CHECKS_UNPROVEN");
}
function validateMerge(p, number, mergeSha, rules) {
  demand(obj(p) && p.number === number && p.repository === REPO && p.headRepository === REPO &&
    p.baseRef === "main" && p.merged === true && p.mergeSha === mergeSha &&
    [p.mergeSha, p.headSha, p.baseSha, p.tree].every(sha) && p.headSha !== p.baseSha &&
    p.mergeSha !== p.headSha && p.mergeSha !== p.baseSha &&
    equal(p.parents, [p.baseSha, p.headSha]) && text(p.author) &&
    /^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(p.author), "MERGE_IDENTITY");
  const created = time(p.createdAt), merged = time(p.mergedAt);
  demand(Number.isFinite(created) && Number.isFinite(merged) && created < merged, "MERGE_TIME");
  demand(Array.isArray(p.reviews) && p.reviews.length > 0 &&
    p.reviews.every((r) => obj(r) && text(r.actor) && sha(r.commit) &&
      text(r.state) && Number.isFinite(time(r.submittedAt))), "REVIEW_UNPROVEN");
  const candidates = p.reviews.filter((r) => r.eligible === true &&
    r.actor.toLowerCase() === "edivan5002" && r.actor.toLowerCase() !== p.author.toLowerCase() &&
    r.state === "APPROVED" && r.commit === p.headSha &&
    time(r.submittedAt) >= created && time(r.submittedAt) < merged);
  demand(candidates.length > 0, "REVIEW_UNPROVEN");
  const approvedAt = Math.max(...candidates.map((r) => time(r.submittedAt)));
  demand(!p.reviews.some((r) => ["CHANGES_REQUESTED", "DISMISSED"].includes(r.state) &&
    time(r.submittedAt) >= approvedAt && time(r.submittedAt) <= merged), "REVIEW_BLOCKED");
  demand(Array.isArray(p.checks), "CHECK_UNPROVEN");
  for (const requirement of rules.checks) {
    const matching = p.checks.filter((c) => c?.name === requirement.name);
    demand(matching.length === 1, "CHECK_AMBIGUOUS");
    const c = matching[0], started = time(c.startedAt), completed = time(c.completedAt);
    demand(c.appId === requirement.appId && c.sha === p.headSha && c.status === "completed" &&
      c.conclusion === "success" && Number.isFinite(started) && Number.isFinite(completed) &&
      started <= completed && completed <= merged, "CHECK_UNPROVEN");
  }
}
export function authorizeRequest(request, catalog, evidence) {
  try {
    const q = parseRequest(raw(request), REPO);
    validateCatalog(raw(catalog), REPO);
    demand(q.operation === "CANARY_CODE" && q.environment === "CODE", "OPERATION_DISABLED");
    const e = evidence;
    demand(obj(e) && e.repository === REPO && e.requestCommit === e.main?.sha &&
      e.requestCommit === e.request?.mergeSha && e.main?.protected === true &&
      sha(e.main.tree) && e.main.tree === e.request.tree, "STALE_MAIN");
    validateRules(e.ruleset);
    validateMerge(e.source, q.source_pr, q.source_sha, e.ruleset);
    validateMerge(e.request, q.request_pr, e.requestCommit, e.ruleset);
    const now = time(e.now);
    demand(Number.isFinite(now) && time(e.request.mergedAt) <= now &&
      time(e.source.mergedAt) <= time(e.request.mergedAt) && e.sourceAncestor === true, "SOURCE_ANCESTRY");
    const plan = e.plan, auth = e.authorization, requestPath = ROOT + "requests/" + q.request_id + ".json";
    demand(obj(plan) && plan.commit === q.plan_ref && plan.blob === q.plan_blob &&
      plan.protected === true && plan.beforeRequest === true && plan.descendantOfSource === true, "PLAN_UNPROVEN");
    demand(obj(auth) && auth.commit === q.authorization_ref && auth.protected === true &&
      auth.beforeRequest === true && auth.descendantOfSource === true &&
      auth.path === requestPath && auth.reviewed === true && equal(auth.intent, intent(q)) &&
      Number.isFinite(time(auth.expiresAt)) && time(auth.expiresAt) > now, "AUTHORIZATION_UNPROVEN");
    demand(unique(auth.allowedDelta) && auth.allowedDelta.every(adminPath) &&
      unique(e.changedPaths) && e.changedPaths.every(adminPath) &&
      equal([...auth.allowedDelta].sort(), [...e.changedPaths].sort()), "DELTA_OUTSIDE_SCOPE");
    demand(Array.isArray(e.request.files) && e.request.files.length === 1 &&
      e.request.files[0]?.path === requestPath && e.request.files[0]?.status === "added" &&
      e.request.previousExists === false && e.request.raw === raw(q), "REQUEST_NOT_APPEND_ONLY");
    demand(unique(e.consumedIds) && e.consumedIds.every(uuid) && !e.consumedIds.includes(q.request_id), "REPLAY_UNPROVEN");
    return {status: "VALIDATED_FIXTURE", executionAllowed: false, reason: "CODE_FIXTURE_ONLY"};
  } catch (error) { return blocked(error); }
}

// GET adapter: no arbitrary URL, redirect, write operation, output of credentials or shell.
function reader(fetcher, token) {
  const deadline = Date.now() + 30_000;
  let calls = 0;
  async function one(path, query = {}, allow404 = false) {
    demand(text(path) && (safePath(path) || /^compare\/[0-9a-f]{40}\.\.\.[0-9a-f]{40}$/.test(path)), "INVALID_API_PATH");
    const url = new URL(PREFIX + path, ORIGIN);
    for (const [k, v] of Object.entries(query)) url.searchParams.set(k, String(v));
    demand(++calls <= 80 && Date.now() < deadline, "API_BUDGET");
    let response;
    const timeout = Math.min(8000, Math.max(1, deadline - Date.now()));
    try {
      response = await fetcher(url.href, {
        method: "GET", redirect: "error", signal: AbortSignal.timeout(timeout),
        headers: {Accept: "application/vnd.github+json", Authorization: "Bearer " + token,
          "X-GitHub-Api-Version": "2022-11-28"},
      });
    } catch { throw new Denial("API_UNAVAILABLE"); }
    demand(response && response.redirected !== true && !(response.status >= 300 && response.status < 400), "API_REDIRECT");
    if (allow404 && response.status === 404) return {value: null, next: null};
    demand(response.status === 200 && response.body && typeof response.body.getReader === "function", "API_HTTP");
    const length = response.headers.get("content-length");
    demand(!length || (/^\d+$/.test(length) && Number(length) <= MAX_BODY), "API_SIZE");
    const stream = response.body.getReader();
    let bytes = 0;
    const chunks = [];
    try {
      while (true) {
        demand(Date.now() < deadline, "API_BUDGET");
        const item = await stream.read();
        if (item.done) break;
        bytes += item.value.byteLength;
        demand(bytes <= MAX_BODY, "API_SIZE");
        chunks.push(Buffer.from(item.value));
      }
    } catch (error) {
      await stream.cancel().catch(() => {});
      throw error;
    } finally { stream.releaseLock(); }
    let value;
    try { value = JSON.parse(Buffer.concat(chunks).toString("utf8")); } catch { throw new Denial("API_JSON"); }
    const link = response.headers.get("link");
    let next = null;
    if (link) {
      const m = /<([^>]+)>;\s*rel="next"/.exec(link);
      if (m) {
        let u;
        try { u = new URL(m[1]); } catch { throw new Denial("API_PAGINATION"); }
        demand(u.origin === ORIGIN && u.pathname === url.pathname && !u.username && !u.password && !u.hash, "API_PAGINATION");
        const n = Number(u.searchParams.get("page"));
        demand(Number.isSafeInteger(n) && n === Number(query.page ?? 1) + 1, "API_PAGINATION");
        const expected = new URL(url.href); expected.searchParams.set("page", String(n));
        demand(equal([...u.searchParams.entries()].sort(), [...expected.searchParams.entries()].sort()), "API_PAGINATION");
        next = n;
      } else demand(!link.includes('rel="next"'), "API_PAGINATION");
    }
    return {value, next};
  }
  return {
    async get(path, query = {}, allow404 = false) {
      const a = await one(path, query, allow404);
      demand(a.next === null, "API_UNEXPECTED_PAGINATION");
      return a.value;
    },
    async list(path, query = {}, field = null) {
      const out = [];
      let page = 1, total = null;
      while (page !== null) {
        demand(page <= MAX_PAGES, "API_PAGINATION_LIMIT");
        const {value, next} = await one(path, {...query, per_page: 100, page});
        const values = field ? value?.[field] : value;
        demand(Array.isArray(values) && values.length <= 100, "API_INCOMPLETE_LIST");
        if (field) {
          demand(Number.isSafeInteger(value.total_count) && value.total_count >= 0 &&
            value.total_count <= 100 * MAX_PAGES &&
            (total === null || total === value.total_count), "API_INCOMPLETE_LIST");
          total = value.total_count;
        }
        out.push(...values);
        demand(next !== null || values.length < 100 || (total !== null && out.length === total), "API_INCOMPLETE_LIST");
        page = next;
      }
      demand(total === null || out.length === total, "API_INCOMPLETE_LIST");
      return out;
    },
  };
}
function ruleEvidence(r) {
  demand(obj(r) && Array.isArray(r.rules), "RULESET_UNPROVEN");
  const get = (type) => {
    const matches = r.rules.filter((x) => x?.type === type);
    demand(matches.length === 1, "RULESET_UNPROVEN");
    return matches[0].parameters ?? {};
  };
  const pull = get("pull_request"), status = get("required_status_checks");
  get("deletion"); get("non_fast_forward");
  const result = {
    id: r.id, active: r.enforcement === "active", target: r.target,
    defaultBranch: equal(r.conditions?.ref_name?.include, ["~DEFAULT_BRANCH"]) &&
      equal(r.conditions?.ref_name?.exclude, []),
    bypassActors: r.bypass_actors, canBypass: r.current_user_can_bypass,
    pullRequest: true, approvals: pull.required_approving_review_count,
    strictChecks: status.strict_required_status_checks_policy,
    checks: (status.required_status_checks ?? []).map((c) => ({name: c.context, appId: c.integration_id})),
    deletion: true, nonFastForward: true, dismissStale: pull.dismiss_stale_reviews_on_push,
    lastPushApproval: pull.require_last_push_approval,
    reviewThreadResolution: pull.required_review_thread_resolution,
  };
  validateRules(result);
  return result;
}
function gitBlob(file, path) {
  demand(obj(file) && file.type === "file" && file.path === path && file.encoding === "base64" &&
    sha(file.sha) && Number.isSafeInteger(file.size) && file.size >= 0 && file.size <= MAX_BODY &&
    text(file.content), "BLOB_UNPROVEN");
  const encoded = file.content.replace(/\r?\n/g, "");
  demand(/^[A-Za-z0-9+/]*={0,2}$/.test(encoded), "BLOB_UNPROVEN");
  const bytes = Buffer.from(encoded, "base64");
  demand(bytes.length === file.size && bytes.toString("base64") === encoded, "BLOB_UNPROVEN");
  const hash = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  demand(hash === file.sha, "BLOB_UNPROVEN");
  return {hash, raw: bytes.toString("utf8")};
}
function apiPath(p) {
  demand(safePath(p), "INVALID_FILE_PATH");
  return p;
}
async function readMerge(api, number, mergeSha, rules) {
  demand(pos(number) && sha(mergeSha), "MERGE_IDENTITY");
  const pr = await api.get("pulls/" + number);
  demand(pr?.number === number && pr.merge_commit_sha === mergeSha && sha(pr.head?.sha) && sha(pr.base?.sha), "MERGE_IDENTITY");
  const commit = await api.get("commits/" + mergeSha);
  demand(commit?.sha === mergeSha && Array.isArray(commit.parents), "MERGE_IDENTITY");
  const reviews = await api.list("pulls/" + number + "/reviews");
  const runs = await api.list("commits/" + pr.head?.sha + "/check-runs", {filter: "all"}, "check_runs");
  const result = {
    number, repository: pr.base?.repo?.full_name, headRepository: pr.head?.repo?.full_name,
    baseRef: pr.base?.ref, merged: pr.merged, mergeSha, headSha: pr.head?.sha, baseSha: pr.base?.sha,
    parents: commit.parents.map((x) => x.sha), tree: commit.commit?.tree?.sha,
    author: pr.user?.login, createdAt: pr.created_at, mergedAt: pr.merged_at,
    reviews: reviews.map((r) => ({actor: r.user?.login, commit: r.commit_id, state: r.state,
      submittedAt: r.submitted_at, eligible: r.user?.login?.toLowerCase() === "edivan5002" &&
        ["OWNER", "MEMBER", "COLLABORATOR"].includes(r.author_association)})),
    checks: runs.map((c) => ({name: c.name, appId: c.app?.id, sha: c.head_sha,
      status: c.status, conclusion: c.conclusion, startedAt: c.started_at, completedAt: c.completed_at})),
  };
  validateMerge(result, number, mergeSha, rules);
  demand(Number.isSafeInteger(pr.changed_files) && pr.changed_files >= 0 && pr.changed_files < 300, "PR_DIFF_UNPROVEN");
  const files = await api.list("pulls/" + number + "/files");
  demand(files.length === pr.changed_files, "PR_DIFF_UNPROVEN");
  result.files = files.map((f) => ({path: f.filename, status: f.status}));
  return result;
}
async function compare(api, from, to) {
  demand(sha(from) && sha(to), "ANCESTRY_UNPROVEN");
  if (from === to) return [];
  const c = await api.get("compare/" + from + "..." + to, {per_page: 100});
  demand(c?.status === "ahead" && c.merge_base_commit?.sha === from && c.base_commit?.sha === from &&
    c.behind_by === 0 && pos(c.ahead_by) && c.ahead_by <= 100 && c.total_commits === c.ahead_by &&
    Array.isArray(c.commits) && c.commits.length === c.ahead_by &&
    c.commits.at(-1)?.sha === to && Array.isArray(c.files) && c.files.length < 300 &&
    c.files.every((f) => safePath(f.filename) && ["added", "modified"].includes(f.status)), "ANCESTRY_UNPROVEN");
  return c.files.map((f) => f.filename);
}
export async function collectEvidence({request, repository, requestCommit, token, fetcher = fetch} = {}) {
  try {
    const q = parseRequest(raw(request), repository);
    demand(q.operation === "CANARY_CODE" && q.environment === "CODE", "OPERATION_DISABLED");
    demand(sha(requestCommit) && text(token) && token.length > 0 && token.length <= 4096 &&
      !/[\r\n]/.test(token) && typeof fetcher === "function", "API_CREDENTIAL_UNAVAILABLE");
    const api = reader(fetcher, token);
    const initial = await api.get("branches/main");
    demand(initial?.protected === true && initial.commit?.sha === requestCommit, "STALE_MAIN");
    const ruleset = ruleEvidence(await api.get("rulesets/" + RULESET));
    const source = await readMerge(api, q.source_pr, q.source_sha, ruleset);
    const req = await readMerge(api, q.request_pr, requestCommit, ruleset);
    const requestPath = ROOT + "requests/" + q.request_id + ".json";
    const authPath = ROOT + "authorizations/" + q.request_id + ".json";
    const authBlob = gitBlob(await api.get("contents/" + apiPath(authPath), {ref: q.authorization_ref}), authPath);
    const record = decode(authBlob.raw);
    const recordKeys = ["schema","request_path","intent","plan_path","plan_pr","authorization_pr","expires_at","allowed_delta"];
    demand(exactKeys(record, recordKeys) && raw(record) === authBlob.raw &&
      record.schema === "contaos.p0.actions-authorization.v1" && record.request_path === requestPath &&
      safePath(record.plan_path) && record.plan_path.startsWith(PLAN_ROOT) &&
      /\.(md|json)$/.test(record.plan_path) && pos(record.plan_pr) && pos(record.authorization_pr), "AUTHORIZATION_UNPROVEN");
    // A commit cannot contain its own SHA. Derive authorization_ref from the
    // verified commit, never from text in the authorization file itself.
    const embedded = Object.fromEntries(Object.entries(q).filter(([k]) =>
      k !== "request_pr" && k !== "authorization_ref"));
    demand(equal(record.intent, embedded), "AUTHORIZATION_UNPROVEN");
    const planPr = await readMerge(api, record.plan_pr, q.plan_ref, ruleset);
    const authPr = await readMerge(api, record.authorization_pr, q.authorization_ref, ruleset);
    demand(planPr.files.some((f) => f.path === record.plan_path && ["added","modified"].includes(f.status)) &&
      authPr.files.length === 1 && authPr.files[0].path === authPath && authPr.files[0].status === "added", "AUTHORIZATION_UNPROVEN");
    const planBlob = gitBlob(await api.get("contents/" + apiPath(record.plan_path), {ref: q.plan_ref}), record.plan_path);
    demand(planBlob.hash === q.plan_blob, "PLAN_UNPROVEN");
    demand(q.source_sha !== q.plan_ref && q.plan_ref !== q.authorization_ref &&
      q.authorization_ref !== requestCommit && time(planPr.mergedAt) <= time(authPr.mergedAt) &&
      time(authPr.mergedAt) < time(req.mergedAt), "AUTHORIZATION_ORDER");
    await compare(api, q.source_sha, q.plan_ref);
    await compare(api, q.plan_ref, q.authorization_ref);
    await compare(api, q.authorization_ref, req.baseSha);
    const changedPaths = await compare(api, q.source_sha, req.baseSha);
    const existing = await api.get("contents/" + apiPath(requestPath), {ref: req.baseSha}, true);
    const prior = await api.list("commits", {sha: req.baseSha, path: requestPath});
    const requestBlob = gitBlob(await api.get("contents/" + apiPath(requestPath), {ref: requestCommit}), requestPath);
    const final = await api.get("branches/main");
    demand(final?.protected === true && final.commit?.sha === requestCommit &&
      equal(ruleEvidence(await api.get("rulesets/" + RULESET)), ruleset), "STALE_MAIN");
    const evidence = {
      repository, requestCommit, main: {sha: requestCommit, tree: req.tree, protected: true},
      ruleset, source, request: {...req, previousExists: existing !== null, raw: requestBlob.raw},
      plan: {commit: q.plan_ref, blob: planBlob.hash, protected: true, beforeRequest: true, descendantOfSource: true},
      authorization: {commit: q.authorization_ref, protected: true, beforeRequest: true, descendantOfSource: true,
        path: requestPath, intent: intent(q), expiresAt: record.expires_at, reviewed: true, allowedDelta: record.allowed_delta},
      sourceAncestor: true, changedPaths, consumedIds: prior.length ? [q.request_id] : [],
      now: new Date().toISOString(),
    };
    const verdict = authorizeRequest(q, fixedCatalog(), evidence);
    if (verdict.status !== "VALIDATED_FIXTURE") return verdict;
    return {status: "COLLECTED_FIXTURE", executionAllowed: false, evidence};
  } catch (error) { return blocked(error); }
}
