import fs from 'node:fs'
import path from 'node:path'
import { execSync } from 'node:child_process'

const raiz = process.cwd()
const falhas = []

function listarArquivos(dir) {
  if (!fs.existsSync(dir)) return []
  const saida = []
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const completo = path.join(dir, item.name)
    if (item.isDirectory()) saida.push(...listarArquivos(completo))
    else saida.push(completo)
  }
  return saida
}

function argumentoEstatico(arg) {
  const valor = arg.trim()
  if (valor === '') return true
  if ((valor.startsWith("'") && valor.endsWith("'")) || (valor.startsWith('"') && valor.endsWith('"'))) return true
  if (valor.startsWith('`') && valor.endsWith('`') && !valor.includes('${')) return true
  return false
}

function auditarChamadasSupabase(arquivo) {
  const fonte = fs.readFileSync(arquivo, 'utf8')
  const relativo = path.relative(raiz, arquivo).replaceAll('\\', '/')
  const metodos = ['rpc', 'from', 'schema', 'select', 'order', 'filter', 'not', 'or']

  for (const metodo of metodos) {
    const re = new RegExp(`\\.${metodo}\\s*\\(\\s*([^,\\n)]*)`, 'g')
    let m
    while ((m = re.exec(fonte)) !== null) {
      const arg = m[1] ?? ''
      const antes = fonte.slice(Math.max(0, m.index - 40), m.index)

      // storage.from(bucket) não constrói SQL/PostgREST de tabela; o bucket pode ser dinâmico.
      if (metodo === 'from' && /storage\s*$/.test(antes)) continue

      if (!argumentoEstatico(arg)) {
        const linha = fonte.slice(0, m.index).split('\n').length
        falhas.push(`${relativo}:${linha} - ${metodo}() usa identificador/gramática dinâmica: ${arg.trim().slice(0, 120)}`)
      }
    }
  }

  const importsSqlDireto = [
    /from\s+['"](?:npm:)?pg(?:['"/])/i,
    /from\s+['"](?:npm:)?postgres(?:['"/])/i,
    /from\s+['"](?:npm:)?postgresjs(?:['"/])/i,
    /Deno\.connect\s*\(/,
  ]
  for (const padrao of importsSqlDireto) {
    if (padrao.test(fonte)) falhas.push(`${relativo} - acesso SQL direto detectado; use supabase-js/RPCs tipadas e revisadas.`)
  }

  if (/\/rest\/v1\/[^\n`]*\$\{/.test(fonte) || /\/rpc\/[^\n`]*\$\{/.test(fonte)) {
    falhas.push(`${relativo} - URL PostgREST/RPC construída por interpolação dinâmica.`)
  }
}

function arquivosAlterados() {
  const env = (process.env.ZERO_DRIFT_CHANGED_FILES ?? '').trim()
  if (env) return env.split(/\r?\n/).map((x) => x.trim()).filter(Boolean)
  try {
    return execSync('git diff --name-only HEAD~1..HEAD', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
      .split(/\r?\n/).map((x) => x.trim()).filter(Boolean)
  } catch {
    return []
  }
}

function auditarSqlAlterado(relativo) {
  const arquivo = path.join(raiz, relativo)
  if (!fs.existsSync(arquivo)) return
  const fonte = fs.readFileSync(arquivo, 'utf8')
  const linhas = fonte.split(/\r?\n/)

  linhas.forEach((linha, i) => {
    const t = linha.trim()
    if (/^(?:return\s+query\s+)?execute\s+/i.test(t) && !/^execute\s+function\b/i.test(t)) {
      falhas.push(`${relativo}:${i + 1} - SQL dinâmico via EXECUTE é proibido em novas migrations sem revisão explícita do guard.`)
    }
    if (/\bfor\s+execute\b/i.test(t)) {
      falhas.push(`${relativo}:${i + 1} - cursor FOR EXECUTE dinâmico é proibido em novas migrations.`)
    }
  })
}

for (const arquivo of listarArquivos(path.join(raiz, 'supabase/functions'))) {
  if (/\.(?:js|mjs|cjs|ts|tsx)$/.test(arquivo)) auditarChamadasSupabase(arquivo)
}

for (const relativo of arquivosAlterados()) {
  if (/^supabase\/migrations\/.*\.sql$/i.test(relativo)) auditarSqlAlterado(relativo)
}

if (falhas.length) {
  console.error('SQL Security Guard FALHOU. Foram encontradas construções que podem permitir SQL/PostgREST Injection:')
  for (const falha of falhas) console.error(`- ${falha}`)
  console.error('Use nomes de tabela/RPC/coluna fixos e envie dados somente como valores parametrizados. Se SQL dinâmico for realmente indispensável, faça revisão de segurança antes de alterar este guard.')
  process.exit(1)
}

console.log('SQL Security Guard PASS: Edge Functions sem identificadores SQL/PostgREST controlados por entrada dinâmica e novas migrations sem EXECUTE dinâmico.')
