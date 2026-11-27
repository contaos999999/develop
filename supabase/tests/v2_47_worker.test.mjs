import assert from "node:assert/strict";
import { test } from "node:test";
import { revalidarSolucaoDiligencia } from "../functions/queue-worker-ai/diligencia-revalidacao.mjs";

const id = (n) => "47000000-0000-4000-8000-" + String(n).padStart(12, "0");
const job = { id_execucao: id(1), entidade_id: id(2), payload: { id_tarefa: id(3), id_evidencia: id(4) } };
const referencia = {
  p_id_execucao: id(1), p_id_tarefa: id(3), p_id_apontamento: id(2), p_id_evidencia: id(4),
};
const leitura = { estado: "pendente", descricao: "Conferir documento", fundamento: null };
const decisao = {
  classificacao: "procedente", fundamento: "Assinatura conferida", confianca: 0.91, evidencia_suficiente: true,
};
const recibo = { estado: "registrada", prova: { id_analise: id(5) } };
const parametros = {
  ...referencia,
  p_classificacao: decisao.classificacao,
  p_fundamento: decisao.fundamento,
  p_confianca: decisao.confianca,
  p_evidencia_suficiente: decisao.evidencia_suficiente,
};

function infraestrutura(respostas = [leitura, recibo], resultado = decisao) {
  const chamadas = [];
  return {
    chamadas,
    rpc: async (nome, argumentos) => {
      chamadas.push([nome, argumentos]);
      const resposta = respostas.shift();
      if (resposta instanceof Error) throw resposta;
      return resposta;
    },
    lerPaginas: async (versao) => {
      chamadas.push(["lerPaginas", versao]);
      return [{ numero_pagina: 2, texto_extraido: "Documento exclusivamente sintético" }];
    },
    avaliar: async (contexto) => {
      chamadas.push(["avaliar", contexto]);
      if (resultado instanceof Error) throw resultado;
      return resultado;
    },
  };
}

test("preflight oficial precede a leitura de uma única versão e a gravação usa o mesmo vínculo", async () => {
  const ambiente = infraestrutura();
  assert.deepEqual(await revalidarSolucaoDiligencia(job, ambiente), recibo);
  assert.deepEqual(ambiente.chamadas, [
    ["obter_revalidacao_tarefa_diligencia_v2", referencia],
    ["lerPaginas", id(4)],
    ["avaliar", {
      descricao: leitura.descricao, fundamento: "", evidencia: "[PÁGINA 2]\nDocumento exclusivamente sintético",
    }],
    ["registrar_revalidacao_tarefa_diligencia_v2", parametros],
  ]);
});

test("retry, job obsoleto e legados sem vínculo dispensam leitura e modelo", async () => {
  const antigo = { estado: "obsoleta" };
  for (const resposta of [recibo, antigo]) {
    const ambiente = infraestrutura([resposta]);
    assert.equal(await revalidarSolucaoDiligencia(job, ambiente), resposta);
    assert.equal(ambiente.chamadas.length, 1);
  }
  const ambiente = infraestrutura([antigo]);
  await revalidarSolucaoDiligencia({ ...job, payload: { id_evidencia: id(4) } }, ambiente);
  assert.deepEqual(ambiente.chamadas, [["obter_revalidacao_tarefa_diligencia_v2", { ...referencia, p_id_tarefa: null }]]);
});

test("versão sem texto tem prova insuficiente sem consulta ao modelo", async () => {
  const ambiente = infraestrutura();
  ambiente.lerPaginas = async () => [{ numero_pagina: 2, texto_extraido: " \n" }];
  assert.equal(await revalidarSolucaoDiligencia(job, ambiente), recibo);
  const [preflight, registrar] = ambiente.chamadas;
  assert.equal(preflight[0], "obter_revalidacao_tarefa_diligencia_v2");
  assert.deepEqual(registrar, ["registrar_revalidacao_tarefa_diligencia_v2", {
    ...referencia, p_classificacao: "inconclusivo",
    p_fundamento: "A versão apresentada ainda não contém texto extraído para revalidação.",
    p_confianca: 0, p_evidencia_suficiente: false,
  }]);
});

test("envelope inválido, escopo recusado e falha de leitura não persistem prova", async () => {
  const ambiente = infraestrutura();
  await assert.rejects(revalidarSolucaoDiligencia({ ...job, id_execucao: "inválido" }, ambiente), /EXECUCAO_INVALIDA/);
  assert.equal(ambiente.chamadas.length, 0);
  const semAcesso = infraestrutura([new Error("escopo recusado")]);
  await assert.rejects(revalidarSolucaoDiligencia(job, semAcesso), /escopo recusado/);
  assert.equal(semAcesso.chamadas.length, 1);
  ambiente.lerPaginas = async () => { throw new Error("leitura indisponível"); };
  await assert.rejects(revalidarSolucaoDiligencia(job, ambiente), /leitura indisponível/);
  assert.equal(ambiente.chamadas.length, 1);
});

test("modelo indisponível ou resposta inválida não produz prova oficial", async () => {
  for (const valor of [
    null, { ...decisao, fundamento: " " }, { ...decisao, confianca: 1.2 },
    { ...decisao, evidencia_suficiente: "true" }, { ...decisao, classificacao: "inconclusivo" },
  ]) {
    const ambiente = infraestrutura([leitura], valor);
    await assert.rejects(revalidarSolucaoDiligencia(job, ambiente), /RESULTADO_INVALIDO/);
    assert.equal(ambiente.chamadas.length, 3);
  }
  const ambiente = infraestrutura([leitura], new Error("tempo excedido"));
  await assert.rejects(revalidarSolucaoDiligencia(job, ambiente), /tempo excedido/);
  assert.equal(ambiente.chamadas.length, 3);
});

test("recibo incompatível falha e substituição entre leitura e registro mantém o job obsoleto", async () => {
  const obsoleta = { estado: "obsoleta" };
  assert.equal(await revalidarSolucaoDiligencia(job, infraestrutura([leitura, obsoleta])), obsoleta);
  await assert.rejects(revalidarSolucaoDiligencia(job, infraestrutura([leitura, null])), /RECIBO_INVALIDO/);
});
