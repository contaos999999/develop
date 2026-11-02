/**
 * SYS-04 — Preferência local de organização (NÃO AUTORITATIVA).
 *
 * Apenas preferência de navegação, associada ao `user.id` para impedir que um
 * usuário herde a escolha de outro no mesmo navegador. Qualquer consumidor
 * deve revalidar o acesso pelo backend/RLS; este valor nunca concede acesso.
 */
const CHAVE = "contaos.preferenciaOrganizacao";

type Preferencia = { idUsuario: string; idOrganizacao: string };

function storage(): Storage | null {
  try {
    return typeof window === "undefined" ? null : window.sessionStorage;
  } catch {
    return null;
  }
}

export function obterPreferenciaOrganizacao(idUsuario: string): string | null {
  const s = storage();
  if (!s) return null;
  try {
    const v = JSON.parse(s.getItem(CHAVE) ?? "null") as Partial<Preferencia> | null;
    if (v && v.idUsuario === idUsuario && typeof v.idOrganizacao === "string") return v.idOrganizacao;
  } catch {
    /* valor inválido é ignorado */
  }
  return null;
}

export function definirPreferenciaOrganizacao(idUsuario: string, idOrganizacao: string): void {
  const s = storage();
  if (!s) return;
  const v: Preferencia = { idUsuario, idOrganizacao };
  s.setItem(CHAVE, JSON.stringify(v));
}
