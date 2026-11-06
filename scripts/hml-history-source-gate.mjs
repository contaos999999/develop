import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const manifestPath='supabase/applied-history/hml-source-recovery-20261106.json';
const sha=s=>crypto.createHash('sha256').update(s).digest('hex');
export function validateHistoricalSources(root) {
 const manifest=JSON.parse(fs.readFileSync(path.join(root,manifestPath),'utf8'));
 const errors=[];
 const verify=(file,hash)=>{
  if(!/^(?:supabase\/migrations|supabase\/legacy-migrations)\/\d{14}_[a-z0-9_]+\.sql$/.test(file)){errors.push('Invalid historical path: '+file);return;}
  const target=path.join(root,file);
  if(!fs.existsSync(target)){errors.push('Missing historical file: '+file);return;}
  if(sha(fs.readFileSync(target))!==hash)errors.push('Historical bytes changed: '+file);
 };
 if(manifest.archived.length!==49||manifest.recovered.length!==52||manifest.retained.length!==73)errors.push('Historical inventory count changed');
 for(const x of manifest.archived){
  verify(x.archive_path,x.sha256);
  if(fs.existsSync(path.join(root,x.original_path)))errors.push('Unapplied legacy alias remains executable: '+x.original_path);
 }
 for(const x of manifest.recovered)verify(x.path,x.sha256);
 for(const x of manifest.retained)verify(x.path,x.github_sha256);
 const versions=[...manifest.recovered,...manifest.retained].map(x=>x.version);
 if(new Set(versions).size!==125)errors.push('Historical versions are not unique');
 return errors;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const errors=validateHistoricalSources(process.cwd());
 if(errors.length){console.error(errors.join('\n'));process.exit(1);}
 console.log('HML_SOURCE_HISTORY_PASS: 125 historical versions and 49 archived originals verified by SHA-256; no database mutation');
}
