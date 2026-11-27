export const classificacoesRevalidacao = Object.freeze([
  "procedente",
  "parcialmente_procedente",
  "nao_procedente",
  "inconclusivo",
]);

const uuid = (value) =>
  typeof value === "string" &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value);

export async function revalidarSolucaoDiligencia(job, { obterSubmissao, registrarProva, lerPaginas, avaliar }) {
  const { id_tarefa, id_evidencia } = job.payload;
  if (
    !uuid(job.id_execucao) || !uuid(job.entidade_id) || !uuid(id_evidencia) ||
    (id_tarefa != null && !uuid(id_tarefa))
  ) {
    throw new Error("V247_EXECUCAO_INVALIDA");
  }
  const referencia = {
    p_id_execucao: job.id_execucao,
    p_id_tarefa: id_tarefa ?? null,
    p_id_apontamento: job.entidade_id,
    p_id_evidencia: id_evidencia,
  };
  const leitura = await obterSubmissao(referencia);
  if (leitura?.estado === "registrada" || leitura?.estado === "obsoleta") return leitura;
  if (
    leitura?.estado !== "pendente" || !uuid(id_tarefa) || typeof leitura.descricao !== "string" ||
    (leitura.fundamento != null && typeof leitura.fundamento !== "string")
  ) {
    throw new Error("V247_LEITURA_INVALIDA");
  }

  const paginas = await lerPaginas(id_evidencia);
  const evidencia = paginas
    .filter((pagina) => typeof pagina.texto_extraido === "string" && pagina.texto_extraido.trim())
    .map((pagina) => "[PÁGINA " + pagina.numero_pagina + "]\n" + pagina.texto_extraido.trim())
    .join("\n\n").slice(0, 120000);
  const resultado = evidencia
    ? await avaliar({ descricao: leitura.descricao, fundamento: leitura.fundamento ?? "", evidencia })
    : {
      classificacao: "inconclusivo",
      fundamento: "A versão apresentada ainda não contém texto extraído para revalidação.",
      confianca: 0,
      evidencia_suficiente: false,
    };
  if (
    !classificacoesRevalidacao.includes(resultado?.classificacao) ||
    typeof resultado?.fundamento !== "string" || !resultado.fundamento.trim() ||
    !Number.isFinite(resultado.confianca) || resultado.confianca < 0 || resultado.confianca > 1 ||
    typeof resultado.evidencia_suficiente !== "boolean" ||
    (resultado.classificacao === "inconclusivo" && resultado.evidencia_suficiente)
  ) {
    throw new Error("V247_RESULTADO_INVALIDO");
  }
  const recibo = await registrarProva({
    ...referencia,
    p_classificacao: resultado.classificacao,
    p_fundamento: resultado.fundamento.trim(),
    p_confianca: resultado.confianca,
    p_evidencia_suficiente: resultado.evidencia_suficiente,
  });
  if (recibo?.estado !== "registrada" && recibo?.estado !== "obsoleta") {
    throw new Error("V247_RECIBO_INVALIDO");
  }
  return recibo;
}
