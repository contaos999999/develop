import fs from 'node:fs';
import { execSync } from 'node:child_process';

const task = JSON.parse(fs.readFileSync('docs/tasks/active-task.json','utf8'));
const changedEnv = process.env.ZERO_DRIFT_CHANGED_FILES?.trim();
let changed = [];
if (changedEnv) changed = changedEnv.split('\n').filter(Boolean);
else {
  try { changed = execSync('git diff --name-only HEAD~1..HEAD',{encoding:'utf8'}).trim().split('\n').filter(Boolean); }
  catch { changed = []; }
}
const esc = s => s.replace(/[.+^${}()|[\]\\]/g,'\\$&').replaceAll('**','§§').replaceAll('*','[^/]*').replaceAll('§§','.*');
const match = (path,patterns=[]) => patterns.some(p => new RegExp('^'+esc(p)+'$').test(path));
const forbidden = changed.filter(f=>match(f,task.forbidden_paths));
const outside = changed.filter(f=>!match(f,task.allowed_paths));
const sql = changed.filter(f=>f.startsWith('supabase/migrations/') && f.endsWith('.sql'));
const edge = changed.filter(f=>f.startsWith('supabase/functions/'));
const errors=[];
if(forbidden.length) errors.push('Arquivos proibidos alterados: '+forbidden.join(', '));
if(outside.length) errors.push('Arquivos fora do escopo: '+outside.join(', '));
if(sql.length && !task.database_changes_allowed) errors.push('Mudança de banco não autorizada pelo manifesto.');
if(edge.length && !task.edge_function_changes_allowed) errors.push('Mudança de Edge Function não autorizada pelo manifesto.');
if(errors.length){ console.error(errors.join('\n')); process.exit(1); }
console.log(`Zero-Drift PASS: ${changed.length} arquivo(s) dentro do manifesto ${task.id}.`);
