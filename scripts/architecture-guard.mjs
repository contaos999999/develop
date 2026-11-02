import fs from 'node:fs';
import { execSync } from 'node:child_process';

const files = execSync('git ls-files',{encoding:'utf8'}).trim().split('\n').filter(Boolean);
const selfExcluded = new Set([
  'scripts/architecture-guard.mjs',
  '.github/workflows/zero-drift.yml',
  '.github/workflows/sync-hml-history.yml'
]);
const textFiles=files.filter(f=>!selfExcluded.has(f) && !f.match(/\.(png|jpg|jpeg|gif|pdf|zip|docx|xlsx|pptx)$/i));
const errors=[];
for(const f of textFiles){
  let s=''; try{s=fs.readFileSync(f,'utf8')}catch{continue}
  const isEnv=/^\.env(?:\.|$)/.test(f) && f!=='.env.example';
  if(isEnv && /^(?:SUPABASE_SERVICE_ROLE_KEY|SUPABASE_SECRET_KEY|SERVICE_ROLE_KEY|DB_PASSWORD|OPENAI_API_KEY)\s*=\s*(?!$|<|\$\{|CHANGE_ME|SEU_|YOUR_).+/im.test(s)) errors.push(`${f}: possível secret literal em arquivo de ambiente`);
  if(/(?:sb_service_role_|sb_secret_|sk-)[A-Za-z0-9_-]{20,}/.test(s)) errors.push(`${f}: padrão de chave secreta detectado`);
  if(/Authorization\s*[:=]\s*[`'\"]Bearer\s+(?!\$\{|\$|<)[A-Za-z0-9._-]{20,}/i.test(s)) errors.push(`${f}: bearer token literal detectado`);
  if((f.startsWith('src/')||f.startsWith('public/')) && /service[_-]?role|SUPABASE_SECRET_KEY/i.test(s)) errors.push(`${f}: credencial privilegiada referenciada no cliente`);
  if((f.startsWith('src/')||f.startsWith('app/')) && /(pode_apresentar_contratante|pode_reapresentar_contratante|\bvalidada\b)/i.test(s) && /update\s*\(|\.update\s*\(/i.test(s)) errors.push(`${f}: possível update direto de status crítico`);
  if((f.startsWith('src/')||f.startsWith('app/')) && /PODE APRESENTAR AO CONTRATANTE|PODE REAPRESENTAR AO CONTRATANTE/.test(s) && /percentual|100\s*%|===\s*100/.test(s)) errors.push(`${f}: possível cálculo local de portão crítico`);
}
if(errors.length){console.error('Architecture Guard BLOQUEOU:\n'+errors.join('\n'));process.exit(1)}
console.log(`Architecture Guard PASS: ${textFiles.length} arquivo(s) inspecionados.`);
