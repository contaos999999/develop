import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const file='supabase/migrations/20261108054500_fix_document_upload_wrapper.sql';
test('document upload wrapper change is a single exact security attribute',()=>{
 assert.ok(fs.existsSync(file),'new additive wrapper migration required');
 const sql=fs.readFileSync(file,'utf8').replace(/^--.*$/gm,'').trim();
 assert.equal(sql,'ALTER FUNCTION public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) SECURITY DEFINER;');
});
