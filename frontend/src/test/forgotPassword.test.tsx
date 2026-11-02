import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import type { ReactNode } from "react";

const m = vi.hoisted(() => ({ reset: vi.fn() }));
vi.mock("@/integrations/supabase/client", () => ({
  supabase: { auth: { resetPasswordForEmail: m.reset } },
}));
vi.mock("@tanstack/react-router", () => ({
  Link: ({ children, to, ...p }: { children: ReactNode; to: string }) => (
    <a href={to} {...p}>{children}</a>
  ),
}));

import { ForgotPasswordForm, MENSAGENS_SYS02 } from "@/components/auth/ForgotPasswordForm";

function enviar(email: string) {
  fireEvent.change(screen.getByLabelText("E-mail"), { target: { value: email } });
  fireEvent.click(screen.getByRole("button", { name: "Enviar link" }));
}

beforeEach(() => vi.clearAllMocks());

describe("SYS-02 Esqueci a senha", () => {
  it("e-mail inválido não chama o Supabase", async () => {
    render(<ForgotPasswordForm />);
    enviar("invalido");
    expect(await screen.findByText(MENSAGENS_SYS02.emailInvalido)).toBeTruthy();
    expect(m.reset).not.toHaveBeenCalled();
  });

  it("duplo envio gera uma única chamada", async () => {
    let resolver!: (v: unknown) => void;
    m.reset.mockReturnValue(new Promise((r) => (resolver = r)));
    render(<ForgotPasswordForm />);
    enviar("a@b.com");
    fireEvent.submit(screen.getByRole("button", { name: /Enviando/ }).closest("form")!);
    expect(m.reset).toHaveBeenCalledTimes(1);
    resolver({ data: {}, error: null });
    await screen.findByText(MENSAGENS_SYS02.sucesso);
  });

  it("sucesso usa copy neutra e redirectTo /redefinir-senha", async () => {
    m.reset.mockResolvedValue({ data: {}, error: null });
    render(<ForgotPasswordForm />);
    enviar("a@b.com");
    expect(await screen.findByText(MENSAGENS_SYS02.sucesso)).toBeTruthy();
    expect(m.reset.mock.calls[0]?.[1]?.redirectTo).toMatch(/\/redefinir-senha$/);
  });

  it("erro que revela conta vira a mesma copy neutra", async () => {
    m.reset.mockResolvedValue({ data: null, error: { status: 404, code: "user_not_found" } });
    render(<ForgotPasswordForm />);
    enviar("x@b.com");
    expect(await screen.findByText(MENSAGENS_SYS02.sucesso)).toBeTruthy();
  });

  it("erro inesperado mostra falha genérica", async () => {
    m.reset.mockResolvedValue({ data: null, error: { status: 400, code: "captcha_failed" } });
    render(<ForgotPasswordForm />);
    enviar("a@b.com");
    expect(await screen.findByText(MENSAGENS_SYS02.falha)).toBeTruthy();
  });

  it.each(["over_email_send_rate_limit", "over_request_rate_limit"])(
    "429 (%s) mostra exatamente a copy neutra de sucesso, sem nova chamada automática",
    async (code) => {
      m.reset.mockResolvedValue({ data: null, error: { status: 429, code } });
      render(<ForgotPasswordForm />);
      enviar("a@b.com");
      expect(await screen.findByText(MENSAGENS_SYS02.sucesso)).toBeTruthy();
      expect(screen.queryByText(/Muitas solicitações/)).toBeNull();
      await new Promise((r) => setTimeout(r, 50));
      expect(m.reset).toHaveBeenCalledTimes(1);
    },
  );

  it("erro de rede mostra falha genérica", async () => {
    m.reset.mockRejectedValue(new TypeError("Failed to fetch"));
    render(<ForgotPasswordForm />);
    enviar("a@b.com");
    await waitFor(() => expect(screen.getByText(MENSAGENS_SYS02.falha)).toBeTruthy());
  });

  it("toque/clique na dica de segurança abre e mantém a dica visível", async () => {
    m.reset.mockResolvedValue({ data: {}, error: null });
    render(<ForgotPasswordForm />);
    enviar("a@b.com");
    const gatilho = await screen.findByLabelText("Por que não confirmamos o cadastro");
    fireEvent.focus(gatilho);
    fireEvent.click(gatilho);
    await new Promise((r) => setTimeout(r, 50));
    expect(screen.getAllByText(MENSAGENS_SYS02.tooltipNeutro).length).toBeGreaterThan(0);
  });
});