import fs from 'node:fs'

const arquivo = 'supabase/functions/deliver-webhook/index.ts'
const fonte = fs.readFileSync(arquivo, 'utf8')

const obrigatorios = [
  ["from 'node:https'", 'cliente HTTPS com lookup controlado'],
  ['function ipEhPublico', 'classificação de IP público'],
  ['function hostLocalOuEspecial', 'bloqueio de hosts locais/especiais'],
  ['Deno.resolveDns', 'resolução DNS explícita'],
  ['const primeira = await resolverIpsPublicos', 'primeira resolução DNS'],
  ['const segunda = await resolverIpsPublicos', 'segunda resolução DNS'],
  ['listasIguais(primeira, segunda)', 'detecção de DNS instável/rebinding'],
  ['lookup:', 'lookup HTTPS customizado'],
  ['callback(null, ip, family)', 'pin do socket no IP validado'],
  ['maxHeaderSize: MAX_RESPONSE_HEADERS_BYTES', 'limite de cabeçalhos de resposta'],
  ['AbortSignal.timeout(WEBHOOK_TIMEOUT_MS)', 'timeout de entrega'],
  ["resposta.status >= 300 && resposta.status < 400", 'bloqueio de redirecionamento'],
  ['MAX_RESPONSE_BYTES = 4_000', 'limite de corpo de resposta'],
  ['valorHeaderSeguro', 'sanitização de headers de saída'],
  ["url.protocol !== 'https:'", 'HTTPS obrigatório'],
]

for (const [trecho, descricao] of obrigatorios) {
  if (!fonte.includes(trecho)) throw new Error(`SSRF Guard: controle ausente: ${descricao}.`)
}

if (/\bfetch\s*\(\s*(?:url|destino\.url)/.test(fonte)) {
  throw new Error('SSRF Guard: entrega de webhook voltou a usar fetch() direto com URL configurável, reabrindo risco de DNS rebinding.')
}

if (!/url\.username\s*\|\|\s*url\.password/.test(fonte)) {
  throw new Error('SSRF Guard: bloqueio de credenciais embutidas na URL foi removido.')
}

if (!/endereco\.range\(\)\s*===\s*'unicast'/.test(fonte)) {
  throw new Error('SSRF Guard: classificação de rede pública foi alterada.')
}

console.log('Webhook SSRF Security PASS: HTTPS, IP público, DNS estável, DNS pinning, no-redirect, timeout e limites preservados.')
