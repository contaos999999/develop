import fs from 'node:fs';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

const required = [
  "00_AI_LEIA_ANTES_DE_ALTERAR.md",
  "01_PRD_MESTRE_4_1.md",
  "02_PREMISSAS_FUNCIONAIS_TECNICAS_4_1.md",
  "03_ARQUITETURA_OFICIAL_4_1.md",
  "04_MANUAL_AMBIENTE_E_PROMOCAO_4_1.md",
  "05_BACKEND_SUPABASE_CERTIFICADO_4_1.md",
  "06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md",
  "07_ZERO_DRIFT_GOVERNANCA_4_1.md",
  "08_REQUISITOS_96_E_CRITERIOS_ACEITE_4_1.md",
  "08A_REQUISITOS_001_024_4_1.md",
  "08B_REQUISITOS_025_048_4_1.md",
  "08C_REQUISITOS_049_072_4_1.md",
  "08D_REQUISITOS_073_096_4_1.md",
  "09_RASTREABILIDADE_FONTES_AUDITORIA_4_1.md",
  "10_IA_OCR_RAG_E_PRECEDENTES_4_1.md",
  "11_RNF_PERFORMANCE_CONCORRENCIA_RESILIENCIA_4_1.md",
  "12_PROMPTS_PROTOCOLO_IMPLEMENTACAO_4_1.md",
  "13_MAPA_DOCUMENTOS_PACOTE_4_1.md",
  "14_CHECKLIST_PRE_ALTERACAO.md",
  "15_ESTADO_CERTIFICADO_HML_4_1.md",
  "16_CUSTOS_E_PLANOS_REFERENCIA_4_1.md",
  "17_FONTES_TECNICAS_E_QA_4_1.md",
  "18_SCHEMA_RLS_EDGE_QUEUES_CRON_4_1.md"
];
const manifestPath = 'AI_CONTEXT_MANIFEST.md';
const taskPath = 'docs/tasks/active-task.json';

function combinedFingerprint() {
  const h = crypto.createHash('sha256');
  for (const name of required) {
    if (!fs.existsSync(name)) throw new Error(`Documento obrigatório ausente: ${name}`);
    const content = fs.readFileSync(name,'utf8');
    h.update(name); h.update('\0'); h.update(content); h.update('\0');
  }
  return h.digest('hex');
}

const fingerprint = combinedFingerprint();
if (!fs.existsSync(manifestPath)) throw new Error('AI_CONTEXT_MANIFEST.md ausente.');
const manifest = fs.readFileSync(manifestPath,'utf8');
const m = manifest.match(/Fingerprint SHA-256 combinado:\s*`([a-f0-9]{64})`/i);
if (!m) throw new Error('Fingerprint não encontrado no AI_CONTEXT_MANIFEST.md.');
if (m[1].toLowerCase() !== fingerprint) throw new Error(`Contexto alterado sem regenerar manifesto. Esperado no arquivo: ${m[1]}; calculado: ${fingerprint}.`);

for (const f of ['AGENTS.md','CLAUDE.md','GEMINI.md','LOVABLE.md','.github/copilot-instructions.md']) {
  if (!fs.existsSync(f)) throw new Error(`Instrução obrigatória de agente ausente: ${f}`);
  const c=fs.readFileSync(f,'utf8');
  if (!c.includes('00_AI_LEIA_ANTES_DE_ALTERAR.md')) throw new Error(`${f} não aponta para a leitura obrigatória do contexto.`);
}

const env = process.env.ZERO_DRIFT_CHANGED_FILES?.trim();
let changed=[];
if (env) changed=env.split('\n').filter(Boolean);
else { try { changed=execSync('git diff --name-only HEAD~1..HEAD',{encoding:'utf8'}).trim().split('\n').filter(Boolean); } catch { changed=[]; } }

const governance = new Set([
  ...required,
  manifestPath,
  'AGENTS.md','CLAUDE.md','GEMINI.md','LOVABLE.md','README.md','README_ZERO_DRIFT.md',
  '.github/copilot-instructions.md','.github/CODEOWNERS','.github/pull_request_template.md',
  'scripts/ai-context-gate.mjs','.github/workflows/zero-drift.yml',taskPath
]);
const implementationChanged = changed.some(f => !governance.has(f));

if (implementationChanged) {
  if (!fs.existsSync(taskPath)) throw new Error('active-task.json ausente.');
  const task=JSON.parse(fs.readFileSync(taskPath,'utf8'));
  const active=['ativa','ativo','active','em_andamento','in_progress'].includes(String(task.status||'').toLowerCase());
  if (!active) throw new Error('Alteração de implementação exige tarefa ativa no docs/tasks/active-task.json.');
  if (task.context_pack_version !== '4.1') throw new Error('A tarefa deve declarar context_pack_version = 4.1.');
  if (task.context_read_acknowledged !== true) throw new Error('A tarefa não declarou context_read_acknowledged = true.');
  if (!task.context_read_acknowledged_at) throw new Error('Informe context_read_acknowledged_at.');
  if (!task.context_read_by) throw new Error('Informe context_read_by (agente/pessoa responsável pela leitura).');
  if (task.context_manifest_sha256 !== fingerprint) throw new Error('O fingerprint declarado na tarefa não corresponde ao contexto atual. Leia novamente todos os documentos canônicos, incluindo 08A–08D.');
  const read=new Set(task.context_documents_read||[]);
  const missing=required.filter(f=>!read.has(f));
  if (missing.length) throw new Error('A tarefa não declara leitura de todos os documentos: '+missing.join(', '));
}

console.log(`Context Gate PASS: contexto 4.1 íntegro, fingerprint ${fingerprint}, ${required.length} documentos obrigatórios.`);
