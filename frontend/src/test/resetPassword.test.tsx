import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, act } from "@testing-library/react";
import type { ReactNode } from "react";

const m = vi.hoisted(() => ({
  update: vi.fn(),
  signOut: vi.fn(),
  getSession: vi.fn(),
  cb: null as null | ((e: string, s: unknown) => void),
}));
vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    auth: {
      updateUser: m.update,
      signOut: m.signOut,
      getSession: m.getSession,
      onAuthStateChange: (cb: (e: string, s: unknown) => void) => {
        m.cb = cb;
        return { data: { subscription: { unsubscribe: vi.fn() } } };
      },
    },
  },
}));
vi.mock("@tanstack/react-router", () => ({
  Link: ({ children, to, ...p }: { children: ReactNode; to: string }) => (
    <a href={to} {...p}>{children}</a>
  ),
}));

import { ResetPasswordForm, MENSAGENS_SYS03 } from "@/components/auth/ResetPasswordForm";

beforeEach(() => {
  vi.clearAllMocks();
  m.getSession.mockResolvedValue({ data: { session: null } });
  m.signOut.mockResolvedValue({ error: null });
  window.history.replaceState(null, "", "/redefinir-senha");
});
afterEach(() => vi.useRealTimers());

async function abrirComRecuperacao() {
  render(<ResetPasswordForm />);
  act(() => m.cb?.("PASSWORD_RECOVERY", { user: {} }));
  return screen.findByLabelText("Nova senha");
}
function preencher(a: string, b: string) {
  fireEvent.change(screen.getByLabelText("Nova senha"), { target: { value: a } });
  fireEvent.change(screen.getByLabelText("Confirmar nova senha"), { target: { value: b } });
  fireEvent.click(screen.getByRole("button", { name: "Salvar nova senha" }));
}

describe("SYS-03 Redefinir senha", () => {
  it("sem evento/sessão de recuperação mostra link inválido após o tempo", async () => {
    vi.useFakeTimers();
    render(<ResetPasswordForm />);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(3100);
    });
    expect(screen.getByText(MENSAGENS_SYS03.linkInvalido)).toBeTruthy();
    expect(screen.queryByLabelText("Nova senha")).toBeNull();
  });

  it("hash com otp_expired mostra link inválido", async () => {
    window.history.replaceState(null, "", "/redefinir-senha#error=access_denied&error_code=otp_expired");
    render(<ResetPasswordForm />);
    expect(await screen.findByText(MENSAGENS_SYS03.linkInvalido)).toBeTruthy();
  });

  it("PASSWORD_RECOVERY libera o formulário", async () => {
    expect(await abrirComRecuperacao()).toBeTruthy();
  });

  it("SIGNED_IN com sessão comum NÃO libera o formulário", async () => {
    vi.useFakeTimers();
    render(<ResetPasswordForm />);
    act(() => m.cb?.("SIGNED_IN", { user: {} }));
    await act(async () => {
      await vi.advanceTimersByTimeAsync(3100);
    });
    expect(screen.queryByLabelText("Nova senha")).toBeNull();
    expect(screen.getByText(MENSAGENS_SYS03.linkInvalido)).toBeTruthy();
  });

  it("getSession com sessão comum NÃO libera o formulário", async () => {
    vi.useFakeTimers();
    m.getSession.mockResolvedValue({ data: { session: { user: {} } } });
    render(<ResetPasswordForm />);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(3100);
    });
    expect(screen.queryByLabelText("Nova senha")).toBeNull();
    expect(screen.getByText(MENSAGENS_SYS03.linkInvalido)).toBeTruthy();
  });

  it("validação local: vazia e não conferem não chamam updateUser", async () => {
    await abrirComRecuperacao();
    preencher("", "");
    expect(await screen.findByText(MENSAGENS_SYS03.senhaVazia)).toBeTruthy();
    preencher("SenhaLonga123", "Outra123456");
    expect(await screen.findByText(MENSAGENS_SYS03.naoConferem)).toBeTruthy();
    expect(m.update).not.toHaveBeenCalled();
  });

  it("senha curta não é bloqueada localmente; weak_password do backend mostra fraca", async () => {
    m.update.mockResolvedValue({ data: null, error: { status: 422, code: "weak_password" } });
    await abrirComRecuperacao();
    preencher("curta", "curta");
    expect(await screen.findByText(MENSAGENS_SYS03.fraca)).toBeTruthy();
    expect(m.update).toHaveBeenCalledWith({ password: "curta" });
  });

  it("duplo envio gera uma única chamada; sucesso chama signOut", async () => {
    let resolver!: (v: unknown) => void;
    m.update.mockReturnValue(new Promise((r) => (resolver = r)));
    await abrirComRecuperacao();
    preencher("SenhaLonga123", "SenhaLonga123");
    fireEvent.submit(screen.getByRole("button", { name: /Salvando/ }).closest("form")!);
    expect(m.update).toHaveBeenCalledTimes(1);
    expect(m.update).toHaveBeenCalledWith({ password: "SenhaLonga123" });
    resolver({ data: {}, error: null });
    expect(await screen.findByText(MENSAGENS_SYS03.sucesso)).toBeTruthy();
    expect(m.signOut).toHaveBeenCalledTimes(1);
  });

  it.each([
    [{ status: 422, code: "weak_password" }, MENSAGENS_SYS03.fraca],
    [{ status: 422, code: "same_password" }, MENSAGENS_SYS03.mesma],
    [{ status: 429, code: "over_request_rate_limit" }, MENSAGENS_SYS03.rateLimit],
    [{ status: 401, code: "session_not_found" }, MENSAGENS_SYS03.linkInvalido],
    [{ status: 500, code: "unexpected_failure" }, MENSAGENS_SYS03.falha],
  ])("erro %o mostra a copy correta sem nova chamada", async (error, copy) => {
    m.update.mockResolvedValue({ data: null, error });
    await abrirComRecuperacao();
    preencher("SenhaLonga123", "SenhaLonga123");
    expect(await screen.findByText(copy)).toBeTruthy();
    await new Promise((r) => setTimeout(r, 30));
    expect(m.update).toHaveBeenCalledTimes(1);
    expect(m.signOut).not.toHaveBeenCalled();
  });

  it("erro de rede mostra falha genérica", async () => {
    m.update.mockRejectedValue(new TypeError("Failed to fetch"));
    await abrirComRecuperacao();
    preencher("SenhaLonga123", "SenhaLonga123");
    await waitFor(() => expect(screen.getByText(MENSAGENS_SYS03.falha)).toBeTruthy());
  });

  it("toque na dica de política abre e mantém a dica visível", async () => {
    await abrirComRecuperacao();
    const g = screen.getByLabelText("Sobre a política de senha");
    fireEvent.focus(g);
    fireEvent.click(g);
    await new Promise((r) => setTimeout(r, 30));
    expect(screen.getAllByText(MENSAGENS_SYS03.tooltipPolitica).length).toBeGreaterThan(0);
  });
});