import { createFileRoute } from "@tanstack/react-router";
import { FileSearch, Lock, ShieldCheck, Sparkles } from "lucide-react";

import { LoginForm } from "@/components/auth/LoginForm";

export const Route = createFileRoute("/login")({
  head: () => ({
    meta: [
      { title: "Entrar — ContaOS" },
      { name: "description", content: "Acesso ao ContaOS: controle, auditoria e conformidade na prestação de contas." },
      { property: "og:title", content: "Entrar — ContaOS" },
      { property: "og:description", content: "Acesso ao ContaOS: controle, auditoria e conformidade na prestação de contas." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: LoginPage,
});

const PILARES = [
  { icone: FileSearch, titulo: "Rastreável", texto: "Fontes, versões e decisões" },
  { icone: Lock, titulo: "Seguro", texto: "Acesso por organização e perfil" },
  { icone: Sparkles, titulo: "Explicável", texto: "IA sempre vinculada à evidência" },
] as const;

function Marca() {
  return (
    <div className="flex items-center gap-3">
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-primary-foreground/20 bg-primary-foreground/10">
        <ShieldCheck className="h-5 w-5" aria-hidden />
      </span>
      <div className="leading-tight">
        <p className="text-lg font-semibold tracking-tight">ContaOS</p>
        <p className="hidden text-[0.65rem] font-medium uppercase tracking-[0.2em] opacity-70 sm:block">
          Controle • Auditoria • Conformidade
        </p>
      </div>
    </div>
  );
}

function BadgeAmbiente() {
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-primary-foreground/20 bg-primary-foreground/10 px-3 py-1 text-xs font-medium">
      <span className="h-1.5 w-1.5 rounded-full bg-primary-foreground" aria-hidden />
      Ambiente seguro de homologação
    </span>
  );
}

function PainelInstitucional() {
  return (
    <aside className="relative isolate overflow-hidden bg-primary text-primary-foreground lg:flex lg:w-[48%] lg:flex-col">
      {/* Profundidade: grid sutil + glows desfocados (decorativos) */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 text-primary-foreground opacity-[0.06]"
        style={{
          backgroundImage:
            "linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)",
          backgroundSize: "48px 48px",
        }}
      />
      <div aria-hidden className="pointer-events-none absolute -left-24 -top-24 -z-10 h-80 w-80 rounded-full bg-chart-2/25 blur-3xl" />
      <div aria-hidden className="pointer-events-none absolute -bottom-32 right-0 -z-10 h-96 w-96 rounded-full bg-chart-1/20 blur-3xl" />

      {/* Faixa compacta: 390 / 768 */}
      <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-4 md:px-10 md:py-5 lg:hidden">
        <Marca />
        <BadgeAmbiente />
      </div>

      {/* Painel completo: 1280 / 1440 */}
      <div className="hidden flex-1 flex-col justify-between gap-10 px-12 py-12 xl:px-16 lg:flex">
        <div className="flex items-center justify-between gap-4">
          <Marca />
        </div>

        <div className="max-w-xl space-y-6">
          <BadgeAmbiente />
          <h2 className="text-4xl font-semibold leading-tight tracking-tight xl:text-[2.75rem]">
            Inteligência e governança para cada etapa da prestação de contas.
          </h2>
          <p className="max-w-lg text-base opacity-80">
            Requisitos, evidências, apontamentos e pareceres do contratante reunidos em um ambiente
            auditável, com cada decisão ligada à sua fonte.
          </p>
          <ul className="grid grid-cols-3 gap-3 pt-2">
            {PILARES.map(({ icone: Icone, titulo, texto }) => (
              <li
                key={titulo}
                className="rounded-xl border border-primary-foreground/15 bg-primary-foreground/5 p-4 backdrop-blur-sm"
              >
                <Icone className="mb-3 h-5 w-5 opacity-90" aria-hidden />
                <p className="text-sm font-semibold">{titulo}</p>
                <p className="mt-1 text-xs opacity-75">{texto}</p>
              </li>
            ))}
          </ul>
        </div>

        <div className="flex items-center justify-between gap-4 border-t border-primary-foreground/15 pt-5 text-xs opacity-70">
          <span>ContaOS • Ambiente HML</span>
          <span>Segurança e rastreabilidade por padrão</span>
        </div>
      </div>
    </aside>
  );
}

function LoginPage() {
  return (
    <div lang="pt-BR" className="flex min-h-screen flex-col bg-background lg:flex-row">
      <PainelInstitucional />

      <main className="flex flex-1 items-center justify-center px-4 py-8 sm:px-6 md:py-12">
        <div className="w-full max-w-md space-y-5">
          <div className="space-y-2">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              Acesso ao ContaOS
            </p>
            <h1 className="text-3xl font-semibold tracking-tight text-foreground">Bem-vindo de volta</h1>
            <p className="text-sm text-muted-foreground">
              Entre com seu e-mail e senha corporativos para acessar as organizações às quais você
              está vinculado.
            </p>
          </div>

          <div className="rounded-xl border border-border bg-card p-6 shadow-sm sm:p-7">
            <LoginForm />
          </div>

          <section
            aria-labelledby="acesso-protegido-titulo"
            className="flex gap-3 rounded-xl border border-border bg-muted/50 p-4"
          >
            <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
            <div>
              <h2 id="acesso-protegido-titulo" className="text-sm font-semibold text-foreground">
                Acesso protegido
              </h2>
              <p className="mt-1 text-xs text-muted-foreground">
                Sua sessão respeita as permissões do seu perfil e os vínculos ativos com cada
                organização. Você verá apenas o que está autorizado a acessar.
              </p>
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
