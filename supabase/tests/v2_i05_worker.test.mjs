import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import {
  conferirHashDaExtracao,
  registrarItensDaExtracao,
  validarArquivoDaExtracao,
  validarParecerDaExtracao,
} from "../functions/queue-worker-ai/diligencia-origem.mjs";

const ids = {
  org: "11111111-1111-4111-8111-111111111111",
  contrato: "22222222-2222-4222-8222-222222222222",
  competencia: "33333333-3333-4333-8333-333333333333",
  ciclo: "44444444-4444-4444-8444-444444444444",
  parecer: "55555555-5555-4555-8555-555555555555",
  arquivo: "66666666-6666-4666-8666-666666666666",
  item: "77777777-7777-4777-8777-777777777777",
  outro: "88888888-8888-4888-8888-888888888888",
};
const bytes = Buffer.from("Bytes sintéticos de origem");
const sha = createHash("sha256").update(bytes).digest("hex");
const parecer = {
  id: ids.parecer,
  id_organizacao: ids.org,
  id_contrato: ids.contrato,
  id_competencia: ids.competencia,
  id_ciclo: ids.ciclo,
  id_arquivo: ids.arquivo,
};
const arquivo = { id: ids.arquivo, id_organizacao: ids.org, id_contrato: ids.contrato, sha256: sha };
const job = {
  entidade_id: ids.parecer, id_organizacao: ids.org, id_contrato: ids.contrato,
  payload: { id_competencia: ids.competencia, id_ciclo: ids.ciclo },
};
const resultado = {
  apontamentos: 1, ids_apontamentos: [ids.item], reutilizado: false,
  id_parecer: ids.parecer, id_arquivo: ids.arquivo, arquivo_sha256: sha,
};

test("I05 worker valida a identidade da rodada e os bytes do arquivo antes do modelo", async () => {
  assert.doesNotThrow(() => validarParecerDaExtracao(job, parecer));
  assert.doesNotThrow(() => validarArquivoDaExtracao(parecer, arquivo));
  assert.equal(await conferirHashDaExtracao(arquivo, bytes), sha);
  await assert.rejects(conferirHashDaExtracao(arquivo, Buffer.from("Outro documento")), /conteúdo do arquivo/);
});

test("I05 worker recusa ciclo, documento, organização e contrato cruzados", () => {
  for (const delta of [
    { id: ids.outro }, { id_organizacao: ids.outro }, { id_contrato: ids.outro },
    { id_competencia: ids.outro }, { id_ciclo: ids.outro }, { id_arquivo: null },
  ]) {
    assert.throws(() => validarParecerDaExtracao(job, { ...parecer, ...delta }), /escopo/);
  }
  for (const delta of [
    { id: ids.outro }, { id_organizacao: ids.outro }, { id_contrato: ids.outro }, { sha256: "" },
  ]) {
    assert.throws(() => validarArquivoDaExtracao(parecer, { ...arquivo, ...delta }), /origem/);
  }
});

test("I05 worker usa somente a RPC atômica e preserva os IDs retornados", async () => {
  const chamadas = [];
  const cliente = { rpc: async (...args) => {
    chamadas.push(args);
    return { data: resultado, error: null };
  } };
  const itens = [{ descricao: "Item A", severidade: "media", pagina: 2, trecho: "Trecho A" }];
  assert.deepEqual(await registrarItensDaExtracao(cliente, parecer, arquivo, sha, itens), resultado);
  assert.deepEqual(chamadas, [["registrar_extracao_apontamentos", {
    p_id_parecer: ids.parecer, p_id_arquivo: ids.arquivo, p_sha256: sha, p_apontamentos: itens,
  }]]);
});

test("I05 worker diferencia vazio persistido e resultado inválido", async () => {
  const vazio = { ...resultado, apontamentos: 0, ids_apontamentos: [], reutilizado: true };
  const cliente = { rpc: async () => ({ data: vazio, error: null }) };
  assert.deepEqual(await registrarItensDaExtracao(cliente, parecer, arquivo, sha, []), vazio);
  let chamada = false;
  const inesperado = { rpc: async () => { chamada = true; } };
  await assert.rejects(registrarItensDaExtracao(inesperado, parecer, arquivo, sha, {}), /lista/);
  assert.equal(chamada, false);
});

test("I05 worker rejeita erro, retorno parcial, ID trocado e hash não confirmado", async () => {
  for (const reply of [
    { error: { message: "dados privados" }, data: resultado },
    { error: null, data: null },
    { error: null, data: { ...resultado, ids_apontamentos: [ids.item, ids.item] } },
    { error: null, data: { ...resultado, ids_apontamentos: [null] } },
    { error: null, data: { ...resultado, id_parecer: ids.outro } },
    { error: null, data: { ...resultado, arquivo_sha256: "f".repeat(64) } },
  ]) {
    await assert.rejects(
      registrarItensDaExtracao({ rpc: async () => reply }, parecer, arquivo, sha, []),
      { message: "O banco não confirmou os apontamentos com sua origem." },
    );
  }
});

test("I05 o worker em produção usa o mesmo módulo e a auditoria registra os IDs confirmados", () => {
  const source = readFileSync(new URL("../functions/queue-worker-ai/index.ts", import.meta.url), "utf8");
  const trecho = source.slice(source.indexOf("async function extrairDiligencia"), source.indexOf("async function revalidarApontamento"));
  assert.ok(source.includes("from './diligencia-origem.mjs'"));
  assert.match(trecho, /validarParecerDaExtracao\(job, parecer\)[\s\S]*validarArquivoDaExtracao\(parecer, arquivo\)[\s\S]*storage\.from/);
  assert.match(trecho, /conferirHashDaExtracao\(arquivo, bytes\)[\s\S]*fetch\('https:\/\/api\.openai\.com/);
  assert.match(trecho, /registrarItensDaExtracao\(sb, parecer, arquivo, hash, parsed\?\.apontamentos\)/);
  assert.match(trecho, /ids_apontamentos: resultado\.ids_apontamentos/);
  assert.doesNotMatch(trecho, /from\('apontamentos_contratante'\)\.insert/);
});
