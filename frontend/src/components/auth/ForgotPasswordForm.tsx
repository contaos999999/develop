import { useRef, useState, type FormEvent } from "react";
import { Link } from "@tanstack/react-router";
import { AlertCircle, ArrowLeft, Info, Loader2, MailCheck } from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const MENSAGENS_SYS02 = {
  emailInvalido: "Informe um e-mail válido.",
  sucesso:
    "Se existir uma conta vinculada a este e-mail, você receberá as instruções para redefinir sua senha.",
  falha: "Não foi possível enviar a solicitação agora. Tente novamente em instantes.",
  tooltipNeutro: "Por segurança, não informamos se o e-mail possui cadastro.",
} as const;

type Fase = "inicial" | "enviando" | "sucesso";
type Erro = "falha" | null;

// Erros cujo único efeito seria revelar existência/inexistência de conta.
const CODIGOS_ENUMERACAO = new Set(["user_not_found", "email_not_found"]);

export function classificarRespostaReset(
  error: { status?: number | undefined; code?: string | undefined } | null,
): "sucesso" | "falha" {
  if (!error) return "sucesso";
  if (error.code && CODIGOS_ENUMERACAO.has(error.code)) return "sucesso";
  // Anti-enumeração: o limite por e-mail do Auth só atinge contas existentes,
  // então 429 recebe a mesma resposta neutra do sucesso.
  if (error.status === 429 || error.code === "over_email_send_rate_limit" || error.code === "over_request_rate_limit")
    return "sucesso";
  return "falha";
}

export function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [dicaAberta, setDicaAberta] = useState(false);
  const [fase, setFase] = useState<Fase>("inicial");
  const [erro, setErro] = useState<Erro>(null);
  const [erroEmail, setErroEmail] = useState<string | null>(null);
  const emAndamento = useRef(false);
  const emailRef = useRef<HTMLInputElement>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (emAndamento.current) return;
    setErro(null);
    const valor = email.trim();
    if (!EMAIL_RE.test(valor)) {
      setErroEmail(MENSAGENS_SYS02.emailInvalido);
      emailRef.current?.focus();
      return;
    }
    setErroEmail(null);
    emAndamento.current = true;
    setFase("enviando");
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(valor, {
        redirectTo: `${window.location.origin}/redefinir-senha`,
      });
      const r = classificarRespostaReset(error);
      if (r === "sucesso") setFase("sucesso");
      else {
        setErro(r);
        setFase("inicial");
      }
    } catch {
      setErro("falha");
      setFase("inicial");
    } finally {
      emAndamento.current = false;
    }
  }

  const enviando = fase === "enviando";

  return (
    <div className="space-y-5">
      <div aria-live="polite" className="sr-only">
        {enviando ? "Enviando solicitação." : fase === "sucesso" ? "Solicitação recebida." : ""}
      </div>

      {fase === "sucesso" ? (
        <div className="space-y-4">
          <div className="flex gap-3 rounded-lg border border-border bg-muted/50 p-4">
            <MailCheck className="mt-0.5 h-5 w-5 shrink-0 text-primary" aria-hidden />
            <div className="space-y-1">
              <div className="flex items-center gap-1.5">
                <p className="text-sm font-semibold text-foreground">Solicitação recebida</p>
                <TooltipProvider delayDuration={200}>
                  <Tooltip open={dicaAberta} onOpenChange={setDicaAberta}>
                    <TooltipTrigger asChild>
                      <button
                        type="button"
                        aria-label="Por que não confirmamos o cadastro"
                        onClick={(e) => {
                          // Toque: abre de forma idempotente e impede o fechamento padrão do Radix no clique.
                          e.preventDefault();
                          setDicaAberta(true);
                        }}
                        className="rounded text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                      >
                        <Info className="h-4 w-4" aria-hidden />
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>{MENSAGENS_SYS02.tooltipNeutro}</TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
              <p className="text-sm text-muted-foreground">{MENSAGENS_SYS02.sucesso}</p>
              <p className="text-xs text-muted-foreground">Verifique também a caixa de spam.</p>
            </div>
          </div>
          <Button type="button" variant="outline" className="h-11 w-full" onClick={() => setFase("inicial")}>
            Enviar novamente
          </Button>
        </div>
      ) : (
        <form noValidate onSubmit={handleSubmit} className="space-y-5" aria-busy={enviando}>
          {erro && (
            <Alert variant="destructive" role="alert">
              <AlertCircle className="h-4 w-4" aria-hidden />
              <AlertDescription>{MENSAGENS_SYS02[erro]}</AlertDescription>
            </Alert>
          )}
          <div className="space-y-2">
            <Label htmlFor="esqueci-email">E-mail</Label>
            <Input
              id="esqueci-email"
              ref={emailRef}
              type="email"
              inputMode="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              readOnly={enviando}
              aria-invalid={!!erroEmail}
              aria-describedby={erroEmail ? "esqueci-email-erro" : undefined}
              className="h-11"
            />
            {erroEmail && (
              <p id="esqueci-email-erro" role="alert" className="flex items-center gap-1 text-sm text-destructive">
                <AlertCircle className="h-3.5 w-3.5" aria-hidden /> {erroEmail}
              </p>
            )}
          </div>
          <Button type="submit" className="h-11 w-full" disabled={enviando}>
            {enviando ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> Enviando…
              </>
            ) : (
              "Enviar link"
            )}
          </Button>
        </form>
      )}

      <Link
        to="/login"
        className="inline-flex items-center gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline focus-visible:underline"
      >
        <ArrowLeft className="h-4 w-4" aria-hidden /> Voltar ao login
      </Link>
    </div>
  );
}