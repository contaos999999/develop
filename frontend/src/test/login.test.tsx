import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { QueryClient } from "@tanstack/react-query";
import { createRouter } from "@tanstack/react-router";

const m = vi.hoisted(() => {
  const auth = {
    getSession: vi.fn(),
    getUser: vi.fn(),
    signInWithPassword: vi.fn(),
    signOut: vi.fn(),
  };
  const state: { r: { data: unknown; error: unknown } } = { r: { data: [], error: null } };
  const query: Record<string, unknown> = {};
  query["select"] = () => query;
  query["eq"] = () => query;
  query["then"] = (res: (v: unknown) => void) => res(state.r);
  return { auth, state, query };
});
const auth = m.auth;
vi.mock("@/integrations/supabase/client", () => ({
  supabase: { auth: m.auth, from: () => m.query },
}));

import { LoginForm, MENSAGENS } from "@/components/auth/LoginForm";
import { routeTree } from "@/routeTree.gen";

function preencher(email: string, senha: string) {
  fireEvent.change(screen.getByLabelText("E-mail"), { target: { value: email } });
  fireEvent.change(screen.getByLabelText("Senha"), { target: { value: senha } });
  fireEvent.click(screen.getByRole("button", { name: "Entrar" }));
}

beforeEach(() => {
  vi.clearAllMocks();
  auth.getSession.mockResolvedValue({ data: { session: null } });
  auth.getUser.mockResolvedValue({ data: { user: { id: "u1" } }, error: null });
  m.state.r = { data: [], error: null };
});

describe("SYS-01 Login", () => {
  it("rota /login existe", () => {
    const router = createRouter({ routeTree, context: { queryClient: new QueryClient() } });
    expect(router.matchRoutes("/login").at(-1)?.routeId).toBe("/login");
  });

  it("campos têm label visível", () => {
    render(<LoginForm onNavegar={vi.fn()} />);
    expect(screen.getByLabelText("E-mail")).toHaveAttribute("type", "email");
    expect(screen.getByLabelText("Senha")).toHaveAttribute("type", "password");
    expect(screen.getByRole("button", { name: "Mostrar senha" })).toBeInTheDocument();
  });

  it("valida e-mail e senha sem chamar o backend", () => {
    render(<LoginForm onNavegar={vi.fn()} />);
    preencher("invalido", "");
    expect(screen.getByText(MENSAGENS.emailInvalido)).toBeInTheDocument();
    expect(auth.signInWithPassword).not.toHaveBeenCalled();
  });

  it("desabilita Entrar durante o envio", async () => {
    auth.signInWithPassword.mockReturnValue(new Promise(() => {}));
    render(<LoginForm onNavegar={vi.fn()} />);
    preencher("a@b.com", "x");
    await waitFor(() => expect(screen.getByRole("button", { name: /Entrando/ })).toBeDisabled());
  });

  it("erro de credencial usa mensagem genérica", async () => {
    auth.signInWithPassword.mockResolvedValue({ error: { status: 400, code: "invalid_credentials" } });
    render(<LoginForm onNavegar={vi.fn()} />);
    preencher("a@b.com", "x");
    expect(await screen.findByText(MENSAGENS.credencial)).toBeInTheDocument();
  });

  it("erro de rede mostra mensagem de conexão", async () => {
    auth.signInWithPassword.mockRejectedValue(new Error("fetch"));
    render(<LoginForm onNavegar={vi.fn()} />);
    preencher("a@b.com", "x");
    expect(await screen.findByText(MENSAGENS.rede)).toBeInTheDocument();
  });

  it("sem vínculos mostra acesso não disponível", async () => {
    auth.signInWithPassword.mockResolvedValue({ error: null });
    render(<LoginForm onNavegar={vi.fn()} />);
    preencher("a@b.com", "x");
    expect(await screen.findByText(MENSAGENS.semAcesso)).toBeInTheDocument();
  });

  it("vários vínculos navega para /selecionar-organizacao", async () => {
    auth.signInWithPassword.mockResolvedValue({ error: null });
    m.state.r = { data: [{ id: "1" }, { id: "2" }], error: null };
    const nav = vi.fn();
    render(<LoginForm onNavegar={nav} />);
    preencher("a@b.com", "x");
    await waitFor(() => expect(nav).toHaveBeenCalledWith("/selecionar-organizacao"));
  });
});
