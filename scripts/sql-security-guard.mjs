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

function linhaDaPosicao(fonte, posicao) {
  return fonte.slice(0, posicao).split('\n').length
}

function extrairArgumentos(fonte, indiceAbreParen) {
  const args = []
  let atual = ''
  let profundidade = 0
  let aspas = null
  let escape = false

  for (let i = indiceAbreParen + 1; i < fonte.length; i++) {
    const ch = fonte[i]

    if (aspas) {
      atual += ch
      if (escape) { escape = false; continue }
      if (ch === '\\') { escape = true; continue }
      if (ch === aspas) aspas = null
      continue
    }

    if (ch === "'" || ch === '"' || ch === '`') {
      aspas = ch
      atual += ch
      continue
    }

    if (ch === '(' || ch === '[' || ch === '{') {
      profundidade++
      atual += ch
      continue
    }
    if (ch === ')' || ch === ']' || ch === '}') {
      if (ch === ')' && profundidade === 0) {
        if (atual.trim() !== '' || args.length) args.push(atual.trim())
        return args
      }
      profundidade--
      atual += ch
      continue
    }

    if (ch === ',' && profundidade === 0) {
      args.push(atual.trim())
      atual = ''
      continue
    }

    atual += ch
  }
  return null
}

function chamadasDoMetodo(fonte, metodo, prefixo = '') {
  const escapado = metodo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const re = new RegExp(`${prefixo}\\.${escapado}\\s*\\(`, 'g')
  const saida = []
  let m
  while ((m = re.exec(fonte)) !== null) {
    const abre = fonte.indexOf('(', m.index + m[0].lastIndexOf(metodo))
    const args = extrairArgumentos(fonte, abre)
    if (args) saida.push({ index: m.index, args })
  }
  return saida
}

function auditarChamadasSupabase(arquivo) {
  const fonte = fs.readFileSync(arquivo, 'utf8')
  const relativo = path.relative(raiz, arquivo).replaceAll('\\', '/')

  const clientes = new Set()
  const reCliente = /\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*createClient\s*\(/g
  let cm
  while ((cm = reCliente.exec(fonte)) !== null) clientes.add(cm[1])

  for (const cliente of clientes) {
    for (const metodo of ['from', 'rpc', 'schema']) {
      for (const chamada of chamadasDoMetodo(fonte, metodo, `\\b${cliente}`)) {
        const primeiro = chamada.args[0] ?? ''
        if (!argumentoEstatico(primeiro)) {
          falhas.push(`${relativo}:${linhaDaPosicao(fonte, chamada.index)} - ${cliente}.${metodo}() usa nome dinâmico: ${primeiro.slice(0, 120)}`)
        }
      }
    }
  }

  // select/order recebem gramática/identificador PostgREST. No backend ContaOS esses campos devem ser literais.
  for (const metodo of ['select', 'order']) {
    for (const chamada of chamadasDoMetodo(fonte, metodo)) {
      const primeiro = chamada.args[0] ?? ''
      if (!argumentoEstatico(primeiro)) {
        falhas.push(`${relativo}:${linhaDaPosicao(fonte, chamada.index)} - ${metodo}() usa coluna/seleção dinâmica: ${primeiro.slice(0, 120)}`)
      }
    }
  }

  // .or() é interpretado "as-is" pelo PostgREST. Proibimos interpolação dinâmica por padrão.
  for (const chamada of chamadasDoMetodo(fonte, 'or')) {
    const primeiro = chamada.args[0] ?? ''
    if (!argumentoEstatico(primeiro)) {
      falhas.push(`${relativo}:${linhaDaPosicao(fonte, chamada.index)} - or() usa gramática PostgREST dinâmica: ${primeiro.slice(0, 120)}`)
    }
  }

  // .filter() também usa operador/valor em sintaxe PostgREST. Array.filter(fn) é ignorado.
  for (const chamada of chamadasDoMetodo(fonte, 'filter')) {
    const primeiro = chamada.args[0] ?? ''
    const pareceArrayFilter = /^(?:Boolean|Number|String|Object|[A-Za-z_$][\w$]*\s*=>|\([^)]*\)\s*=>|function\b)/.test(primeiro)
    if (pareceArrayFilter) continue
    if (!argumentoEstatico(primeiro) || !argumentoEstatico(chamada.args[1] ?? '') || !argumentoEstatico(chamada.args[2] ?? '')) {
      falhas.push(`${relativo}:${linhaDaPosicao(fonte, chamada.index)} - filter() com gramática/valor dinâmico requer revisão de sanitização.`)
    }
  }

  // .not() recebe operador e valor na sintaxe PostgREST; no ContaOS exigimos forma totalmente literal.
  for (const chamada of chamadasDoMetodo(fonte, 'not')) {
    const [coluna = '', operador = '', valor = ''] = chamada.args
    if (!argumentoEstatico(coluna) || !argumentoEstatico(operador) || !argumentoEstatico(valor)) {
      falhas.push(`${relativo}:${linhaDaPosicao(fonte, chamada.index)} - not() dinâmico requer revisão de sanitização.`)
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
  console.error('Use nomes de tabela/RPC/coluna fixos. Para .or(), .filter() e .not(), não monte gramática PostgREST com entrada dinâmica.')
  process.exit(1)
}

console.log('SQL Security Guard PASS: sem nomes SQL/PostgREST controlados por entrada dinâmica e sem novo EXECUTE dinâmico em migrations.')
