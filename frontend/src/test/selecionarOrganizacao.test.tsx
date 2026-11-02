import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";

const m = vi.hoisted(() => ({
  getUser: vi.fn(),
  signOut: vi.fn(),
  resultado: vi.fn(),
  eqs: [] as Array<[string, unknown]>,
  nav: vi.fn(),
}));

vi.mock("@/integrations/supabase/client", () => {
  const builder = {
    select: () => builder,
    eq: (c: string, v: unknown) => {
      m.eqs.push([c, v]);
      return builder;
    },
    then: (res: (v: unknown) => unknown, rej: (e: unknown) => unknown) =>
      Promise.resolve().then(() => m.resultado()).then(res, rej),
  };
  return {
    supabase: {
      auth: { getUser: m.getUser, signOut: m.signOut },
      from: () => builder,
    },
  };
});
vi.mock("@tanstack/react-router", () => ({
  useNavigate: () => m.nav,
}));

import { OrganizationSelector, MENSAGENS_SYS04 } from "@/components/organizacao/OrganizationSelector";
import {
  definirPreferenciaOrganizacao,
  obterPreferenciaOrganizacao,
} from "@/lib/organizacao/preferenciaOrganizacao";

const U = "user-1";
const org = (id: string, nome: string) => ({
  id: `v-${id}`,
  perfil: "admin",
  organizacao: { id, razao_social: `${nome} LTDA`, nome_fantasia: nome, cnpj: "12345678000190", situacao: "ativa" },
});

let qc: QueryClient;
function montar() {
  qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const W = ({ children }: { children: ReactNode }) => <QueryClientProvider client={qc}>{children}</QueryClientProvider>;
  return render(<OrganizationSelector />, { wrapper: W });
}

beforeEach(() => {
  vi.clearAllMocks();
  m.eqs.length = 0;
  sessionStorage.clear();
  m.getUser.mockResolvedValue({ data: { user: { id: U } }, error: null });
  m.signOut.mockResolvedValue({ error: null });
});

describe("SYS-04 Selecionar organização", () => {
  it("sem sessão redireciona para /login", async () => {
    m.getUser.mockResolvedValue({ data: { user: null }, error: null });
    montar();
    await waitFor(() => expect(m.nav).toHaveBeenCalledWith({ to: "/login", replace: true }));
  });

  it("AuthSessionMissingError (sem sessão real do SDK) redireciona para /login sem erro genérico", async () => {
    m.getUser.mockResolvedValue({ data: { user: null }, error: { name: "AuthSessionMissingError", status: 400 } });
    montar();
    await waitFor(() => expect(m.nav).toHaveBeenCalledWith({ to: "/login", replace: true }));
    expect(screen.queryByText(MENSAGENS_SYS04.erro)).toBeNull();
  });

  it("loading bloqueia a ação e a consulta filtra id_usuario e ativo", async () => {
    let resolver!: (v: unknown) => void;
    m.resultado.mockReturnValue(new Promise((r) => (resolver = r)));
    montar();
    expect((await screen.findAllByText(MENSAGENS_SYS04.carregando)).length).toBeGreaterThan(0);
    expect(screen.queryByRole("button", { name: "Continuar" })).toBeNull();
    await waitFor(() => expect(m.eqs).toEqual([["id_usuario", U], ["ativo", true]]));
    resolver({ data: [org("o1", "Alfa")], error: null });
    expect(await screen.findByRole("radio", { name: /Alfa/ })).toBeTruthy();
  });

  it("vazio orienta procurar administrador e permite sair", async () => {
    m.resultado.mockReturnValue({ data: [], error: null });
    montar();
    expect(await screen.findByText(MENSAGENS_SYS04.vazio)).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: "Sair" }));
    await waitFor(() => expect(m.signOut).toHaveBeenCalledTimes(1));
    expect(m.nav).toHaveBeenCalledWith({ to: "/login", replace: true });
  });

  it.each([
    [{ code: "42501", message: "permission denied for table vinculos_usuarios" }],
    [{ status: 403, message: "forbidden" }],
  ])("permissão negada %o mostra acesso negado, não lista vazia", async (error) => {
    m.resultado.mockReturnValue({ data: null, error });
    montar();
    expect(await screen.findByText(MENSAGENS_SYS04.negado)).toBeTruthy();
    expect(screen.queryByText(MENSAGENS_SYS04.vazio)).toBeNull();
    expect(screen.queryByText(/permission denied/)).toBeNull();
  });

  it("erro técnico mostra mensagem genérica e retry funciona", async () => {
    m.resultado.mockReturnValueOnce({ data: null, error: { code: "XX000", message: "internal boom" } });
    montar();
    expect(await screen.findByText(MENSAGENS_SYS04.erro)).toBeTruthy();
    expect(screen.queryByText(/boom/)).toBeNull();
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa")], error: null });
    fireEvent.click(screen.getByRole("button", { name: "Tentar novamente" }));
    expect(await screen.findByRole("radio", { name: /Alfa/ })).toBeTruthy();
  });

  it("organização aninhada null aparece indisponível e não selecionável", async () => {
    m.resultado.mockReturnValue({ data: [{ id: "v-x", perfil: "admin", organizacao: null }], error: null });
    montar();
    expect(await screen.findByText(MENSAGENS_SYS04.indisponivel)).toBeTruthy();
    expect(screen.queryByText(MENSAGENS_SYS04.vazio)).toBeNull();
    expect(screen.queryAllByRole("radio")).toHaveLength(0);
  });

  it("um vínculo vem pré-selecionado e exige clique", async () => {
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa")], error: null });
    montar();
    const r = await screen.findByRole("radio", { name: /Alfa/ });
    expect(r.getAttribute("aria-checked")).toBe("true");
    expect(m.nav).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Continuar" }));
    await waitFor(() => expect(m.nav).toHaveBeenCalledWith({ to: "/" }));
    expect(obterPreferenciaOrganizacao(U)).toBe("o1");
  });

  it("vários vínculos: Continuar desabilitado até selecionar", async () => {
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa"), org("o2", "Beta")], error: null });
    montar();
    await screen.findByRole("radio", { name: /Beta/ });
    const btn = screen.getByRole("button", { name: "Continuar" }) as HTMLButtonElement;
    expect(btn.disabled).toBe(true);
    fireEvent.click(screen.getByRole("radio", { name: /Beta/ }));
    expect(btn.disabled).toBe(false);
  });

  it("trocar organização chama clear() antes de gravar e navegar", async () => {
    definirPreferenciaOrganizacao(U, "o1");
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa"), org("o2", "Beta")], error: null });
    montar();
    const ordem: string[] = [];
    const clear = vi.spyOn(qc, "clear").mockImplementation(() => {
      ordem.push(`clear:${obterPreferenciaOrganizacao(U)}`);
    });
    m.nav.mockImplementation(() => ordem.push("nav"));
    fireEvent.click(await screen.findByRole("radio", { name: /Beta/ }));
    fireEvent.click(screen.getByRole("button", { name: "Continuar" }));
    await waitFor(() => expect(m.nav).toHaveBeenCalled());
    expect(clear).toHaveBeenCalledTimes(1);
    expect(ordem).toEqual(["clear:o1", "nav"]);
    expect(obterPreferenciaOrganizacao(U)).toBe("o2");
  });

  it("manter a mesma organização não chama clear()", async () => {
    definirPreferenciaOrganizacao(U, "o1");
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa"), org("o2", "Beta")], error: null });
    montar();
    const clear = vi.spyOn(qc, "clear");
    fireEvent.click(await screen.findByRole("radio", { name: /Alfa/ }));
    fireEvent.click(screen.getByRole("button", { name: "Continuar" }));
    await waitFor(() => expect(m.nav).toHaveBeenCalled());
    expect(clear).not.toHaveBeenCalled();
  });

  it("duplo clique gera uma única navegação", async () => {
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa")], error: null });
    montar();
    await screen.findByRole("radio", { name: /Alfa/ });
    const btn = screen.getByRole("button", { name: "Continuar" });
    fireEvent.click(btn);
    fireEvent.click(btn);
    await waitFor(() => expect(m.nav).toHaveBeenCalled());
    expect(m.nav).toHaveBeenCalledTimes(1);
  });

  it.each([
    ["erro do Auth", () => m.getUser.mockResolvedValueOnce({ data: { user: null }, error: { status: 500, message: "auth boom" } })],
    ["promise rejeitada", () => m.getUser.mockRejectedValueOnce(new TypeError("Failed to fetch"))],
  ])("getUser com %s mostra erro genérico, não navega para login, e retry segue", async (_n, prep) => {
    prep();
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa")], error: null });
    montar();
    expect(await screen.findByText(MENSAGENS_SYS04.erro)).toBeTruthy();
    expect(screen.queryByText(/boom|Failed to fetch/)).toBeNull();
    expect(m.nav).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Tentar novamente" }));
    expect(await screen.findByRole("radio", { name: /Alfa/ })).toBeTruthy();
    expect(m.getUser).toHaveBeenCalledTimes(2);
    expect(m.nav).not.toHaveBeenCalled();
  });

  it("radiogroup contém só opções válidas; indisponível fica visível fora dele", async () => {
    m.resultado.mockReturnValue({
      data: [org("o1", "Alfa"), { id: "v-x", perfil: "admin", organizacao: null }],
      error: null,
    });
    montar();
    const grupo = await screen.findByRole("radiogroup");
    const filhos = Array.from(grupo.querySelectorAll("[role]")).map((e) => e.getAttribute("role"));
    expect(filhos).toEqual(["radio"]);
    const ind = screen.getByText(MENSAGENS_SYS04.indisponivel);
    expect(grupo.contains(ind)).toBe(false);
    expect(screen.queryByRole("button", { name: "Sobre o perfil" })).toBeNull();
  });

  it("teclado: ArrowDown seleciona/foca a segunda, ArrowUp volta à primeira", async () => {
    m.resultado.mockReturnValue({ data: [org("o1", "Alfa"), org("o2", "Beta")], error: null });
    montar();
    const a = await screen.findByRole("radio", { name: /Alfa/ });
    const b = screen.getByRole("radio", { name: /Beta/ });
    a.focus();
    fireEvent.keyDown(a, { key: "ArrowDown" });
    await waitFor(() => expect(b.getAttribute("aria-checked")).toBe("true"));
    expect(document.activeElement).toBe(b);
    fireEvent.keyDown(b, { key: "ArrowUp" });
    await waitFor(() => expect(a.getAttribute("aria-checked")).toBe("true"));
    expect(document.activeElement).toBe(a);
  });
});

describe("preferência local por usuário (não autoritativa)", () => {
  beforeEach(() => sessionStorage.clear());
  it("preferência de outro usuário é ignorada", () => {
    definirPreferenciaOrganizacao("user-A", "org-A");
    expect(obterPreferenciaOrganizacao("user-B")).toBeNull();
    expect(obterPreferenciaOrganizacao("user-A")).toBe("org-A");
  });
  it("valor corrompido é ignorado", () => {
    sessionStorage.setItem("contaos.preferenciaOrganizacao", "{lixo");
    expect(obterPreferenciaOrganizacao("user-A")).toBeNull();
  });
});
