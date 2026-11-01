import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const raiz = path.resolve(process.cwd());
const checkpoint = path.join(raiz, 'supabase', 'applied-history', 'contaos-hml-full-history.sql');
const destino = path.join(raiz, 'supabase', 'migrations');

if (!fs.existsSync(checkpoint)) {
  console.error('Checkpoint não encontrado:', checkpoint);
  process.exit(1);
}

fs.mkdirSync(destino, { recursive: true });
const bruto = fs.readFileSync(checkpoint, 'utf8');
const separador = /\n\n-- ============================================================\n\n/g;
const blocos = bruto.split(separador).map(x => x.trim()).filter(Boolean);
let criados = 0;
let validados = 0;
let divergentes = 0;

for (const bloco of blocos) {
  const primeiraQuebra = bloco.indexOf('\n');
  const cabecalho = primeiraQuebra >= 0 ? bloco.slice(0, primeiraQuebra).trim() : bloco.trim();
  const corpo = primeiraQuebra >= 0 ? bloco.slice(primeiraQuebra + 1).trim() + '\n' : '';
  const m = cabecalho.match(/^-- MIGRATION (\d{14})_(.+)$/);
  if (!m) {
    console.error('Bloco sem cabeçalho de migration reconhecido:', cabecalho);
    process.exit(2);
  }
  const [, versao, nome] = m;
  const arquivo = path.join(destino, `${versao}_${nome}.sql`);
  if (fs.existsSync(arquivo)) {
    const atual = fs.readFileSync(arquivo, 'utf8').trimEnd() + '\n';
    if (atual !== corpo) {
      console.error(`DIVERGÊNCIA: ${path.relative(raiz, arquivo)}`);
      divergentes++;
      continue;
    }
    validados++;
  } else {
    fs.writeFileSync(arquivo, corpo, 'utf8');
    criados++;
  }
}

const hash = crypto.createHash('sha256').update(Buffer.from(bruto, 'utf8')).digest('hex');
console.log(`Checkpoint SHA-256: ${hash}`);
console.log(`Migrations criadas: ${criados}`);
console.log(`Migrations já validadas: ${validados}`);
console.log(`Divergências: ${divergentes}`);
if (divergentes > 0) process.exit(3);
