import { useEffect, useRef, useState, type KeyboardEvent } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import {
  AlertCircle,
  Building2,
  Check,
  Loader2,
  LogOut,
  RefreshCw,
  ShieldAlert,
} from "lucide-react";

import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import {
  definirPreferenciaOrganizacao,
  obterPreferenciaOrganizacao,
} from "@/lib/organizacao/preferenciaOrganizacao";

export const MENSAGENS_SYS04 = {
  carregando: "Carregando organizações…",
  vazio: "Não há organização disponível para o seu usuário. Procure o administrador do ContaOS.",
  negado: "Acesso negado. Você não tem permissão para consultar organizações.",
  erro: "Não foi possível carregar as organizações agora. Tente novamente em instantes.",
  indisponivel: "Acesso indisponível",
} as const;

type Organizacao = {
  id: string;
  razao_social: string;
  nome_fantasia: string | null;
  cnpj: string | null;
  situacao: string;
};
type Vinculo = { id: string; perfil: string; organizacao: Organizacao | null };

class ErroConsulta extends Error {
  constructor(public tipo: "negado" | "erro") {
    super(tipo);
  }
}

function classificar(error: { code?: string; status?: number } | null): "negado" | "erro" {
  if (!error) return "erro";
  if (
    error.code === "42501" ||
    error.code === "PGRST301" ||
    error.status === 401 ||
    error.status === 403
  )
    return "negado";
  return "erro";
}

export function formatarCnpj(c: string | null): string {
  const d = (c ?? "").replace(/\D/g, "");
  if (d.length !== 14) return c ?? "—";
  return d.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, "$1.$2.$3/$4-$5");
}

async function buscarVinculos(idUsuario: string): Promise<Vinculo[]> {
  const { data, error } = await supabase
    .from("vinculos_usuarios")
    .select(
      "id, perfil, organizacao:organizacoes!vinculos_usuarios_id_organizacao_fkey(id, razao_social, nome_fantasia, cnpj, situacao)",
    )
    .eq("id_usuario", idUsuario)
    .eq("ativo", true);
  if (error) throw new ErroConsulta(classificar(error as { code?: string; status?: number }));
  return (data ?? []) as unknown as Vinculo[];
}

export function OrganizationCard(props: {
  vinculo: Vinculo;
  selecionado: boolean;
  focavel: boolean;
  onSelecionar: () => void;
  onTecla: (e: KeyboardEvent<HTMLDivElement>) => void;
  refEl?: (el: HTMLDivElement | null) => void;
}) {
  const o = props.vinculo.organizacao;
  if (!o) {
    return (
      <div className="flex items-start gap-3 rounded-lg border border-dashed border-border bg-muted/40 p-4 text-muted-foreground">
        <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0" aria-hidden />
        <div className="min-w-0">
          <p className="text-sm font-medium">{MENSAGENS_SYS04.indisponivel}</p>
          <p className="text-xs">Esta organização não pode ser acessada no momento.</p>
        </div>
      </div>
    );
  }
  const nome = o.nome_fantasia || o.razao_social;
  return (
    <div
      ref={props.refEl}
      role="radio"
      aria-checked={props.selecionado}
      tabIndex={props.focavel ? 0 : -1}
      onClick={props.onSelecionar}
      onKeyDown={props.onTecla}
      className={cn(
        "flex min-h-[44px] cursor-pointer items-start gap-3 rounded-lg border p-4 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        props.selecionado
          ? "border-primary bg-primary/5"
          : "border-border bg-card hover:bg-muted/50",
      )}
    >
      <span
        aria-hidden
        className={cn(
          "mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border",
          props.selecionado
            ? "border-primary bg-primary text-primary-foreground"
            : "border-muted-foreground/40",
        )}
      >
        {props.selecionado && <Check className="h-3 w-3" />}
      </span>
      <div className="min-w-0 flex-1 space-y-1">
        <p className="break-words text-sm font-semibold text-foreground">{nome}</p>
        {o.nome_fantasia && o.razao_social !== o.nome_fantasia && (
          <p className="break-words text-xs text-muted-foreground">{o.razao_social}</p>
        )}
        <dl className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
          <div className="flex gap-1">
            <dt>CNPJ:</dt>
            <dd className="font-mono text-foreground">{formatarCnpj(o.cnpj)}</dd>
          </div>
          <div className="flex items-center gap-1">
            <dt>Perfil:</dt>
            <dd className="text-foreground">{props.vinculo.perfil}</dd>
          </div>
          <div className="flex gap-1">
            <dt>Situação:</dt>
            <dd className="text-foreground">{o.situacao}</dd>
          </div>
        </dl>
      </div>
      {props.selecionado && <span className="sr-only">Selecionada</span>}
    </div>
  );
}

export function OrganizationList(props: {
  vinculos: Vinculo[];
  selecionada: string | null;
  onSelecionar: (id: string) => void;
}) {
  const refs = useRef<Record<string, HTMLDivElement | null>>({});
  const validos = props.vinculos.filter((v) => v.organizacao).map((v) => v.organizacao!.id);
  const focavel =
    props.selecionada && validos.includes(props.selecionada) ? props.selecionada : validos[0];

  function tecla(id: string, e: KeyboardEvent<HTMLDivElement>) {
    if (e.key === " " || e.key === "Enter") {
      e.preventDefault();
      props.onSelecionar(id);
      return;
    }
    const delta =
      e.key === "ArrowDown" || e.key === "ArrowRight"
        ? 1
        : e.key === "ArrowUp" || e.key === "ArrowLeft"
          ? -1
          : 0;
    if (!delta || validos.length === 0) return;
    e.preventDefault();
    const i = (validos.indexOf(id) + delta + validos.length) % validos.length;
    const prox = validos[i];
    if (!prox) return;
    props.onSelecionar(prox);
    refs.current[prox]?.focus();
  }

  return (
    <div className="space-y-3">
      <p id="sys04-titulo-lista" className="text-sm font-medium text-foreground">
        Organizações disponíveis
      </p>
      {validos.length > 0 && (
        <div role="radiogroup" aria-labelledby="sys04-titulo-lista" className="space-y-3">
          {props.vinculos
            .filter((v) => v.organizacao)
            .map((v) => {
              const id = v.organizacao?.id;
              return (
                <OrganizationCard
                  key={v.id}
                  vinculo={v}
                  selecionado={!!id && id === props.selecionada}
                  focavel={!!id && id === focavel}
                  onSelecionar={() => id && props.onSelecionar(id)}
                  onTecla={(e) => id && tecla(id, e)}
                  refEl={(el) => {
                    if (id) refs.current[id] = el;
                  }}
                />
              );
            })}
        </div>
      )}
      {props.vinculos
        .filter((v) => !v.organizacao)
        .map((v) => (
          <OrganizationCard
            key={v.id}
            vinculo={v}
            selecionado={false}
            focavel={false}
            onSelecionar={() => undefined}
            onTecla={() => undefined}
          />
        ))}
    </div>
  );
}

export function ContinueButton(props: {
  desabilitado: boolean;
  processando: boolean;
  onClick: () => void;
}) {
  return (
    <Button
      type="button"
      className="h-11 w-full"
      disabled={props.desabilitado || props.processando}
      aria-disabled={props.desabilitado || props.processando}
      onClick={props.onClick}
    >
      {props.processando ? (
        <>
          <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden /> Continuando…
        </>
      ) : (
        "Continuar"
      )}
    </Button>
  );
}

export function OrganizationSelector() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [idUsuario, setIdUsuario] = useState<string | null>(null);
  const [verificandoSessao, setVerificandoSessao] = useState(true);
  const [erroSessao, setErroSessao] = useState(false);
  const [tentativaSessao, setTentativaSessao] = useState(0);
  const [selecionada, setSelecionada] = useState<string | null>(null);
  const [processando, setProcessando] = useState(false);
  const emAndamento = useRef(false);

  useEffect(() => {
    let ativo = true;
    setVerificandoSessao(true);
    setErroSessao(false);
    supabase.auth
      .getUser()
      .then(({ data, error }) => {
        if (!ativo) return;
        const semSessao =
          !!error &&
          ((error as { name?: string }).name === "AuthSessionMissingError" ||
            (error as { code?: string }).code === "session_not_found");
        if (semSessao || (!error && !data.user)) navigate({ to: "/login", replace: true });
        else if (error) setErroSessao(true);
        else setIdUsuario(data.user.id);
      })
      .catch(() => {
        if (ativo) setErroSessao(true);
      })
      .finally(() => {
        if (ativo) setVerificandoSessao(false);
      });
    return () => {
      ativo = false;
    };
  }, [navigate, tentativaSessao]);

  const consulta = useQuery({
    queryKey: ["sys04", "vinculos", idUsuario],
    queryFn: () => buscarVinculos(idUsuario!),
    enabled: !!idUsuario,
    retry: false,
  });

  const vinculos = consulta.data ?? [];
  const validos = vinculos.filter((v) => v.organizacao);

  useEffect(() => {
    if (!consulta.data || !idUsuario || selecionada) return;
    const ok = consulta.data.filter((v) => v.organizacao).map((v) => v.organizacao!.id);
    const pref = obterPreferenciaOrganizacao(idUsuario);
    if (pref && ok.includes(pref)) setSelecionada(pref);
    else if (ok.length === 1 && ok[0]) setSelecionada(ok[0]);
  }, [consulta.data, idUsuario, selecionada]);

  function continuar() {
    if (emAndamento.current || !idUsuario || !selecionada) return;
    if (!validos.some((v) => v.organizacao!.id === selecionada)) return;
    emAndamento.current = true;
    setProcessando(true);
    const anterior = obterPreferenciaOrganizacao(idUsuario);
    if (anterior !== null && anterior !== selecionada) queryClient.clear();
    definirPreferenciaOrganizacao(idUsuario, selecionada);
    navigate({ to: "/" });
  }

  async function sair() {
    await supabase.auth.signOut().catch(() => undefined);
    navigate({ to: "/login", replace: true });
  }

  const carregando = !erroSessao && (verificandoSessao || !idUsuario || consulta.isPending);
  const erroTipo = erroSessao
    ? "erro"
    : consulta.error instanceof ErroConsulta
      ? consulta.error.tipo
      : consulta.error
        ? "erro"
        : null;
  const tentarNovamente = () =>
    erroSessao ? setTentativaSessao((n) => n + 1) : consulta.refetch();
  const anuncio = carregando
    ? MENSAGENS_SYS04.carregando
    : processando
      ? "Abrindo organização selecionada."
      : "";

  return (
    <div className="space-y-5">
      <div aria-live="polite" className="sr-only">
        {anuncio}
      </div>

      {carregando && (
        <div className="space-y-3" aria-hidden>
          <p className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" /> {MENSAGENS_SYS04.carregando}
          </p>
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      )}

      {!carregando && erroTipo === "negado" && (
        <div
          role="alert"
          className="flex gap-3 rounded-lg border border-destructive/40 bg-destructive/5 p-4"
        >
          <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-destructive" aria-hidden />
          <p className="text-sm text-foreground">{MENSAGENS_SYS04.negado}</p>
        </div>
      )}

      {!carregando && erroTipo === "erro" && (
        <div className="space-y-3">
          <div
            role="alert"
            className="flex gap-3 rounded-lg border border-destructive/40 bg-destructive/5 p-4"
          >
            <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" aria-hidden />
            <p className="text-sm text-foreground">{MENSAGENS_SYS04.erro}</p>
          </div>
          <Button type="button" variant="outline" className="h-11 w-full" onClick={tentarNovamente}>
            <RefreshCw className="mr-2 h-4 w-4" aria-hidden /> Tentar novamente
          </Button>
        </div>
      )}

      {!carregando && !erroTipo && vinculos.length === 0 && (
        <div role="status" className="flex gap-3 rounded-lg border border-border bg-muted/40 p-4">
          <Building2 className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground" aria-hidden />
          <p className="text-sm text-foreground">{MENSAGENS_SYS04.vazio}</p>
        </div>
      )}

      {!carregando && !erroTipo && vinculos.length > 0 && (
        <>
          <OrganizationList
            vinculos={vinculos}
            selecionada={selecionada}
            onSelecionar={setSelecionada}
          />
          {validos.length > 0 && (
            <ContinueButton
              desabilitado={!selecionada}
              processando={processando}
              onClick={continuar}
            />
          )}
        </>
      )}

      {!carregando && (erroTipo === "negado" || vinculos.length === 0 || validos.length === 0) && (
        <Button type="button" variant="outline" className="h-11 w-full" onClick={sair}>
          <LogOut className="mr-2 h-4 w-4" aria-hidden /> Sair
        </Button>
      )}
    </div>
  );
}
