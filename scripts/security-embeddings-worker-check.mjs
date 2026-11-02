import fs from 'node:fs'

const arquivo = 'supabase/functions/queue-worker-embeddings/index.ts'
const fonte = fs.readFileSync(arquivo, 'utf8')

const obrigatorios = [
  ["createClient(URL, SERVICE", 'cliente backend com service role'],
  ["new Supabase.ai.Session('gte-small')", 'modelo local oficial gte-small'],
  ["sb.rpc('validar_token_interno'", 'validação real do token interno'],
  ["p_fila: 'embeddings'", 'consumo exclusivo da fila embeddings'],
  ["'fragmento_documento'", 'tipo fragmento_documento'],
  ["'precedente'", 'tipo precedente'],
  ['vetor.length !== 384', 'validação explícita de 384 dimensões'],
  ['MAX_JOBS_POR_CHAMADA = 3', 'limite de jobs por chamada'],
  ['LIMITE_JSON = 4 * 1024', 'limite do corpo da requisição'],
  ['LIMITE_TEXTO = 6_000', 'limite de texto para inferência'],
  ["sb.rpc('worker_pull_job'", 'leitura controlada da fila'],
  ["sb.rpc('worker_finalizar_job'", 'finalização com retry/DLQ'],
  [".from('fragmentos_documento')", 'tabela fixa de fragmentos'],
  [".from('precedentes')", 'tabela fixa de precedentes'],
]

for (const [trecho, descricao] of obrigatorios) {
  if (!fonte.includes(trecho)) throw new Error(`Embeddings Worker Guard: controle ausente: ${descricao}.`)
}

const posToken = fonte.indexOf("sb.rpc('validar_token_interno'")
const posBody = fonte.indexOf('lerJsonLimitado(req')
if (posToken < 0 || posBody < 0 || posToken > posBody) {
  throw new Error('Embeddings Worker Guard: o corpo está sendo processado antes da autenticação interna.')
}

if (/functions\/v1\/contaos-worker/i.test(fonte)) {
  throw new Error('Embeddings Worker Guard: o worker voltou a delegar para o processador genérico legado.')
}

if (/\bfetch\s*\(/.test(fonte)) {
  throw new Error('Embeddings Worker Guard: o worker dedicado não deve fazer chamadas HTTP externas ou internas.')
}

if (/\.from\s*\(\s*(?!['"](?:fragmentos_documento|precedentes)['"])/.test(fonte)) {
  throw new Error('Embeddings Worker Guard: foi detectado acesso de tabela não previsto ou dinâmico.')
}

console.log('Embeddings Worker Security PASS: autenticação antes do body, fila/tipos fixos, gte-small 384, limites e finalização segura preservados.')
