import { describe, expect, it } from "vitest";
import { resolverDestinoPosLogin } from "@/lib/auth/resolverDestinoPosLogin";

const v = (n: number) => ({ id: `v${n}`, id_organizacao: `o${n}`, perfil: "analista" });

describe("resolverDestinoPosLogin (SYS-01)", () => {
  it("sem vínculos → sem acesso", () => {
    expect(resolverDestinoPosLogin([])).toEqual({ tipo: "sem-acesso" });
  });
  it("um vínculo → Dashboard /", () => {
    expect(resolverDestinoPosLogin([v(1)])).toEqual({ tipo: "rota", rota: "/" });
  });
  it("vários vínculos → /selecionar-organizacao", () => {
    expect(resolverDestinoPosLogin([v(1), v(2)])).toEqual({ tipo: "rota", rota: "/selecionar-organizacao" });
  });
});
