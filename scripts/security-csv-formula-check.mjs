import fs from 'node:fs'
import vm from 'node:vm'

const arquivo = 'supabase/functions/generate-report/index.js'
const fonte = fs.readFileSync(arquivo, 'utf8')
const inicio = fonte.indexOf('function formulaCsvPerigosa')
const fim = fonte.indexOf('async function garantirArquivo')
if (inicio < 0 || fim <= inicio) throw new Error('Funções de segurança CSV não encontradas no generate-report.')

const sandbox = {}
vm.createContext(sandbox)
vm.runInContext(`${fonte.slice(inicio, fim)}; globalThis.__csv={formulaCsvPerigosa,csvCell};`, sandbox)
const { formulaCsvPerigosa, csvCell } = sandbox.__csv

const perigosos = [
  '=SUM(A1:A2)',
  '+1+1',
  '-1+2',
  '@SUM(A1:A2)',
  '   =HYPERLINK("https://exemplo.invalid")',
  '\t=1+1',
  '\r=1+1',
  '\n=1+1',
  '＝1+1',
  '＋1+1',
  '＠SUM(A1:A2)',
]

for (const valor of perigosos) {
  if (!formulaCsvPerigosa(valor)) throw new Error(`Entrada perigosa não detectada: ${JSON.stringify(valor)}`)
  const celula = csvCell(valor)
  if (!celula.startsWith('"\'')) throw new Error(`Entrada perigosa não neutralizada: ${JSON.stringify(valor)} -> ${celula}`)
}

const benignos = [
  ['Relatório normal', '"Relatório normal"'],
  ['texto "com aspas"', '"texto ""com aspas"""'],
  [42, '"42"'],
  [-42, '"-42"'],
  [true, '"true"'],
  [{ status: 'ok' }, '"{""status"":""ok""}"'],
]

for (const [valor, esperado] of benignos) {
  if (typeof valor === 'string' && formulaCsvPerigosa(valor)) throw new Error(`Falso positivo: ${JSON.stringify(valor)}`)
  const obtido = csvCell(valor)
  if (obtido !== esperado) throw new Error(`Serialização divergente para ${JSON.stringify(valor)}: ${obtido} != ${esperado}`)
}

if (!fonte.includes("new TextEncoder().encode('\\ufeff'+cab+linhas)")) throw new Error('BOM UTF-8 do CSV foi alterado.')
if (!fonte.includes("const cab='ordem;entidade_tipo;entidade_id;versao_id;hash;metadados\\r\\n'")) throw new Error('Cabeçalho/separador CSV foi alterado.')

console.log(`Security CSV Formula PASS: ${perigosos.length} entradas perigosas neutralizadas e ${benignos.length} entradas benignas preservadas.`)
