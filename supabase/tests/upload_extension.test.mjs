import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const path='supabase/migrations/20261108053000_fix_upload_extension_extraction.sql';
const base=fs.readFileSync('supabase/migrations/20261106014102_p0_v1_rbac_persistente.sql','utf8');
function definition(s){return s.match(/CREATE OR REPLACE FUNCTION privado[.]confirmar_upload_arquivo[\s\S]*?\$function\$\s*;/)?.[0];}
test('extension correction preserves entire certified RPC except extension expression',()=>{
 assert.ok(fs.existsSync(path),'new additive migration is required');
 const next=fs.readFileSync(path,'utf8');
 const old=definition(base); const actual=definition(next);
 assert.ok(old); assert.ok(actual);
 const expression="  v_ext := lower(coalesce(substring(p_nome_original from '[.]([^.]*)$'),''));";
 assert.equal(actual,old.replace(/  v_ext := [^\n]+;/,()=>expression));
 assert.equal((next.match(/CREATE OR REPLACE FUNCTION/g)||[]).length,1);
 assert.doesNotMatch(next,/\b(?:grant|revoke|drop|alter|delete|update|truncate)\s/i);
});
