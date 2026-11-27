import assert from "node:assert/strict";
import { test } from "node:test";
import { gerarMinutaContestacao } from "../functions/queue-worker-ai/contestacao-evidencias.mjs";

const id = (n) => "48000000-0000-4000-8000-" + String(n).padStart(12, "0");
const job = { id_execucao: id(1), entidade_id: id(2) };
const ref = { p_id_execucao: id(1), p_id_apontamento: id(2) };
const fonte = { id_versao_documento: id(3), pagina: 2, trecho: "Documento da competência contém a assinatura.",
  hash: "c".repeat(64) };
const contexto = { estado: "pendente", descricao: "Assinatura", fundamento: null, fontes: [fonte],
  regras: [{ codigo: "ASSINATURA", descricao: "A evidência exige assinatura." }] };
const evidencias = [{ id_versao_documento: id(3), pagina: 2, trecho: "contém a assinatura.", descricao: "Assinatura localizada" }];
const recomendacao = { recomendada: true, justificativa_recomendacao: "A página sustenta a conclusão",
  texto: "Síntese e pedido", fundamento: "A assinatura consta na página 2", evidencias };
const recibo = { estado: "registrada", id_contestacao: id(5) };
function ambiente({ entrada = contexto, resposta = recomendacao, resultado = recibo } = {}) {
  const chamadas = [];
  return {
    chamadas,
    obterContexto: async (pesquisa) => { chamadas.push(["preflight", pesquisa]); return entrada; },
    avaliar: async (dado) => {
      chamadas.push(["avaliar", dado]);
      if (resposta instanceof Error) throw resposta;
      return resposta;
    },
    registrar: async (dados) => { chamadas.push(["registrar", dados]); return resultado; },
  };
}

test("obtém escopo antes do modelo e registra mapa com o hash da fonte oficial", async () => {
  const a = ambiente();
  assert.equal(await gerarMinutaContestacao(job, a), recibo);
  assert.deepEqual(a.chamadas, [
    ["preflight", ref], ["avaliar", contexto],
    ["registrar", { ...ref, p_recomendada: true, p_justificativa: recomendacao.justificativa_recomendacao,
      p_texto: recomendacao.texto, p_fundamento: recomendacao.fundamento,
      p_evidencias: [{ ...evidencias[0], hash: fonte.hash }] }],
  ]);
});

test("reentrega e job obsoleto dispensam nova análise", async () => {
  for (const entrada of [recibo, { estado: "obsoleta" }]) {
    const a = ambiente({ entrada });
    assert.equal(await gerarMinutaContestacao(job, a), entrada);
    assert.deepEqual(a.chamadas, [["preflight", ref]]);
  }
});

test("sem fonte disponível só registra ausência de suporte", async () => {
  const a = ambiente({ entrada: { ...contexto, fontes: [] } });
  assert.equal(await gerarMinutaContestacao(job, a), recibo);
  assert.deepEqual(a.chamadas.map(([nome]) => nome), ["preflight", "registrar"]);
  assert.equal(a.chamadas[1][1].p_recomendada, false);
  assert.deepEqual(a.chamadas[1][1].p_evidencias, []);
});

test("página, versão ou trecho ausentes das fontes impedem a minuta", async () => {
  for (const referencia of [
    { ...evidencias[0], pagina: 3 }, { ...evidencias[0], id_versao_documento: id(10) },
    { ...evidencias[0], trecho: "Trecho inexistente" },
  ]) {
    const a = ambiente({ resposta: { ...recomendacao, evidencias: [referencia] } });
    await assert.rejects(gerarMinutaContestacao(job, a), /V248_FONTE_NAO_CONFIRMADA/);
    assert.equal(a.chamadas.length, 2);
  }
});

test("resposta inválida, análise indisponível e recomendação sem prova falham antes do registro", async () => {
  for (const resposta of [null, { ...recomendacao, evidencias: [] }, new Error("indisponível")]) {
    const a = ambiente({ resposta });
    await assert.rejects(gerarMinutaContestacao(job, a));
    assert.equal(a.chamadas.length, 2);
  }
  await assert.rejects(gerarMinutaContestacao(job, ambiente({ resultado: null })), /V248_RECIBO_INVALIDO/);
});
