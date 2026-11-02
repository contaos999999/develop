import fs from 'node:fs'
import path from 'node:path'

const raiz = process.cwd()
const diretorio = path.join(raiz, 'supabase/functions')
const falhas = []

function listar(dir) {
  if (!fs.existsSync(dir)) return []
  const saida = []
  for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
    const completo = path.join(dir, item.name)
    if (item.isDirectory()) saida.push(...listar(completo))
    else if (/\.(?:js|mjs|cjs|ts|tsx)$/i.test(item.name)) saida.push(completo)
  }
  return saida
}

function linha(fonte, indice) {
  return fonte.slice(0, indice).split('\n').length
}

const regras = [
  {
    nome: 'HTML executável em Edge Function',
    padrao: /(?:content-type|Content-Type)[^\n]{0,80}text\/html|['"]text\/html['"]/gi,
    motivo: 'O backend ContaOS é API JSON/CSV. HTML deve permanecer no frontend para evitar nova superfície XSS.',
  },
  {
    nome: 'WebSocket próprio',
    padrao: /Deno\.upgradeWebSocket\s*\(|\bWebSocketServer\b|\bnew\s+WebSocket\s*\(/g,
    motivo: 'WebSocket exige desenho específico de autenticação, Origin e limites antes de ser habilitado.',
  },
  {
    nome: 'Supabase Realtime',
    padrao: /\.channel\s*\(|\brealtime\.(?:send|broadcast|channel)|postgres_changes/gi,
    motivo: 'Realtime está desativado no baseline 4.1; qualquer ativação deve vir com canais privados/RLS e revisão de tenant.',
  },
  {
    nome: 'Autenticação implícita por cookie',
    padrao: /headers\.get\s*\(\s*['"]cookie['"]\s*\)|\bset-cookie\b|credentials\s*:\s*['"]include['"]/gi,
    motivo: 'O baseline usa Authorization Bearer ou tokens internos explícitos; cookies reabrem superfície CSRF.',
  },
  {
    nome: 'Confiança em Host controlado pelo cliente',
    padrao: /headers\.get\s*\(\s*['"](?:host|x-forwarded-host|forwarded)['"]\s*\)/gi,
    motivo: 'Host não deve ser usado para autorização, geração de links sensíveis ou decisões de segurança.',
  },
  {
    nome: 'Redirect HTTP na aplicação',
    padrao: /\bResponse\.redirect\s*\(|headers\s*:\s*\{[^}]*['"]?Location['"]?\s*:/gis,
    motivo: 'Redirects exigem allowlist para impedir open redirect e cadeias de SSRF/cache poisoning.',
  },
]

for (const arquivo of listar(diretorio)) {
  const fonte = fs.readFileSync(arquivo, 'utf8')
  const relativo = path.relative(raiz, arquivo).replaceAll('\\', '/')

  for (const regra of regras) {
    regra.padrao.lastIndex = 0
    let m
    while ((m = regra.padrao.exec(fonte)) !== null) {
      falhas.push(`${relativo}:${linha(fonte, m.index)} - ${regra.nome}. ${regra.motivo}`)
      if (m[0].length === 0) regra.padrao.lastIndex++
    }
  }

  const temWildcard = /Access-Control-Allow-Origin['"]?\s*[:=]\s*['"]\*['"]/i.test(fonte)
  const temCredenciais = /Access-Control-Allow-Credentials['"]?\s*[:=]\s*['"]true['"]/i.test(fonte)
  if (temWildcard && temCredenciais) {
    falhas.push(`${relativo} - CORS inválido/inseguro: origem '*' combinada com credenciais.`)
  }
}

if (falhas.length) {
  console.error('Browser Surface Security FALHOU:')
  for (const falha of falhas) console.error(`- ${falha}`)
  console.error('Se uma dessas superfícies passar a ser requisito oficial, atualize arquitetura, ameaça, autorização e testes antes de alterar este guard.')
  process.exit(1)
}

console.log('Browser Surface Security PASS: sem HTML executável, WebSocket/Realtime, cookie auth, redirect ou Host confiado no backend atual.')
