import fs from 'node:fs'
import vm from 'node:vm'

const arquivos = [
  'supabase/functions/storage-sign-download/index.ts',
  'supabase/functions/evidence-access/index.js',
]

function carregarSanitizador(arquivo) {
  const fonte = fs.readFileSync(arquivo, 'utf8')
  const inicio = fonte.indexOf('function nomeDownloadSeguro')
  const fim = fonte.indexOf('\nasync function ', inicio)
  if (inicio < 0 || fim <= inicio) throw new Error(`Sanitizador de nome de download não encontrado em ${arquivo}.`)
  const trecho = fonte.slice(inicio, fim).replace('function nomeDownloadSeguro(v:unknown)', 'function nomeDownloadSeguro(v)')
  const sandbox = {}
  vm.createContext(sandbox)
  vm.runInContext(`${trecho}; globalThis.__sanitizar=nomeDownloadSeguro;`, sandbox)
  return sandbox.__sanitizar
}

const casosPerigosos = [
  'relatorio.pdf\r\nX-Test: injetado',
  'arquivo"; filename="outro.pdf',
  '../../segredo.pdf',
  '..\\..\\segredo.pdf',
  '%0d%0aSet-Cookie: ataque=1.pdf',
  'nome\u0000oculto.pdf',
  '💣relatorio.pdf',
]

const proibidos = /[\r\n\u0000-\u001f\u007f-\u009f"'%;:\/\\]/u

for (const arquivo of arquivos) {
  const sanitizar = carregarSanitizador(arquivo)

  const legitimo = 'Relatório Financeiro 2026 (final).pdf'
  if (sanitizar(legitimo) !== legitimo) throw new Error(`${arquivo}: nome legítimo foi alterado indevidamente.`)
  if (sanitizar('') !== 'arquivo') throw new Error(`${arquivo}: fallback de nome vazio divergente.`)

  for (const entrada of casosPerigosos) {
    const saida = sanitizar(entrada)
    if (!saida || saida.length > 160) throw new Error(`${arquivo}: tamanho/fallback inválido para ${JSON.stringify(entrada)}.`)
    if (proibidos.test(saida)) throw new Error(`${arquivo}: metacaractere perigoso permaneceu em ${JSON.stringify(saida)}.`)
    if (/^\.+/.test(saida)) throw new Error(`${arquivo}: nome ainda começa com ponto/traversal: ${JSON.stringify(saida)}.`)
  }
}

console.log(`Download Filename Security PASS: ${arquivos.length} funções validadas contra ${casosPerigosos.length} entradas perigosas.`)
