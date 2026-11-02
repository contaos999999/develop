/**
 * SYS-01 — Resolve o destino após o login a partir dos vínculos devolvidos
 * pelo backend (já filtrados pela RLS). Não decide autorização: apenas conta
 * quantos vínculos o Supabase entregou.
 *
 * Rotas oficiais (FE 4.1):
 * - `/selecionar-organizacao` — SYS-04 (DEPENDÊNCIA DE FRONTEND)
 * - `/` — Dashboard SYS-05 (DEPENDÊNCIA DE FRONTEND)
 */
export type VinculoUsuario = {
  id: string;
  id_organizacao: string;
  perfil: string;
};

export type DestinoPosLogin =
  | { tipo: "rota"; rota: "/selecionar-organizacao" | "/" }
  | { tipo: "sem-acesso" };

export function resolverDestinoPosLogin(vinculos: readonly VinculoUsuario[]): DestinoPosLogin {
  if (vinculos.length === 0) return { tipo: "sem-acesso" };
  if (vinculos.length === 1) return { tipo: "rota", rota: "/" };
  return { tipo: "rota", rota: "/selecionar-organizacao" };
}
