import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link } from "@tanstack/react-router";
import { AlertCircle, ArrowLeft, CheckCircle2, Eye, EyeOff, Info, Loader2, ShieldAlert } from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

export const MENSAGENS_SYS03 = {
  verificando: "Validando link de redefinição…",
  linkInvalido: "Este link de redefinição é inválido ou expirou. Solicite um novo link.",
  senhaVazia: "Informe a nova senha.",
  naoConferem: "As senhas não conferem.",
  sucesso: "Senha redefinida com sucesso. Entre novamente com a nova senha.",
  fraca: "A senha não atende à política de segurança. Escolha outra senha.",
  mesma: "A nova senha deve ser diferente da anterior.",
  rateLimit: "Muitas tentativas. Aguarde alguns instantes e tente novamente.",
  falha: "Não foi possível redefinir a senha agora. Tente novamente em instantes.",
  tooltipPolitica: "A senha deve seguir a política de segurança do ContaOS. O sistema valida no envio.",
} as const;

export const TEMPO_VERIFICACAO_MS = 3000;

type Fase = "verificando" | "invalido" | "formulario" | "salvando" | "sucesso";
type ErroForm = "fraca" | "mesma" | "rateLimit" | "falha" | null;

export function classificarErroUpdate(
  error: { status?: number | undefined; code?: string | undefined } | null,
): "sucesso" | "invalido" | Exclude<ErroForm, null> {
  if (!error) return "sucesso";
  if (error.code === "weak_password") return "fraca";
  if (error.code === "same_password") return "mesma";
  if (error.status === 429 || error.code?.startsWith("over_")) return "rateLimit";
  if (error.status === 401 || error.status === 403 || error.code === "session_not_found" || error.code === "session_expired")
    return "invalido";
  return "falha";
}

function hashTemErro() {
  if (typeof window === "undefined") return false;
  const h = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  const q = new URLSearchParams(window.location.search);
  return h.has("error") || h.has("error_code") || q.has("error") || q.has("error_code");
}

function CampoSenha(props: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  erro: string | null;
  readOnly: boolean;
  inputRef?: React.Ref<HTMLInputElement>;
  extra?: React.ReactNode;
}) {
  const [visivel, setVisivel] = useState(false);
  const [dica, setDica] = useState(false);
  const rotulo = visivel ? "Ocultar senha" : "Mostrar senha";
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1.5">
        <Label htmlFor={props.id}>{props.label}</Label>
        {props.extra}
      </div>
      <div className="relative">
        <Input
          id={props.id}
          ref={props.inputRef}
          type={visivel ? "text" : "password"}
          autoComplete="new-password"
          value={props.value}
          onChange={(e) => props.onChange(e.target.value)}
          readOnly={props.readOnly}
          aria-invalid={!!props.erro}
          aria-describedby={props.erro ? `${props.id}-erro` : undefined}
          className="h-11 pr-11"
        />
        <TooltipProvider delayDuration={200}>
          <Tooltip open={dica} onOpenChange={setDica}>
            <TooltipTrigger asChild>
              <button
                type="button"
                aria-label={rotulo}
                aria-pressed={visivel}
                onClick={() => setVisivel((v) => !v)}
                className="absolute right-0 top-0 flex h-11 w-11 items-center justify-center rounded-md text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                {visivel ? <EyeOff className="h-4 w-4" aria-hidden /> : <Eye className="h-4 w-4" aria-hidden />}
              </button>
            </TooltipTrigger>
            <TooltipContent>{rotulo}</TooltipContent>
          </Tooltip>
        </TooltipProvider>
      </div>
      {props.erro && (
        <p id={`${props.id}-erro`} role="alert" className="flex items-center gap-1 text-sm text-destructive">
          <AlertCircle className="h-3.5 w-3.5" aria-hidden /> {props.erro}
        </p>
      )}
    </div>
  );
}

export function ResetPasswordForm() {
  const [fase, setFase] = useState<Fase>("verificando");
  const [senha, setSenha] = useState("");
  const [confirmacao, setConfirmacao] = useState("");
  const [erroSenha, setErroSenha] = useState<string | null>(null);
  const [erroConf, setErroConf] = useState<string | null>(null);
  const [erro, setErro] = useState<ErroForm>(null);
  const [dicaAberta, setDicaAberta] = useState(false);
  const emAndamento = useRef(false);
  const senhaRef = useRef<HTMLInputElement>(null);
  const confRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (hashTemErro()) {
      setFase("invalido");
      return;
    }
    let ativo = true;
    const liberar = () => ativo && setFase((f) => (f === "verificando" ? "formulario" : f));
    const { data } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") liberar();
    });
    const t = setTimeout(() => {
      if (ativo) setFase((f) => (f === "verificando" ? "invalido" : f));
    }, TEMPO_VERIFICACAO_MS);
    return () => {
      ativo = false;
      clearTimeout(t);
      data.subscription.unsubscribe();
    };
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (emAndamento.current) return;
    setErro(null);
    let es: string | null = null;
    let ec: string | null = null;
    if (!senha) es = MENSAGENS_SYS03.senhaVazia;
    if (!es && confirmacao !== senha) ec = MENSAGENS_SYS03.naoConferem;
    setErroSenha(es);
    setErroConf(ec);
    if (es) return senhaRef.current?.focus();
    if (ec) return confRef.current?.focus();

    emAndamento.current = true;
    setFase("salvando");
    try {
      const { error } = await supabase.auth.updateUser({ password: senha });
      const r = classificarErroUpdate(error);
      if (r === "sucesso") {
        await supabase.auth.signOut().catch(() => undefined);
        setFase("sucesso");
      } else if (r === "invalido") {
        setFase("invalido");
      } else {
        setErro(r);
        setFase("formulario");
      }
    } catch {
      setErro("falha");
      setFase("formulario");
    } finally {
      setSenha("");
      setConfirmacao("");
      emAndamento.current = false;
    }
  }

  const salvando = fase === "salvando";
  const anuncio =
    fase === "verificando" ? MENSAGENS_SYS03.verificando : salvando ? "Salvando nova senha." : fase === "sucesso" ? "Senha redefinida." : "";

  const voltar = (
    <Link
      to="/login"
      className="inline-flex items-center gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline focus-visible:underline"
    >
      <ArrowLeft className="h-4 w-4" aria-hidden /> Voltar ao login
    </Link>
  );

  return (
    <div className="space-y-5">
      <div aria-live="polite" className="sr-only">{anuncio}</div>

      {fase === "verificando" && (
        <p className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> <span aria-hidden>{MENSAGENS_SYS03.verificando}</span>
        </p>
      )}

      {fase === "invalido" && (
        <div className="space-y-4">
          <div role="alert" className="flex gap-3 rounded-lg border border-destructive/40 bg-destructive/5 p-4">
            <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-destructive" aria-hidden />
            <p className="text-sm text-foreground">{MENSAGENS_SYS03.linkInvalido}</p>
          </div>
          <Button asChild className="h-11 w-full">
            <Link to="/esqueci-senha">Solicitar novo link</Link>
          </Button>
        </div>
      )}

      {fase === "sucesso" && (
        <div className="space-y-4">
          <div role="status" className="flex gap-3 rounded-lg border border-border bg-muted/50 p-4">
            <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-primary" aria-hidden />
            <p className="text-sm text-foreground">{MENSAGENS_SYS03.sucesso}</p>
          </div>
          <Button asChild className="h-11 w-full">
            <Link to="/login">Ir para o login</Link>
          </Button>
        </div>
      )}

      {(fase === "formulario" || salvando) && (
        <form noValidate onSubmit={handleSubmit} className="space-y-5" aria-busy={salvando}>
          {erro && (
            <Alert variant="destructive" role="alert">
              <AlertCircle className="h-4 w-4" aria-hidden />
              <AlertDescription>{MENSAGENS_SYS03[erro]}</AlertDescription>
            </Alert>
          )}
          <CampoSenha
            id="nova-senha"
            label="Nova senha"
            value={senha}
            onChange={setSenha}
            erro={erroSenha}
            readOnly={salvando}
            inputRef={senhaRef}
            extra={
              <TooltipProvider delayDuration={200}>
                <Tooltip open={dicaAberta} onOpenChange={setDicaAberta}>
                  <TooltipTrigger asChild>
                    <button
                      type="button"
                      aria-label="Sobre a política de senha"
                      onClick={(e) => {
                        e.preventDefault();
                        setDicaAberta(true);
                      }}
                      className="rounded text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    >
                      <Info className="h-4 w-4" aria-hidden />
                    </button>
                  </TooltipTrigger>
                  <TooltipContent>{MENSAGENS_SYS03.tooltipPolitica}</TooltipContent>
                </Tooltip>
              </TooltipProvider>
            }
          />
          <CampoSenha
            id="confirmar-senha"
            label="Confirmar nova senha"
            value={confirmacao}
            onChange={setConfirmacao}
            erro={erroConf}
            readOnly={salvando}
            inputRef={confRef}
          />
          <Button type="submit" className="h-11 w-full" disabled={salvando}>
            {salvando ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> Salvando…
              </>
            ) : (
              "Salvar nova senha"
            )}
          </Button>
        </form>
      )}

      {voltar}
    </div>
  );
}