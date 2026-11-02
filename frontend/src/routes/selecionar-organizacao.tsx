import { createFileRoute } from "@tanstack/react-router";
import { Building2, ShieldCheck } from "lucide-react";

import { OrganizationSelector } from "@/components/organizacao/OrganizationSelector";

export const Route = createFileRoute("/selecionar-organizacao")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Selecionar organização — ContaOS" },
      { name: "description", content: "Escolha a organização em que deseja trabalhar no ContaOS." },
      { property: "og:title", content: "Selecionar organização — ContaOS" },
      { property: "og:description", content: "Escolha a organização em que deseja trabalhar no ContaOS." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SelecionarOrganizacaoPage,
});

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

function Badge() {
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-primary-foreground/20 bg-primary-foreground/10 px-3 py-1 text-xs font-medium">
      <span className="h-1.5 w-1.5 rounded-full bg-primary-foreground" aria-hidden />
      Ambiente seguro de homologação
    </span>
  );
}

function Painel() {
  return (
    <aside className="relative isolate overflow-hidden bg-primary text-primary-foreground lg:flex lg:w-[48%] lg:flex-col">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 -z-10 opacity-[0.06]"
        style={{
          backgroundImage:
            "linear-gradient(to right, currentColor 1px, transparent 1px), linear-gradient(to bottom, currentColor 1px, transparent 1px)",
          backgroundSize: "48px 48px",
        }}
      />
      <div aria-hidden className="pointer-events-none absolute -left-24 -top-24 -z-10 h-80 w-80 rounded-full bg-chart-2/25 blur-3xl" />
      <div aria-hidden className="pointer-events-none absolute -bottom-32 right-0 -z-10 h-96 w-96 rounded-full bg-chart-1/20 blur-3xl" />

      <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-4 md:px-10 md:py-5 lg:hidden">
        <Marca />
        <Badge />
      </div>

      <div className="hidden flex-1 flex-col justify-between gap-10 px-12 py-12 xl:px-16 lg:flex">
        <Marca />
        <div className="max-w-xl space-y-6">
          <Badge />
          <p className="text-4xl font-semibold leading-tight tracking-tight xl:text-[2.75rem]">
            Escolha onde você vai trabalhar.
          </p>
          <p className="max-w-lg text-base opacity-80">
            As permissões de cada organização são aplicadas pelo sistema a cada acesso.
          </p>
        </div>
        <div className="flex items-center justify-between gap-4 border-t border-primary-foreground/15 pt-5 text-xs opacity-70">
          <span>ContaOS • Ambiente HML</span>
          <span>Segurança e rastreabilidade por padrão</span>
        </div>
      </div>
    </aside>
  );
}

function SelecionarOrganizacaoPage() {
  return (
    <div lang="pt-BR" className="flex min-h-screen flex-col bg-background lg:flex-row">
      <Painel />
      <main className="flex flex-1 items-start justify-center px-4 py-8 sm:px-6 md:py-12 lg:items-center">
        <div className="w-full max-w-md space-y-5">
          <div className="space-y-2">
            <p className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              <Building2 className="h-3.5 w-3.5" aria-hidden /> Acesso ao ContaOS
            </p>
            <h1 className="text-3xl font-semibold tracking-tight text-foreground">Selecionar organização</h1>
            <p className="text-sm text-muted-foreground">Selecione a organização para continuar.</p>
          </div>
          <div className="rounded-xl border border-border bg-card p-6 shadow-sm sm:p-7">
            <OrganizationSelector />
          </div>
        </div>
      </main>
    </div>
  );
}
