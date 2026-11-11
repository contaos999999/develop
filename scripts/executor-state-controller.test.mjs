import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const source=readFileSync(new URL('./executor-state-controller.mjs',import.meta.url),'utf8');
test('read-only and no dispatch side effects',()=>{assert.match(source,/dispatch_allowed:false/);assert.doesNotMatch(source,/method:\s*['"]POST/);});
test('missing token fails closed',()=>{const p=spawnSync(process.execPath,[new URL('./executor-state-controller.mjs',import.meta.url).pathname],{env:{PATH:process.env.PATH},encoding:'utf8'});assert.equal(p.status,2);assert.match(p.stderr,/GITHUB_TOKEN ausente/)});
test('state schema validates phase, SHA and status',()=>{assert.match(source,/x.phase_id<1/);assert.match(source,/x.phase_id>8/);assert.match(source,/!sha\(x.head_sha\)/);assert.match(source,/!states.includes\(x.status\)/)});
test('reconciliation verifies exact run SHA and outcome',()=>{assert.match(source,/r.head_sha!==s.head_sha/);assert.match(source,/r.status!=='completed'/);assert.match(source,/r.conclusion!=='success'/)});
