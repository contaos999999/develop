import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateHistoricalSources } from './hml-history-source-gate.mjs';
const manifest=JSON.parse(fs.readFileSync('supabase/applied-history/hml-source-recovery-20261106.json','utf8'));
test('historical source inventory is intact',()=>assert.deepEqual(validateHistoricalSources(process.cwd()),[]));
function fixture(fn){const root=fs.mkdtempSync(path.join(os.tmpdir(),'contaos-history-'));try{fs.cpSync('supabase',path.join(root,'supabase'),{recursive:true});fn(root);}finally{fs.rmSync(root,{recursive:true,force:true});}}
test('tampering with recovered SQL is rejected',()=>fixture(root=>{fs.appendFileSync(path.join(root,manifest.recovered[0].path),'-- changed');assert.ok(validateHistoricalSources(root).some(x=>x.includes('Historical bytes changed')));}));
test('missing archive is rejected',()=>fixture(root=>{fs.rmSync(path.join(root,manifest.archived[0].archive_path));assert.ok(validateHistoricalSources(root).some(x=>x.includes('Missing historical file')));}));
test('unapplied alias cannot re-enter migrations',()=>fixture(root=>{fs.copyFileSync(path.join(root,manifest.archived[0].archive_path),path.join(root,manifest.archived[0].original_path));assert.ok(validateHistoricalSources(root).some(x=>x.includes('remains executable')));}));
