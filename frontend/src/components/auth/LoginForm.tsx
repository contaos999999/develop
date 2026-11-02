import { useEffect, useRef, useState, type FormEvent } from "react";
import { AlertCircle, Eye, EyeOff, Loader2, LogOut, ShieldAlert } from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import {
  resolverDestinoPosLogin,
  type VinculoUsuario,
} from "@/lib/auth/resolverDestinoPosLogin";

type Fase =
  | "inicial"
  | "enviando"
  | "carregando-vinculos"
  | "sem-acesso"
  | "erro-vinculos"
  | "redirecionando";

type ErroGeral = "credencial" | "rede" | null;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const MENSAGENS = {
  credencial: "E-mail ou senha inválidos.",
  rede: "Não foi possível conectar. Tente novamente.",
  semAcesso:
    "Seu usuário não possui acesso ativo a nenhuma organização. Procure o administrador.",
  erroVinculos: "Não foi possível carregar seus acessos. Tente novamente.",
  emailInvalido: "Informe um e-mail válido.",
  senhaVazia: "Informe sua senha.",
} as const;

type Props = {
  /** Navegação pós-login. Injetável para testes. */
  onNavegar?: (rota: string) => void;
};

// DEPENDÊNCIA DE FRONTEND: /selecionar-organizacao (SYS-04) e / (SYS-05) ainda
// não implementadas; navegação por URL evita criar rotas fora do escopo.
const navegarPadrao = (rota: string) => window.location.assign(rota);

function ehErroDeCredencial(err: { status?: number | undefined; code?: string | undefined }) {
  if (err.status === 400 || err.status === 401 || err.status === 422) return true;
  return err.code === "invalid_credentials";
}

export function LoginForm({ onNavegar = navegarPadrao }: Props) {
  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [mostrarSenha, setMostrarSenha] = useState(false);
  const [fase, setFase] = useState<Fase>("inicial");
  const [erroGeral, setErroGeral] = useState<ErroGeral>(null);
  const [erroEmail, setErroEmail] = useState<string | null>(null);
  const [erroSenha, setErroSenha] = useState<string | null>(null);
  const emailRef = useRef<HTMLInputElement>(null);
  const senhaRef = useRef<HTMLInputElement>(null);

  async function carregarVinculos() {
    setFase("carregando-vinculos");
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      setFase("inicial");
      return;
    }
    // RLS é a autoridade. O filtro por id_usuario apenas seleciona os vínculos
    // do próprio usuário (perfis administrativos enxergam vínculos de terceiros).
    const { data, error } = await supabase
      .from("vinculos_usuarios")
      .select("id, id_organizacao, perfil")
      .eq("id_usuario", userData.user.id)
      .eq("ativo", true);
    if (error) {
      setFase("erro-vinculos");
      return;
    }
    const destino = resolverDestinoPosLogin((data ?? []) as VinculoUsuario[]);
    if (destino.tipo === "sem-acesso") {
      setFase("sem-acesso");
      return;
    }
    setFase("redirecionando");
    onNavegar(destino.rota);
  }

  useEffect(() => {
    let ativo = true;
    supabase.auth.getSession().then(({ data }) => {
      if (ativo && data.session) void carregarVinculos();
    });
    return () => {
      ativo = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (fase === "enviando") return;
    setErroGeral(null);
    const eEmail = EMAIL_RE.test(email.trim()) ? null : MENSAGENS.emailInvalido;
    const eSenha = senha.length > 0 ? null : MENSAGENS.senhaVazia;
    setErroEmail(eEmail);
    setErroSenha(eSenha);
    if (eEmail) return emailRef.current?.focus();
    if (eSenha) return senhaRef.current?.focus();

    setFase("enviando");
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: senha,
      });
      if (error) {
        setErroGeral(ehErroDeCredencial(error) ? "credencial" : "rede");
        setFase("inicial");
        return;
      }
    } catch {
      setErroGeral("rede");
      setFase("inicial");
      return;
    }
    await carregarVinculos();
  }

  async function handleSair() {
    await supabase.auth.signOut();
    setSenha("");
    setFase("inicial");
  }

  const enviando = fase === "enviando";
  const ocupado = enviando || fase === "carregando-vinculos" || fase === "redirecionando";

  if (fase === "sem-acesso" || fase === "erro-vinculos") {
    const semAcesso = fase === "sem-acesso";
    return (
      <div className="space-y-4">
        <Alert variant={semAcesso ? "default" : "destructive"} role="alert">
          {semAcesso ? <ShieldAlert className="h-4 w-4" aria-hidden /> : <AlertCircle className="h-4 w-4" aria-hidden />}
          <AlertTitle>{semAcesso ? "Acesso não disponível" : "Erro ao carregar acessos"}</AlertTitle>
          <AlertDescription>{semAcesso ? MENSAGENS.semAcesso : MENSAGENS.erroVinculos}</AlertDescription>
        </Alert>
        <div className="flex flex-col gap-2 sm:flex-row">
          {!semAcesso && (
            <Button className="min-h-11 flex-1" onClick={() => void carregarVinculos()}>
              Tentar novamente
            </Button>
          )}
          <Button variant="outline" className="min-h-11 flex-1" onClick={() => void handleSair()}>
            <LogOut className="h-4 w-4" aria-hidden /> Sair
          </Button>
        </div>
      </div>
    );
  }

  return (
    <form noValidate onSubmit={handleSubmit} aria-busy={ocupado} className="space-y-5">
      <div aria-live="polite" className="sr-only">
        {enviando ? "Entrando…" : fase === "carregando-vinculos" ? "Carregando seus acessos…" : ""}
      </div>

      {erroGeral && (
        <Alert variant="destructive" role="alert">
          <AlertCircle className="h-4 w-4" aria-hidden />
          <AlertDescription>{MENSAGENS[erroGeral]}</AlertDescription>
        </Alert>
      )}

      <div className="space-y-2">
        <Label htmlFor="login-email">E-mail</Label>
        <Input
          id="login-email"
          ref={emailRef}
          type="email"
          autoComplete="email"
          inputMode="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          readOnly={ocupado}
          aria-invalid={!!erroEmail}
          aria-describedby={erroEmail ? "login-email-erro" : undefined}
          className="h-11"
        />
        {erroEmail && (
          <p id="login-email-erro" role="alert" className="flex items-center gap-1 text-sm text-destructive">
            <AlertCircle className="h-3.5 w-3.5" aria-hidden /> {erroEmail}
          </p>
        )}
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between gap-2">
          <Label htmlFor="login-senha">Senha</Label>
          <a href="/esqueci-senha" className="text-sm font-medium text-primary underline-offset-4 hover:underline focus-visible:underline">
            Esqueci minha senha
          </a>
        </div>
        <div className="relative">
          <Input
            id="login-senha"
            ref={senhaRef}
            type={mostrarSenha ? "text" : "password"}
            autoComplete="current-password"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
            readOnly={ocupado}
            aria-invalid={!!erroSenha}
            aria-describedby={erroSenha ? "login-senha-erro" : undefined}
            className="h-11 pr-12"
          />
          <TooltipProvider delayDuration={200}>
            <Tooltip>
              <TooltipTrigger asChild>
              <button
                type="button"
                onClick={() => setMostrarSenha((v) => !v)}
                aria-label={mostrarSenha ? "Ocultar senha" : "Mostrar senha"}
                aria-pressed={mostrarSenha}
                aria-controls="login-senha"
                className="absolute inset-y-0 right-0 flex w-11 items-center justify-center rounded-r-md text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                {mostrarSenha ? <EyeOff className="h-4 w-4" aria-hidden /> : <Eye className="h-4 w-4" aria-hidden />}
              </button>
              </TooltipTrigger>
              <TooltipContent side="top">{mostrarSenha ? "Ocultar senha" : "Mostrar senha"}</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
        {erroSenha && (
          <p id="login-senha-erro" role="alert" className="flex items-center gap-1 text-sm text-destructive">
            <AlertCircle className="h-3.5 w-3.5" aria-hidden /> {erroSenha}
          </p>
        )}
      </div>

      <Button type="submit" disabled={ocupado} className="h-11 w-full">
        {ocupado && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
        {enviando ? "Entrando…" : fase === "inicial" ? "Entrar" : "Carregando seus acessos…"}
      </Button>
    </form>
  );
}
