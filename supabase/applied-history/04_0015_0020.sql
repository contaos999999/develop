-- MIGRATION 20261101211500_0015_hardening_seguranca_integridade
begin;

create or replace function privado.bloquear_mutacao_historico()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  raise exception 'Registro histórico é imutável. Crie nova versão ou novo evento.';
end;$$;
revoke all on function privado.bloquear_mutacao_historico() from public,anon,authenticated;

-- Histórico/auditoria e artefatos congelados não podem ser editados ou apagados.
create trigger eventos_auditoria_append_only before update or delete on public.eventos_auditoria for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_contrato_append_only before update or delete on public.versoes_contrato for each row execute function privado.bloquear_mutacao_historico();
create trigger versoes_documento_append_only before update or delete on public.versoes_documento for each row execute function privado.bloquear_mutacao_historico();
create trigger desfechos_historicos_append_only before update or delete on public.desfechos_historicos for each row execute function privado.bloquear_mutacao_historico();
create trigger itens_pacote_competencia_append_only before update or delete on public.itens_pacote_competencia for each row execute function privado.bloquear_mutacao_historico();
create trigger desfechos_apontamentos_append_only before update or delete on public.desfechos_apontamentos for each row execute function privado.bloquear_mutacao_historico();
create trigger tratamentos_alertas_append_only before update or delete on public.tratamentos_alertas for each row execute function privado.bloquear_mutacao_historico();
create trigger retornos_modelo_append_only before update or delete on public.retornos_modelo for each row execute function privado.bloquear_mutacao_historico();
create trigger fontes_resposta_copiloto_append_only before update or delete on public.fontes_resposta_copiloto for each row execute function privado.bloquear_mutacao_historico();
create trigger publicacoes_regras_append_only before update or delete on public.publicacoes_regras for each row execute function privado.bloquear_mutacao_historico();
create trigger exportacoes_evidencias_append_only before update or delete on public.exportacoes_evidencias for each row execute function privado.bloquear_mutacao_historico();

-- Referência de contrato em vínculo ganha FK depois que contratos já existe.
alter table public.vinculos_usuario_contratos
  add constraint vinculos_usuario_contratos_contrato_fk foreign key(id_contrato) references public.contratos(id) on delete cascade;

-- Consistência de tenant: impedir IDs de organização divergentes em entidades filhas.
create or replace function privado.validar_org_contrato()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_org uuid;
begin
  if new.id_contrato is null then return new; end if;
  select id_organizacao into v_org from public.contratos where id=new.id_contrato;
  if v_org is null or v_org<>new.id_organizacao then raise exception 'Organização incompatível com o contrato.'; end if;
  return new;
end;$$;
revoke all on function privado.validar_org_contrato() from public,anon,authenticated;

create trigger competencias_org_ck before insert or update on public.competencias for each row execute function privado.validar_org_contrato();
create trigger requisitos_competencia_org_ck before insert or update on public.requisitos_competencia for each row execute function privado.validar_org_contrato();
create trigger documentos_competencia_org_ck before insert or update on public.documentos_competencia for each row execute function privado.validar_org_contrato();
create trigger execucoes_analise_org_ck before insert or update on public.execucoes_analise for each row execute function privado.validar_org_contrato();
create trigger apontamentos_contratante_org_ck before insert or update on public.apontamentos_contratante for each row execute function privado.validar_org_contrato();
create trigger transacoes_financeiras_org_ck before insert or update on public.transacoes_financeiras for each row execute function privado.validar_org_contrato();
create trigger alertas_preventivos_org_ck before insert or update on public.alertas_preventivos for each row execute function privado.validar_org_contrato();

-- Campos canônicos que fecham lacunas de rastreabilidade da arquitetura 4.1.
alter table public.transacoes_financeiras add column if not exists id_linha_orcamentaria uuid references public.linhas_orcamentarias(id) on delete restrict;
alter table public.transacoes_financeiras add column if not exists conta_bancaria text;
alter table public.transacoes_financeiras add column if not exists status_fluxo text not null default 'registrada' check(status_fluxo in ('prevista','em_aprovacao','registrada','paga','conciliada','cancelada'));
alter table public.transacoes_financeiras add column if not exists pre_validada boolean not null default false;
alter table public.transacoes_financeiras add column if not exists pre_validada_em timestamptz;

alter table public.alertas_preventivos add column if not exists codigo_regra text;
alter table public.alertas_preventivos add column if not exists grupo_chave text;
alter table public.alertas_preventivos add column if not exists impacto_financeiro numeric(18,2);
alter table public.alertas_preventivos add column if not exists responsavel uuid references auth.users(id) on delete set null;
alter table public.alertas_preventivos add column if not exists evidencias_futuras jsonb not null default '[]'::jsonb;

-- Versionamento de arquivo imutável: nunca reaproveitar hash físico em organizações diferentes.
create unique index if not exists arquivos_org_sha_uidx on public.arquivos(id_organizacao,sha256);

-- Segurança de Storage: bucket privado e caminho inicia pelo id_organizacao.
update storage.buckets set public=false where id='contaos-documentos';

create policy contaos_storage_select on storage.objects
for select to authenticated
using (
 bucket_id='contaos-documentos'
 and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
 and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid)
);
create policy contaos_storage_insert on storage.objects
for insert to authenticated
with check (
 bucket_id='contaos-documentos'
 and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$'
 and privado.usuario_tem_acesso_organizacao(((storage.foldername(name))[1])::uuid)
);

-- Grants explícitos: nada no schema privado pela Data API comum.
revoke all on schema privado from public,anon,authenticated;
revoke all on all tables in schema privado from public,anon,authenticated;
revoke all on all sequences in schema privado from public,anon,authenticated;
revoke all on all functions in schema privado from public,anon,authenticated;

-- Data API pública: anon não acessa domínio; authenticated depende de RLS.
do $$ declare r record; begin
 for r in select tablename from pg_tables where schemaname='public' loop
   execute format('revoke all on table public.%I from anon',r.tablename);
   execute format('grant select,insert,update on table public.%I to authenticated',r.tablename);
 end loop;
end $$;

-- Tabelas append-only não aceitam INSERT do cliente; somente RPCs/serviço.
revoke insert,update,delete on public.eventos_auditoria from authenticated;
revoke insert,update,delete on public.versoes_contrato from authenticated;
revoke insert,update,delete on public.versoes_documento from authenticated;
revoke insert,update,delete on public.resultados_requisitos from authenticated;
revoke insert,update,delete on public.evidencias_resultado from authenticated;
revoke insert,update,delete on public.itens_pacote_competencia from authenticated;
revoke insert,update,delete on public.apresentacoes_contratante from authenticated;
revoke insert,update,delete on public.pacotes_competencia from authenticated;
revoke insert,update,delete on public.pacotes_reapresentacao from authenticated;
revoke insert,update,delete on public.retornos_modelo from authenticated;
revoke insert,update,delete on public.fontes_resposta_copiloto from authenticated;
revoke insert,update,delete on public.publicacoes_regras from authenticated;
revoke insert,update,delete on public.eventos_webhook from authenticated;
revoke insert,update,delete on public.exportacoes_evidencias from authenticated;
revoke insert,update,delete on public.acessos_pacote_evidencias from authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211533_0016_rpc_privadas_wrappers
begin;

-- Implementações privilegiadas ficam fora do schema exposto pela API.
alter function public.criar_organizacao(text,text,varchar,text) set schema privado;
alter function public.criar_vinculo_usuario(uuid,uuid,text,boolean,timestamptz,timestamptz) set schema privado;
alter function public.atribuir_contrato_usuario(uuid,uuid) set schema privado;
alter function public.revogar_contrato_usuario(uuid,uuid) set schema privado;
alter function public.criar_versao_contrato(uuid,text) set schema privado;
alter function public.publicar_versao_fonte_normativa(uuid,date,date,uuid,text,jsonb) set schema privado;
alter function public.publicar_versao_lista(uuid,text,date,date) set schema privado;
alter function public.criar_competencia(uuid,date,date,date,date) set schema privado;
alter function public.solicitar_analise_competencia(uuid,text) set schema privado;
alter function public.avaliar_portao_conformidade(uuid) set schema privado;
alter function public.aprovar_apresentacao(uuid,text) set schema privado;
alter function public.registrar_apresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.promover_precedente_para_regra(uuid,text,text,text,text,text) set schema privado;
alter function public.enfileirar_processamento_documento(uuid,text) set schema privado;
alter function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) set schema privado;
alter function public.avaliar_portao_reapresentacao(uuid) set schema privado;
alter function public.aprovar_contestacao(uuid,boolean,text) set schema privado;
alter function public.liberar_reapresentacao(uuid,text) set schema privado;
alter function public.registrar_reapresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.solicitar_importacao_financeira(uuid,uuid,text,text) set schema privado;
alter function public.tratar_alerta_preventivo(uuid,text,text,uuid) set schema privado;
alter function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) set schema privado;
alter function public.publicar_controle(uuid,text,jsonb,date,date) set schema privado;
alter function public.aprovar_excecao_controle(uuid,boolean) set schema privado;
alter function public.encerrar_nao_conformidade(uuid,text) set schema privado;
alter function public.publicar_regra_candidata(uuid,uuid,date,date) set schema privado;
alter function public.criar_cliente_api(uuid,text,text[]) set schema privado;
alter function public.rotacionar_cliente_api(uuid) set schema privado;
alter function public.criar_webhook(uuid,text,text,text[]) set schema privado;
alter function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) set schema privado;
alter function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) set schema privado;
alter function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) set schema privado;

-- Wrappers SECURITY INVOKER no schema public. O privilégio efetivo fica exclusivamente dentro do privado.
create function public.criar_organizacao(p_razao_social text,p_nome_fantasia text default null,p_cnpj varchar default null,p_timezone text default 'America/Bahia') returns uuid language sql security invoker set search_path='' as $$select privado.criar_organizacao($1,$2,$3,$4)$$;
create function public.criar_vinculo_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_inicio_em timestamptz default now(),p_fim_em timestamptz default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_vinculo_usuario($1,$2,$3,$4,$5,$6)$$;
create function public.atribuir_contrato_usuario(p_id_vinculo_usuario uuid,p_id_contrato uuid) returns uuid language sql security invoker set search_path='' as $$select privado.atribuir_contrato_usuario($1,$2)$$;
create function public.revogar_contrato_usuario(p_id_vinculo_usuario uuid,p_id_contrato uuid) returns void language sql security invoker set search_path='' as $$select privado.revogar_contrato_usuario($1,$2)$$;
create function public.criar_versao_contrato(p_id_contrato uuid,p_motivo text default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_versao_contrato($1,$2)$$;
create function public.publicar_versao_fonte_normativa(p_id_fonte uuid,p_inicio_vigencia date,p_fim_vigencia date default null,p_id_arquivo uuid default null,p_conteudo_texto text default null,p_metadados jsonb default '{}'::jsonb) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_versao_fonte_normativa($1,$2,$3,$4,$5,$6)$$;
create function public.publicar_versao_lista(p_id_lista uuid,p_observacao text default null,p_vigencia_inicio date default null,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_versao_lista($1,$2,$3,$4)$$;
create function public.criar_competencia(p_id_contrato uuid,p_competencia_referencia date,p_periodo_inicio date default null,p_periodo_fim date default null,p_data_limite date default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_competencia($1,$2,$3,$4,$5)$$;
create function public.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa') returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_analise_competencia($1,$2)$$;
create function public.avaliar_portao_conformidade(p_id_competencia uuid) returns jsonb language sql security invoker stable set search_path='' as $$select privado.avaliar_portao_conformidade($1)$$;
create function public.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.aprovar_apresentacao($1,$2)$$;
create function public.registrar_apresentacao(p_id_competencia uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_apresentacao($1,$2,$3,$4,$5)$$;
create function public.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato') returns uuid language sql security invoker set search_path='' as $$select privado.promover_precedente_para_regra($1,$2,$3,$4,$5,$6)$$;
create function public.enfileirar_processamento_documento(p_id_versao_documento uuid,p_chave_idempotencia text default null) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_processamento_documento($1,$2)$$;
create function public.registrar_parecer_contratante(p_id_competencia uuid,p_id_apresentacao uuid,p_id_arquivo uuid,p_resultado_geral text,p_parecer_final_favoravel boolean default false,p_numero_documento text default null,p_data_emissao date default null,p_prazo_resposta date default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_parecer_contratante($1,$2,$3,$4,$5,$6,$7,$8)$$;
create function public.avaliar_portao_reapresentacao(p_id_ciclo uuid) returns jsonb language sql security invoker stable set search_path='' as $$select privado.avaliar_portao_reapresentacao($1)$$;
create function public.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null) returns void language sql security invoker set search_path='' as $$select privado.aprovar_contestacao($1,$2,$3)$$;
create function public.liberar_reapresentacao(p_id_ciclo uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.liberar_reapresentacao($1,$2)$$;
create function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_reapresentacao($1,$2,$3,$4,$5)$$;
create function public.solicitar_importacao_financeira(p_id_fonte uuid,p_id_arquivo uuid,p_hash text,p_chave_deduplicacao text) returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_importacao_financeira($1,$2,$3,$4)$$;
create function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.tratar_alerta_preventivo($1,$2,$3,$4)$$;
create function public.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.iniciar_consulta_copiloto($1,$2,$3,$4,$5)$$;
create function public.publicar_controle(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_controle($1,$2,$3,$4,$5)$$;
create function public.aprovar_excecao_controle(p_id_excecao uuid,p_aprovar boolean) returns void language sql security invoker set search_path='' as $$select privado.aprovar_excecao_controle($1,$2)$$;
create function public.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text) returns void language sql security invoker set search_path='' as $$select privado.encerrar_nao_conformidade($1,$2)$$;
create function public.publicar_regra_candidata(p_id_regra_candidata uuid,p_id_avaliacao_impacto uuid,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_regra_candidata($1,$2,$3,$4)$$;
create function public.criar_cliente_api(p_id_organizacao uuid,p_nome text,p_escopos text[] default '{}'::text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_cliente_api($1,$2,$3)$$;
create function public.rotacionar_cliente_api(p_id_cliente uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.rotacionar_cliente_api($1)$$;
create function public.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_webhook($1,$2,$3,$4)$$;
create function public.enfileirar_evento_webhook(p_id_webhook uuid,p_evento text,p_entidade_tipo text,p_entidade_id uuid,p_payload_ref jsonb) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_evento_webhook($1,$2,$3,$4,$5)$$;
create function public.criar_pacote_evidencias(p_id_organizacao uuid,p_id_contrato uuid,p_escopo jsonb,p_expira_em timestamptz default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_pacote_evidencias($1,$2,$3,$4)$$;
create function public.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_acesso_temporario_pacote($1,$2,$3,$4)$$;

-- Apenas authenticated executa wrappers.
do $$ declare r record; begin
 for r in
   select p.oid::regprocedure as sig
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in (
     'criar_organizacao','criar_vinculo_usuario','atribuir_contrato_usuario','revogar_contrato_usuario','criar_versao_contrato','publicar_versao_fonte_normativa','publicar_versao_lista','criar_competencia','solicitar_analise_competencia','avaliar_portao_conformidade','aprovar_apresentacao','registrar_apresentacao','promover_precedente_para_regra','enfileirar_processamento_documento','registrar_parecer_contratante','avaliar_portao_reapresentacao','aprovar_contestacao','liberar_reapresentacao','registrar_reapresentacao','solicitar_importacao_financeira','tratar_alerta_preventivo','iniciar_consulta_copiloto','publicar_controle','aprovar_excecao_controle','encerrar_nao_conformidade','publicar_regra_candidata','criar_cliente_api','rotacionar_cliente_api','criar_webhook','enfileirar_evento_webhook','criar_pacote_evidencias','criar_acesso_temporario_pacote'
   )
 loop
   execute format('revoke all on function %s from public,anon',r.sig);
   execute format('grant execute on function %s to authenticated',r.sig);
 end loop;
end $$;

-- Os wrappers precisam poder executar somente suas implementações homônimas.
do $$ declare r record; begin
 for r in
   select p.oid::regprocedure as sig
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='privado' and p.proname in (
     'criar_organizacao','criar_vinculo_usuario','atribuir_contrato_usuario','revogar_contrato_usuario','criar_versao_contrato','publicar_versao_fonte_normativa','publicar_versao_lista','criar_competencia','solicitar_analise_competencia','avaliar_portao_conformidade','aprovar_apresentacao','registrar_apresentacao','promover_precedente_para_regra','enfileirar_processamento_documento','registrar_parecer_contratante','avaliar_portao_reapresentacao','aprovar_contestacao','liberar_reapresentacao','registrar_reapresentacao','solicitar_importacao_financeira','tratar_alerta_preventivo','iniciar_consulta_copiloto','publicar_controle','aprovar_excecao_controle','encerrar_nao_conformidade','publicar_regra_candidata','criar_cliente_api','rotacionar_cliente_api','criar_webhook','enfileirar_evento_webhook','criar_pacote_evidencias','criar_acesso_temporario_pacote'
   )
 loop execute format('grant execute on function %s to authenticated',r.sig); end loop;
end $$;

-- Helpers usados pelas políticas RLS permanecem executáveis por authenticated, sem acesso de anon.
grant execute on function privado.usuario_tem_acesso_organizacao(uuid) to authenticated;
grant execute on function privado.usuario_tem_acesso_contrato(uuid) to authenticated;
grant execute on function privado.usuario_possui_perfil(uuid,text[]) to authenticated;

commit;

-- ============================================================

-- MIGRATION 20261101211541_0017_hardening_final
begin;

-- Nenhuma função public deve manter privilégio de execução anônima.
do $$ declare r record; begin
 for r in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
 loop execute format('revoke execute on function %s from public,anon',r.sig); end loop;
end $$;

-- O cliente autenticado só recebe EXECUTE onde já foi explicitamente concedido.
-- Revoga helpers técnicos acidentalmente concedidos por comandos globais anteriores.
revoke execute on function public.caminho_storage_organizacao(uuid,uuid,uuid,text) from authenticated;
revoke execute on function public.caminho_storage_contrato(uuid,uuid,uuid,text) from authenticated;
revoke execute on function public.caminho_storage_competencia(uuid,uuid,uuid,text) from authenticated;

-- Perfis são somente leitura. Comandos idempotentes e logs são escritos apenas pelo backend.
revoke insert,update,delete on public.perfis_usuarios from authenticated;
revoke insert,update,delete on public.comandos_idempotentes from authenticated;
revoke insert,update,delete on public.execucoes_assincronas from authenticated;

-- Registros técnicos de IA, integrações e evidências não podem ser escritos diretamente pelo navegador.
revoke insert,update,delete on public.similaridades_precedentes from authenticated;
revoke insert,update,delete on public.alertas_historicos_transversais from authenticated;
revoke insert,update,delete on public.pontuacoes_risco from authenticated;
revoke insert,update,delete on public.metricas_historicas from authenticated;
revoke insert,update,delete on public.assinaturas_eventos_integracao from authenticated;
revoke insert,update,delete on public.itens_pacote_evidencias from authenticated;

-- Histórico importado: apenas leitura pelo cliente e ingestão via backend/Edge Functions.
revoke insert,update,delete on public.apontamentos_historicos from authenticated;
revoke insert,update,delete on public.respostas_historicas from authenticated;
revoke insert,update,delete on public.desfechos_historicos from authenticated;
revoke insert,update,delete on public.precedentes from authenticated;

-- Eventos/auditoria não são mutáveis por acesso direto, mesmo usando service APIs comuns.
revoke all on public.eventos_auditoria from anon;
revoke insert,update,delete on public.eventos_auditoria from authenticated;

-- Mantém as implementações privilegiadas fora do schema público.
revoke all on schema privado from public,anon,authenticated;
-- Apenas EXECUTE explícito nas funções privadas selecionadas continua válido; USAGE em schema não é concedido,
-- porque os wrappers SQL SECURITY INVOKER são resolvidos no catálogo no momento da criação.

commit;

-- ============================================================

-- MIGRATION 20261101211716_0018_otimizacao_rls
begin;

-- RLS: auth.uid() vira init-plan e as operações ficam separadas para não criar políticas permissivas concorrentes.
drop policy if exists usuarios_select_self on public.usuarios;
drop policy if exists usuarios_update_self on public.usuarios;
create policy usuarios_select_self on public.usuarios for select to authenticated using(id_usuario=(select auth.uid()));
create policy usuarios_update_self on public.usuarios for update to authenticated using(id_usuario=(select auth.uid())) with check(id_usuario=(select auth.uid()));

drop policy if exists vinculos_select on public.vinculos_usuarios;
create policy vinculos_select on public.vinculos_usuarios for select to authenticated using(id_usuario=(select auth.uid()) or privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

drop policy if exists consultas_semanticas_select on public.consultas_semanticas;
create policy consultas_semanticas_select on public.consultas_semanticas for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists sessoes_copiloto_select on public.sessoes_copiloto;
create policy sessoes_copiloto_select on public.sessoes_copiloto for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists mensagens_copiloto_select on public.mensagens_copiloto;
create policy mensagens_copiloto_select on public.mensagens_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.sessoes_copiloto s where s.id=id_sessao and s.criado_por=(select auth.uid())));

drop policy if exists fontes_resposta_copiloto_select on public.fontes_resposta_copiloto;
create policy fontes_resposta_copiloto_select on public.fontes_resposta_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.mensagens_copiloto m join public.sessoes_copiloto s on s.id=m.id_sessao where m.id=id_mensagem and s.criado_por=(select auth.uid())));

-- Converte FOR ALL em políticas de escrita específicas. O projeto não concede DELETE físico do domínio.
drop policy if exists recursos_admin_write on public.recursos_organizacao;
create policy recursos_admin_insert on public.recursos_organizacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy recursos_admin_update on public.recursos_organizacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));

drop policy if exists contratantes_write on public.contratantes;
create policy contratantes_insert on public.contratantes for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy contratantes_update on public.contratantes for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));

drop policy if exists contratos_write on public.contratos;
create policy contratos_insert on public.contratos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratos_update on public.contratos for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));

drop policy if exists propostas_write on public.propostas_orcamentarias;
create policy propostas_insert on public.propostas_orcamentarias for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy propostas_update on public.propostas_orcamentarias for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

drop policy if exists fontes_normativas_write on public.fontes_normativas;
create policy fontes_normativas_insert on public.fontes_normativas for insert to authenticated with check(privado.usuario_tem_acesso_organizacao(id_organizacao) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy fontes_normativas_update on public.fontes_normativas for update to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_organizacao(id_organizacao) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));

drop policy if exists listas_write on public.listas_verificacao;
create policy listas_insert on public.listas_verificacao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy listas_update on public.listas_verificacao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

drop policy if exists itens_lista_write on public.itens_lista;
create policy itens_lista_insert on public.itens_lista for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy itens_lista_update on public.itens_lista for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

drop policy if exists regras_conformidade_write on public.regras_conformidade;
create policy regras_conformidade_insert on public.regras_conformidade for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy regras_conformidade_update on public.regras_conformidade for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists planos_acao_write on public.planos_acao;
create policy planos_acao_insert on public.planos_acao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy planos_acao_update on public.planos_acao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists tarefas_diligencia_write on public.tarefas_diligencia;
create policy tarefas_diligencia_insert on public.tarefas_diligencia for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy tarefas_diligencia_update on public.tarefas_diligencia for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists fornecedores_write on public.fornecedores;
create policy fornecedores_insert on public.fornecedores for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy fornecedores_update on public.fornecedores for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

drop policy if exists fontes_financeiras_write on public.fontes_financeiras;
create policy fontes_financeiras_insert on public.fontes_financeiras for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[]));
create policy fontes_financeiras_update on public.fontes_financeiras for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists contratos_fornecedores_write on public.contratos_fornecedores;
create policy contratos_fornecedores_insert on public.contratos_fornecedores for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[]));
create policy contratos_fornecedores_update on public.contratos_fornecedores for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists tarefas_alerta_write on public.tarefas_alerta;
create policy tarefas_alerta_insert on public.tarefas_alerta for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy tarefas_alerta_update on public.tarefas_alerta for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato)) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists entidades_org_write on public.entidades_organizacionais;
create policy entidades_org_insert on public.entidades_organizacionais for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy entidades_org_update on public.entidades_organizacionais for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists controles_write on public.controles_conformidade;
create policy controles_insert on public.controles_conformidade for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy controles_update on public.controles_conformidade for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists nao_conformidades_write on public.nao_conformidades;
create policy nao_conformidades_insert on public.nao_conformidades for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy nao_conformidades_update on public.nao_conformidades for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists planos_remediacao_write on public.planos_remediacao;
create policy planos_remediacao_insert on public.planos_remediacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy planos_remediacao_update on public.planos_remediacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists riscos_corporativos_write on public.riscos_corporativos;
create policy riscos_corporativos_insert on public.riscos_corporativos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));
create policy riscos_corporativos_update on public.riscos_corporativos for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));

commit;

-- ============================================================

-- MIGRATION 20261101212010_0019_worker_runtime_vault_vector_notifications
begin;

alter table public.fragmentos_documento alter column embedding type extensions.vector(384) using null;
alter table public.precedentes alter column embedding type extensions.vector(384) using null;
alter table public.consultas_semanticas add column if not exists embedding extensions.vector(384);

create index if not exists fragmentos_documento_embedding_hnsw_idx
on public.fragmentos_documento using hnsw (embedding extensions.vector_cosine_ops) where embedding is not null;
create index if not exists precedentes_embedding_hnsw_idx
on public.precedentes using hnsw (embedding extensions.vector_cosine_ops) where embedding is not null;

alter table public.execucoes_assincronas
 add column if not exists ultima_falha_em timestamptz,
 add column if not exists proxima_tentativa_em timestamptz,
 add column if not exists movido_dlq_em timestamptz;

create table public.jobs_dlq (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid references public.organizacoes(id) on delete restrict,
  id_contrato uuid references public.contratos(id) on delete restrict,
  fila text not null,
  entidade_tipo text,
  entidade_id uuid,
  execucao_id uuid references public.execucoes_assincronas(id) on delete restrict,
  message_id bigint,
  payload jsonb not null default '{}'::jsonb,
  tentativas integer not null,
  erro_codigo text,
  erro_detalhe text,
  correlation_id uuid,
  resolvido_em timestamptz,
  resolvido_por uuid references auth.users(id) on delete set null,
  criado_em timestamptz not null default now()
);
create index jobs_dlq_org_idx on public.jobs_dlq(id_organizacao,fila,criado_em desc);
alter table public.jobs_dlq enable row level security;
create policy jobs_dlq_select on public.jobs_dlq for select to authenticated using(id_organizacao is not null and privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
revoke insert,update,delete on public.jobs_dlq from authenticated;

create table public.notificacoes (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_usuario uuid not null references auth.users(id) on delete cascade,
  evento text not null,
  titulo text not null,
  mensagem text not null,
  canal text not null default 'in_app' check(canal in ('in_app','email')),
  status text not null default 'pendente' check(status in ('pendente','enviada','falhou','lida','cancelada')),
  entidade_tipo text,
  entidade_id uuid,
  enviada_em timestamptz,
  lida_em timestamptz,
  erro text,
  criado_em timestamptz not null default now()
);
create index notificacoes_usuario_idx on public.notificacoes(id_usuario,status,criado_em desc);
alter table public.notificacoes enable row level security;
create policy notificacoes_select on public.notificacoes for select to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy notificacoes_update on public.notificacoes for update to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao)) with check(id_usuario=(select auth.uid()));
revoke insert,delete on public.notificacoes from authenticated;

create table public.preferencias_notificacao (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  id_usuario uuid not null references auth.users(id) on delete cascade,
  evento text not null,
  in_app boolean not null default true,
  email boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint preferencias_notificacao_uk unique(id_organizacao,id_usuario,evento)
);
alter table public.preferencias_notificacao enable row level security;
create policy preferencias_notificacao_select on public.preferencias_notificacao for select to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy preferencias_notificacao_insert on public.preferencias_notificacao for insert to authenticated with check(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy preferencias_notificacao_update on public.preferencias_notificacao for update to authenticated using(id_usuario=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao)) with check(id_usuario=(select auth.uid()));
create trigger preferencias_notificacao_touch before update on public.preferencias_notificacao for each row execute function privado.tocar_atualizado_em();

alter table public.alertas_preventivos add column if not exists origem_tipo text not null default 'transacao_financeira';
alter table public.alertas_preventivos add column if not exists origem_id uuid;
alter table public.alertas_preventivos add column if not exists idempotency_key text;
alter table public.alertas_preventivos add column if not exists limiar_agrupamento integer;
alter table public.alertas_preventivos add column if not exists quantidade_agrupada integer not null default 1;
create unique index if not exists alertas_preventivos_idem_uidx on public.alertas_preventivos(id_organizacao,idempotency_key) where idempotency_key is not null;

alter table public.webhooks add column if not exists secret_ciphertext text;
alter table public.webhooks add column if not exists segredo_versao integer not null default 1;
alter table public.assinaturas_eventos_integracao add column if not exists secret_ciphertext text;

create table public.acessos_pacote_evidencias_log (
 id uuid primary key default gen_random_uuid(),
 id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
 id_acesso uuid not null references public.acessos_pacote_evidencias(id) on delete restrict,
 id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict,
 resultado text not null,
 ip_hash text,
 user_agent_hash text,
 criado_em timestamptz not null default now()
);
alter table public.acessos_pacote_evidencias_log enable row level security;
create policy acessos_pacote_log_select on public.acessos_pacote_evidencias_log for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]));
revoke insert,update,delete on public.acessos_pacote_evidencias_log from authenticated;
create trigger acessos_pacote_log_append_only before update or delete on public.acessos_pacote_evidencias_log for each row execute function privado.bloquear_mutacao_historico();

create or replace function privado.segundos_backoff(p_tentativa integer)
returns integer language sql immutable set search_path='' as $$ select least(3600, greatest(5, 5 * (2 ^ greatest(p_tentativa-1,0))::integer)) $$;
revoke all on function privado.segundos_backoff(integer) from public,anon,authenticated;

create or replace function public.worker_pull_job(p_fila text,p_visibility_seconds integer default 180)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v record;
begin
  if auth.role()<>'service_role' then raise exception 'Acesso restrito ao worker.'; end if;
  select * into v from pgmq.read(p_fila,greatest(p_visibility_seconds,30),1) limit 1;
  if v.msg_id is null then return null; end if;
  update public.execucoes_assincronas set status='processando',tentativas=tentativas+1,iniciado_em=coalesce(iniciado_em,now()),ultima_falha_em=null,proxima_tentativa_em=null where fila=p_fila and message_id=v.msg_id;
  return jsonb_build_object('msg_id',v.msg_id,'read_ct',v.read_ct,'enqueued_at',v.enqueued_at,'vt',v.vt,'payload',v.message);
end;$$;
revoke all on function public.worker_pull_job(text,integer) from public,anon,authenticated;
grant execute on function public.worker_pull_job(text,integer) to service_role;

create or replace function public.worker_finalizar_job(p_fila text,p_msg_id bigint,p_sucesso boolean,p_erro_codigo text default null,p_erro_detalhe text default null,p_max_tentativas integer default 5)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.execucoes_assincronas%rowtype; v_payload jsonb:='{}'::jsonb; v_delay int; v_novo bigint;
begin
  if auth.role()<>'service_role' then raise exception 'Acesso restrito ao worker.'; end if;
  select * into v from public.execucoes_assincronas where fila=p_fila and message_id=p_msg_id for update;
  if v.id is null then raise exception 'Execução assíncrona não encontrada.'; end if;
  if p_sucesso then
    perform pgmq.delete(p_fila,p_msg_id);
    update public.execucoes_assincronas set status='concluido',concluido_em=now(),erro_codigo=null,erro_detalhe=null where id=v.id;
    return jsonb_build_object('status','concluido');
  end if;
  select coalesce(message,'{}'::jsonb) into v_payload from pgmq.q_messages(p_fila) where msg_id=p_msg_id;
  perform pgmq.delete(p_fila,p_msg_id);
  if v.tentativas>=p_max_tentativas then
    insert into public.jobs_dlq(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,execucao_id,message_id,payload,tentativas,erro_codigo,erro_detalhe,correlation_id)
    values(v.id_organizacao,v.id_contrato,p_fila,v.entidade_tipo,v.entidade_id,v.id,p_msg_id,coalesce(v_payload,'{}'::jsonb),v.tentativas,p_erro_codigo,p_erro_detalhe,v.correlation_id);
    update public.execucoes_assincronas set status='falhou',erro_codigo=p_erro_codigo,erro_detalhe=p_erro_detalhe,ultima_falha_em=now(),movido_dlq_em=now(),concluido_em=now() where id=v.id;
    return jsonb_build_object('status','dlq','tentativas',v.tentativas);
  end if;
  v_delay:=privado.segundos_backoff(v.tentativas);
  select pgmq.send(p_fila,coalesce(v_payload,'{}'::jsonb),v_delay) into v_novo;
  update public.execucoes_assincronas set message_id=v_novo,status='enfileirado',erro_codigo=p_erro_codigo,erro_detalhe=p_erro_detalhe,ultima_falha_em=now(),proxima_tentativa_em=now()+make_interval(secs=>v_delay) where id=v.id;
  return jsonb_build_object('status','retry','delay_seconds',v_delay,'novo_msg_id',v_novo);
end;$$;
revoke all on function public.worker_finalizar_job(text,bigint,boolean,text,text,integer) from public,anon,authenticated;
grant execute on function public.worker_finalizar_job(text,bigint,boolean,text,text,integer) to service_role;

create or replace function public.worker_enfileirar_job(p_fila text,p_id_organizacao uuid,p_id_contrato uuid,p_entidade_tipo text,p_entidade_id uuid,p_payload jsonb,p_chave_idempotencia text default null)
returns uuid language plpgsql security definer set search_path='' as $$
begin
 if auth.role()<>'service_role' then raise exception 'Acesso restrito ao worker.'; end if;
 return privado.enfileirar_job(p_fila,p_id_organizacao,p_id_contrato,p_entidade_tipo,p_entidade_id,p_payload,p_chave_idempotencia);
end;$$;
revoke all on function public.worker_enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.worker_enfileirar_job(text,uuid,uuid,text,uuid,jsonb,text) to service_role;

create or replace function public.worker_buscar_fragmentos(p_id_organizacao uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 8)
returns table(id uuid,id_versao_documento uuid,pagina_inicio integer,pagina_fim integer,texto text,similaridade float8)
language sql stable security definer set search_path='' as $$
  select f.id,f.id_versao_documento,f.pagina_inicio,f.pagina_fim,f.texto,(1-(f.embedding OPERATOR(extensions.<=>) p_embedding))::float8
  from public.fragmentos_documento f
  where f.id_organizacao=p_id_organizacao and f.id_contrato=p_id_contrato and f.embedding is not null
  order by f.embedding OPERATOR(extensions.<=>) p_embedding
  limit least(greatest(p_limite,1),20)
$$;
revoke all on function public.worker_buscar_fragmentos(uuid,uuid,extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_fragmentos(uuid,uuid,extensions.vector,integer) to service_role;

create or replace function public.worker_buscar_precedentes(p_id_organizacao uuid,p_id_contratante uuid,p_id_contrato uuid,p_embedding extensions.vector(384),p_limite integer default 8)
returns table(id uuid,id_contrato_origem uuid,competencia_origem date,problema text,solucao text,desfecho text,similaridade float8,mesmo_contrato boolean)
language sql stable security definer set search_path='' as $$
 select p.id,p.id_contrato_origem,p.competencia_origem,p.problema,p.solucao,p.desfecho,(1-(p.embedding OPERATOR(extensions.<=>) p_embedding))::float8,(p.id_contrato_origem=p_id_contrato)
 from public.precedentes p where p.id_organizacao=p_id_organizacao and p.id_contratante=p_id_contratante and p.status='ativo' and p.embedding is not null
 order by p.embedding OPERATOR(extensions.<=>) p_embedding limit least(greatest(p_limite,1),20)
$$;
revoke all on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) from public,anon,authenticated;
grant execute on function public.worker_buscar_precedentes(uuid,uuid,uuid,extensions.vector,integer) to service_role;

create or replace function public.worker_obter_webhook(p_id_evento uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.eventos_webhook%rowtype; w public.webhooks%rowtype; s text;
begin
 if auth.role()<>'service_role' then raise exception 'Acesso restrito ao worker.'; end if;
 select * into e from public.eventos_webhook where id=p_id_evento for update;
 if e.id is null then raise exception 'Evento não encontrado.'; end if;
 select * into w from public.webhooks where id=e.id_webhook and ativo=true;
 if w.id is null then raise exception 'Webhook inativo ou inexistente.'; end if;
 s:=coalesce(w.secret_ciphertext,null);
 if s is null then raise exception 'Segredo do webhook não foi armazenado para entrega.'; end if;
 return jsonb_build_object('id_evento',e.id,'id_webhook',w.id,'url',w.url,'headers',w.headers_publicos,'evento',e.evento,'payload',e.payload_ref,'secret',s,'correlation_id',e.correlation_id);
end;$$;
revoke all on function public.worker_obter_webhook(uuid) from public,anon,authenticated;
grant execute on function public.worker_obter_webhook(uuid) to service_role;

create or replace function public.worker_registrar_entrega_webhook(p_id_evento uuid,p_sucesso boolean,p_status_http integer,p_resposta_hash text,p_erro text default null)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eventos_webhook%rowtype; v_delay int;
begin
 if auth.role()<>'service_role' then raise exception 'Acesso restrito ao worker.'; end if;
 select * into e from public.eventos_webhook where id=p_id_evento for update;
 if e.id is null then raise exception 'Evento não encontrado.'; end if;
 if p_sucesso then
   update public.eventos_webhook set status='entregue',status_http=p_status_http,resposta_hash=p_resposta_hash,entregue_em=now(),tentativa=tentativa+1,proxima_tentativa=null where id=e.id;
 else
   v_delay:=privado.segundos_backoff(e.tentativa+1);
   update public.eventos_webhook set status=case when tentativa+1>=5 then 'falhou' else 'enfileirado' end,status_http=p_status_http,resposta_hash=p_resposta_hash,tentativa=tentativa+1,proxima_tentativa=case when tentativa+1>=5 then null else now()+make_interval(secs=>v_delay) end where id=e.id;
 end if;
end;$$;
revoke all on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) from public,anon,authenticated;
grant execute on function public.worker_registrar_entrega_webhook(uuid,boolean,integer,text,text) to service_role;

create or replace function privado.notificar(p_id_organizacao uuid,p_id_usuario uuid,p_evento text,p_titulo text,p_mensagem text,p_entidade_tipo text default null,p_entidade_id uuid default null)
returns integer language plpgsql security definer set search_path='' as $$
declare v_in_app boolean:=true; v_email boolean:=false; v_count integer:=0;
begin
 select coalesce(p.in_app,true),coalesce(p.email,false) into v_in_app,v_email from public.preferencias_notificacao p where p.id_organizacao=p_id_organizacao and p.id_usuario=p_id_usuario and p.evento=p_evento;
 if v_in_app then insert into public.notificacoes(id_organizacao,id_usuario,evento,titulo,mensagem,canal,entidade_tipo,entidade_id) values(p_id_organizacao,p_id_usuario,p_evento,p_titulo,p_mensagem,'in_app',p_entidade_tipo,p_entidade_id); v_count:=v_count+1; end if;
 if v_email then insert into public.notificacoes(id_organizacao,id_usuario,evento,titulo,mensagem,canal,entidade_tipo,entidade_id) values(p_id_organizacao,p_id_usuario,p_evento,p_titulo,p_mensagem,'email',p_entidade_tipo,p_entidade_id); v_count:=v_count+1; perform privado.enfileirar_job('integrations',p_id_organizacao,null,'notificacao',p_id_usuario,jsonb_build_object('id_usuario',p_id_usuario,'evento',p_evento),'notify:'||p_evento||':'||p_id_usuario::text||':'||coalesce(p_entidade_id::text,'')); end if;
 return v_count;
end;$$;
revoke all on function privado.notificar(uuid,uuid,text,text,text,text,uuid) from public,anon,authenticated;

-- Vault: worker token nunca é versionado nem devolvido ao cliente.
insert into vault.secrets(secret,name,description)
values(encode(extensions.gen_random_bytes(48),'hex'),'contaos_internal_worker_token','Token interno para Cron -> Edge Functions do ContaOS')
on conflict (name) do nothing;

create or replace function public.validar_token_interno(p_token text)
returns boolean language sql stable security definer set search_path='' as $$
 select case when auth.role()='service_role' then coalesce(extensions.digest(p_token,'sha256')=extensions.digest((select decrypted_secret from vault.decrypted_secrets where name='contaos_internal_worker_token'),'sha256'),false) else false end
$$;
revoke all on function public.validar_token_interno(text) from public,anon,authenticated;
grant execute on function public.validar_token_interno(text) to service_role;

-- Corrige criação/rotação de webhook para que o backend consiga entregar, sem expor o segredo via RLS/API.
create or replace function privado.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_secret text; v_hash text; v_id uuid;
begin
 if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_url !~ '^https://' then raise exception 'Webhook exige HTTPS.'; end if;
 v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 insert into public.webhooks(id_organizacao,nome,url,eventos,secret_hash,secret_ciphertext,segredo_versao,criado_por) values(p_id_organizacao,p_nome,p_url,coalesce(p_eventos,'{}'::text[]),v_hash,v_secret,1,auth.uid()) returning id into v_id;
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,secret_ciphertext,criado_por) values(p_id_organizacao,v_id,1,v_hash,v_secret,auth.uid());
 perform privado.registrar_evento_auditoria(p_id_organizacao,'WebhookCriado','webhooks',v_id,null,jsonb_build_object('url',p_url,'eventos',p_eventos));
 return jsonb_build_object('id',v_id,'secret_uma_vez',v_secret);
end;$$;

create or replace function privado.rotacionar_webhook(p_id_webhook uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.webhooks%rowtype; v_secret text; v_hash text; v_ver int;
begin
 select * into w from public.webhooks where id=p_id_webhook for update;
 if w.id is null then raise exception 'Webhook não encontrado.'; end if;
 if not privado.usuario_possui_perfil(w.id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 v_ver:=w.segredo_versao+1; v_secret:='whs_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_secret,'sha256'),'hex');
 update public.assinaturas_eventos_integracao set ativo=false,valido_ate=now() where id_webhook=w.id and ativo=true;
 insert into public.assinaturas_eventos_integracao(id_organizacao,id_webhook,versao,secret_hash,secret_ciphertext,criado_por) values(w.id_organizacao,w.id,v_ver,v_hash,v_secret,auth.uid());
 update public.webhooks set secret_hash=v_hash,secret_ciphertext=v_secret,segredo_versao=v_ver where id=w.id;
 perform privado.registrar_evento_auditoria(w.id_organizacao,'WebhookRotacionado','webhooks',w.id,null,jsonb_build_object('versao',v_ver));
 return jsonb_build_object('id',w.id,'secret_uma_vez',v_secret,'versao',v_ver);
end;$$;
revoke all on function privado.rotacionar_webhook(uuid) from public,anon,authenticated;
grant execute on function privado.rotacionar_webhook(uuid) to authenticated;
create function public.rotacionar_webhook(p_id_webhook uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.rotacionar_webhook($1)$$;
revoke all on function public.rotacionar_webhook(uuid) from public,anon; grant execute on function public.rotacionar_webhook(uuid) to authenticated;

-- Token externo: validação server-side; token puro nunca é armazenado.
create or replace function public.validar_acesso_pacote_evidencias(p_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_hash text; a public.acessos_pacote_evidencias%rowtype; p public.pacotes_evidencias%rowtype;
begin
 v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 select * into a from public.acessos_pacote_evidencias where token_hash=v_hash for update;
 if a.id is null then return jsonb_build_object('permitido',false,'codigo','TOKEN_INVALIDO','mensagem','Acesso temporário não encontrado.'); end if;
 if a.revogado_em is not null or a.expira_em<=now() or (a.max_acessos is not null and a.quantidade_acessos>=a.max_acessos) then return jsonb_build_object('permitido',false,'codigo','TOKEN_EXPIRADO','mensagem','Este acesso temporário expirou, foi revogado ou atingiu o limite de uso.'); end if;
 select * into p from public.pacotes_evidencias where id=a.id_pacote;
 if p.id is null or p.status not in ('congelado','disponivel') or (p.expira_em is not null and p.expira_em<=now()) then return jsonb_build_object('permitido',false,'codigo','PACOTE_INDISPONIVEL','mensagem','O pacote de evidências não está mais disponível.'); end if;
 update public.acessos_pacote_evidencias set quantidade_acessos=quantidade_acessos+1 where id=a.id;
 insert into public.acessos_pacote_evidencias_log(id_organizacao,id_acesso,id_pacote,resultado) values(a.id_organizacao,a.id,a.id_pacote,'permitido');
 return jsonb_build_object('permitido',true,'id_pacote',a.id_pacote,'expira_em',a.expira_em,'acessos_restantes',case when a.max_acessos is null then null else greatest(a.max_acessos-a.quantidade_acessos-1,0) end);
end;$$;
revoke all on function public.validar_acesso_pacote_evidencias(text) from public,anon,authenticated;
grant execute on function public.validar_acesso_pacote_evidencias(text) to service_role;

-- Regras explícitas de senha/secret de API: apenas hash é persistido.
-- Clientes API permanecem sem leitura de secret_hash pelo frontend: policy existente é removida e RPC administrativa substitui a leitura sensível.
drop policy if exists clientes_api_select on public.clientes_api;
create policy clientes_api_select on public.clientes_api for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));
-- proteção em coluna ocorre via view de administração no frontend; SELECT direto será evitado pelo cliente.

commit;

-- ============================================================

-- MIGRATION 20261101212154_0020_rpc_analise_diligencia_rag
begin;

create or replace function privado.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa')
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.competencias%rowtype; v_exec uuid; v_snapshot jsonb; v_hash text;
begin
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if p_tipo not in ('completa','reanálise','parcial') then raise exception 'Tipo de análise inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then raise exception 'Situação não permite análise.'; end if;
  select jsonb_build_object(
    'competencia',jsonb_build_object('id',v.id,'referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim),
    'requisitos',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'origem_tipo',r.origem_tipo,'origem_id',r.origem_id,'origem_versao',r.origem_versao,'hash',r.hash_snapshot) order by r.ordem,r.id) from public.requisitos_competencia r where r.id_competencia=v.id),'[]'::jsonb),
    'documentos',coalesce((select jsonb_agg(jsonb_build_object('id_documento',d.id,'id_versao',vd.id,'numero_versao',vd.numero_versao,'hash',vd.hash) order by d.id) from public.documentos_competencia d join lateral (select x.* from public.versoes_documento x where x.id_documento_competencia=d.id order by x.numero_versao desc limit 1) vd on true where d.id_competencia=v.id and d.situacao='ativo'),'[]'::jsonb),
    'motor','contaos','versao_motor','1.0','idioma','pt-BR'
  ) into v_snapshot;
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');
  insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,prompt_versao,iniciada_por,iniciada_em,metadados)
  values(v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos','1.0','analise-pt-BR-v1',auth.uid(),now(),jsonb_build_object('snapshot_entrada',v_snapshot)) returning id into v_exec;
  update public.competencias set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end where id=v.id;
  perform privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),'analysis:'||v_exec::text);
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash));
  return v_exec;
end;$$;

-- Resultados e evidências de uma execução concluída são append-only e só backend/service role grava diretamente.
create trigger resultados_requisitos_append_only before update or delete on public.resultados_requisitos for each row execute function privado.bloquear_mutacao_historico();
create trigger evidencias_resultado_append_only before update or delete on public.evidencias_resultado for each row execute function privado.bloquear_mutacao_historico();

create or replace function privado.revisar_resultado_requisito(p_id_resultado uuid,p_resultado text,p_justificativa text,p_fundamento text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.resultados_requisitos%rowtype; v_novo uuid;
begin
 select * into r from public.resultados_requisitos where id=p_id_resultado;
 if r.id is null then raise exception 'Resultado não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(r.id_contrato) or not privado.usuario_possui_perfil(r.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']::text[]) then raise exception 'Acesso negado.'; end if;
 if p_resultado not in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel') then raise exception 'Resultado inválido.'; end if;
 if p_resultado='nao_aplicavel' and nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Não aplicável exige fundamento.'; end if;
 insert into public.execucoes_analise(id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,versao_motor,prompt_versao,iniciada_por,iniciada_em,concluida_em,metadados)
 values(r.id_organizacao,r.id_contrato,r.id_competencia,'parcial','concluida',encode(extensions.digest(concat_ws('|',r.id::text,p_resultado,p_justificativa,p_fundamento),'sha256'),'hex'),'revisao_humana','1.0','human-review',auth.uid(),now(),now(),jsonb_build_object('resultado_origem',r.id)) returning id into v_novo;
 insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,confianca,justificativa,fundamento,metadados)
 values(r.id_organizacao,r.id_contrato,r.id_competencia,v_novo,r.id_requisito,p_resultado,1,p_justificativa,p_fundamento,jsonb_build_object('revisao_humana',true,'resultado_anterior',r.id));
 perform privado.registrar_evento_auditoria(r.id_organizacao,'ResultadoRequisitoRevisado','resultados_requisitos',r.id,null,jsonb_build_object('novo_resultado',p_resultado,'id_execucao_revisao',v_novo));
 return v_novo;
end;$$;
revoke all on function privado.revisar_resultado_requisito(uuid,text,text,text) from public,anon,authenticated;
grant execute on function privado.revisar_resultado_requisito(uuid,text,text,text) to authenticated;
create function public.revisar_resultado_requisito(p_id_resultado uuid,p_resultado text,p_justificativa text,p_fundamento text) returns uuid language sql security invoker set search_path='' as $$select privado.revisar_resultado_requisito($1,$2,$3,$4)$$;
revoke all on function public.revisar_resultado_requisito(uuid,text,text,text) from public,anon; grant execute on function public.revisar_resultado_requisito(uuid,text,text,text) to authenticated;

create or replace function privado.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v public.tarefas_diligencia%rowtype;
begin
 select * into v from public.tarefas_diligencia where id=p_id_tarefa for update;
 if v.id is null then raise exception 'Tarefa não encontrada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
 if v.responsavel is not null and v.responsavel<>auth.uid() and not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception 'Somente responsável ou gestor pode concluir a tarefa.'; end if;
 if p_id_evidencia_versao_documento is null or not exists(select 1 from public.versoes_documento vd where vd.id=p_id_evidencia_versao_documento and vd.id_contrato=v.id_contrato) then raise exception 'Evidência documental válida é obrigatória.'; end if;
 update public.tarefas_diligencia set status='concluida',id_evidencia_versao_documento=p_id_evidencia_versao_documento where id=v.id;
 if v.id_apontamento is not null then update public.apontamentos_contratante set status='resolvido' where id=v.id_apontamento and status not in ('encerrado','nao_procedente','contestado_aprovado'); end if;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'TarefaDiligenciaConcluida','tarefas_diligencia',v.id,null,jsonb_build_object('id_evidencia',p_id_evidencia_versao_documento));
end;$$;
revoke all on function privado.concluir_tarefa_diligencia(uuid,uuid) from public,anon,authenticated;
grant execute on function privado.concluir_tarefa_diligencia(uuid,uuid) to authenticated;
create function public.concluir_tarefa_diligencia(p_id_tarefa uuid,p_id_evidencia_versao_documento uuid) returns void language sql security invoker set search_path='' as $$select privado.concluir_tarefa_diligencia($1,$2)$$;
revoke all on function public.concluir_tarefa_diligencia(uuid,uuid) from public,anon; grant execute on function public.concluir_tarefa_diligencia(uuid,uuid) to authenticated;

create or replace function privado.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_org uuid; v_sess uuid; v_cons uuid; v_msg uuid; v_job uuid;
begin
 select id_organizacao into v_org from public.contratos where id=p_id_contrato;
 if v_org is null then raise exception 'Contrato não encontrado.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Acesso negado.'; end if;
 if p_id_sessao is null then
   insert into public.sessoes_copiloto(id_organizacao,id_contrato,titulo,criado_por) values(v_org,p_id_contrato,left(p_texto,120),auth.uid()) returning id into v_sess;
 else
   select id into v_sess from public.sessoes_copiloto where id=p_id_sessao and id_organizacao=v_org and criado_por=auth.uid() and status='ativa';
   if v_sess is null then raise exception 'Sessão inválida.'; end if;
 end if;
 insert into public.consultas_semanticas(id_organizacao,id_contrato,escopo,texto_consulta,filtros,modelo,criado_por,status)
 values(v_org,p_id_contrato,'contrato',p_texto,coalesce(p_filtros,'{}'::jsonb),p_modelo,auth.uid(),'pendente') returning id into v_cons;
 insert into public.mensagens_copiloto(id_organizacao,id_contrato,id_sessao,papel,conteudo,id_consulta_semantica,criado_por)
 values(v_org,p_id_contrato,v_sess,'usuario',p_texto,v_cons,auth.uid()) returning id into v_msg;
 v_job:=privado.enfileirar_job('ai',v_org,p_id_contrato,'consulta_semantica',v_cons,jsonb_build_object('entidade_tipo','consulta_semantica','id_consulta',v_cons,'id_sessao',v_sess),'copilot:'||v_cons::text);
 perform privado.registrar_evento_auditoria(v_org,'ConsultaCopilotoSolicitada','consultas_semanticas',v_cons,null,jsonb_build_object('id_sessao',v_sess,'id_job',v_job));
 return jsonb_build_object('id_sessao',v_sess,'id_consulta',v_cons,'id_mensagem',v_msg,'id_job',v_job);
end;$$;

commit;