const uuid = (value) => typeof value === "string" &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value);
const digest = (value) => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
const texto = (value, max) => typeof value === "string" && value.trim().length > 0 && value.trim().length <= max;
const pagina = (value) => Number.isSafeInteger(value) && value > 0;
const normalizar = (value) => value.trim().toLowerCase().replace(/\s+/gu, " ");

function mapaValidado(evidencias, fontes) {
  if (!Array.isArray(evidencias) || evidencias.length > 40) throw new Error("V248_MAPA_INVALIDO");
  return evidencias.map((e) => {
    if (!e || !uuid(e.id_versao_documento) || !pagina(e.pagina) ||
      !texto(e.descricao, 1500) || !texto(e.trecho, 2000)) throw new Error("V248_REFERENCIA_INVALIDA");
    const fonte = fontes.find((f) => f.id_versao_documento === e.id_versao_documento && f.pagina === e.pagina);
    if (!fonte || !normalizar(fonte.trecho).includes(normalizar(e.trecho))) {
      throw new Error("V248_FONTE_NAO_CONFIRMADA");
    }
    return {
      id_versao_documento: fonte.id_versao_documento, pagina: fonte.pagina,
      trecho: e.trecho.trim(), descricao: e.descricao.trim(), hash: fonte.hash,
    };
  });
}

export async function gerarMinutaContestacao(job, { obterContexto, avaliar, registrar }) {
  if (!uuid(job.id_execucao) || !uuid(job.entidade_id)) throw new Error("V248_EXECUCAO_INVALIDA");
  const referencia = { p_id_execucao: job.id_execucao, p_id_apontamento: job.entidade_id };
  const contexto = await obterContexto(referencia);
  if (contexto?.estado === "registrada" || contexto?.estado === "obsoleta") return contexto;
  if (contexto?.estado !== "pendente" || !texto(contexto.descricao, 20000) ||
    (contexto.fundamento != null && typeof contexto.fundamento !== "string") ||
    !Array.isArray(contexto.regras) || !Array.isArray(contexto.fontes) ||
    contexto.fontes.some((f) => !f || !uuid(f.id_versao_documento) || !pagina(f.pagina) ||
      !digest(f.hash) || !texto(f.trecho, 2500))) throw new Error("V248_CONTEXTO_INVALIDO");

  const analise = contexto.fontes.length ? await avaliar(contexto) : {
    recomendada: false,
    justificativa_recomendacao: "Ainda não há páginas documentais disponíveis para apoiar a contestação.",
    texto: "Aguardar análise das fontes da rodada.",
    fundamento: "Ausência de suporte documental disponível para a minuta.",
    evidencias: [],
  };
  if (typeof analise?.recomendada !== "boolean" || !texto(analise.justificativa_recomendacao, 3000) ||
    !texto(analise.texto, 20000) || !texto(analise.fundamento, 5000)) throw new Error("V248_MINUTA_INVALIDA");
  const mapa = mapaValidado(analise.evidencias, contexto.fontes);
  if (analise.recomendada && !mapa.length) throw new Error("V248_MINUTA_SEM_SUPORTE");

  const recibo = await registrar({
    ...referencia, p_recomendada: analise.recomendada,
    p_justificativa: analise.justificativa_recomendacao.trim(),
    p_texto: analise.texto.trim(), p_fundamento: analise.fundamento.trim(), p_evidencias: mapa,
  });
  if (recibo?.estado !== "registrada" && recibo?.estado !== "obsoleta") {
    throw new Error("V248_RECIBO_INVALIDO");
  }
  return recibo;
}
