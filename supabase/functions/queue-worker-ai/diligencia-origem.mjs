const HASH = /^[0-9a-f]{64}$/;
const UUID = /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/;

export function validarParecerDaExtracao(job, parecer) {
  if (!parecer || parecer.id !== job.entidade_id ||
      parecer.id_organizacao !== job.id_organizacao || parecer.id_contrato !== job.id_contrato ||
      !UUID.test(parecer.id_ciclo || "") || !UUID.test(parecer.id_arquivo || "") ||
      (job.payload?.id_ciclo != null && job.payload.id_ciclo !== parecer.id_ciclo) ||
      (job.payload?.id_competencia != null && job.payload.id_competencia !== parecer.id_competencia)) {
    throw new Error("O parecer não corresponde ao escopo da extração.");
  }
}

export function validarArquivoDaExtracao(parecer, arquivo) {
  if (!arquivo || arquivo.id !== parecer.id_arquivo ||
      arquivo.id_organizacao !== parecer.id_organizacao || arquivo.id_contrato !== parecer.id_contrato ||
      typeof arquivo.sha256 !== "string" || !HASH.test(arquivo.sha256.toLowerCase())) {
    throw new Error("O arquivo não corresponde à origem do parecer.");
  }
}

export async function conferirHashDaExtracao(arquivo, bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  const hash = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
  if (hash !== arquivo.sha256.toLowerCase()) {
    throw new Error("O conteúdo do arquivo de origem diverge do registro.");
  }
  return hash;
}

export async function registrarItensDaExtracao(cliente, parecer, arquivo, hash, itens) {
  if (!Array.isArray(itens)) throw new Error("A extração não retornou uma lista de apontamentos.");

  const { data, error } = await cliente.rpc("registrar_extracao_apontamentos", {
    p_id_parecer: parecer.id,
    p_id_arquivo: arquivo.id,
    p_sha256: hash,
    p_apontamentos: itens,
  });
  const ids = data?.ids_apontamentos;
  if (error || !Array.isArray(ids) ||
      !ids.every((id) => typeof id === "string" && UUID.test(id)) ||
      new Set(ids).size !== ids.length || data.apontamentos !== ids.length ||
      data.id_parecer !== parecer.id || data.id_arquivo !== arquivo.id ||
      data.arquivo_sha256 !== hash || typeof data.reutilizado !== "boolean") {
    throw new Error("O banco não confirmou os apontamentos com sua origem.");
  }
  return data;
}
