begin;

alter function public.aprovar_apresentacao(uuid,text) set schema privado;
alter function public.aprovar_contestacao(uuid,boolean,text) set schema privado;
alter function public.aprovar_excecao_controle(uuid,boolean) set schema privado;
alter function public.avaliar_portao_conformidade(uuid) set schema privado;
alter function public.avaliar_portao_reapresentacao(uuid) set schema privado;
alter function public.criar_acesso_temporario_pacote(uuid,timestamptz,text,integer) set schema privado;
alter function public.criar_cliente_api(uuid,text,text[]) set schema privado;
alter function public.criar_competencia(uuid,date,date,date,date) set schema privado;
alter function public.criar_organizacao(text,text,varchar,text) set schema privado;
alter function public.criar_pacote_evidencias(uuid,uuid,jsonb,timestamptz) set schema privado;
alter function public.criar_webhook(uuid,text,text,text[]) set schema privado;
alter function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) set schema privado;
alter function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) set schema privado;
alter function public.encerrar_nao_conformidade(uuid,text) set schema privado;
alter function public.enfileirar_evento_webhook(uuid,text,text,uuid,jsonb) set schema privado;
alter function public.enfileirar_processamento_documento(uuid,text) set schema privado;
alter function public.iniciar_consulta_copiloto(uuid,uuid,text,jsonb,text) set schema privado;
alter function public.liberar_reapresentacao(uuid,text) set schema privado;
alter function public.promover_precedente_para_regra(uuid,text,text,text,text,text) set schema privado;
alter function public.publicar_controle(uuid,text,jsonb,date,date) set schema privado;
alter function public.publicar_regra_candidata(uuid,uuid,date,date) set schema privado;
alter function public.registrar_apresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.registrar_parecer_contratante(uuid,uuid,uuid,text,boolean,text,date,date) set schema privado;
alter function public.registrar_reapresentacao(uuid,text,text,text,uuid) set schema privado;
alter function public.rotacionar_cliente_api(uuid) set schema privado;
alter function public.solicitar_analise_competencia(uuid,text) set schema privado;
alter function public.solicitar_importacao_financeira(uuid,uuid,text,text) set schema privado;
alter function public.tratar_alerta_preventivo(uuid,text,text,uuid) set schema privado;

-- Implementações privadas só podem ser chamadas pelo papel autenticado via wrapper e não são expostas no Data API.
grant execute on all functions in schema privado to authenticated;

create function public.aprovar_apresentacao(p_id_competencia uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.aprovar_apresentacao($1,$2)$$;
create function public.aprovar_contestacao(p_id_contestacao uuid,p_aprovar boolean,p_fundamento text default null) returns void language sql security invoker set search_path='' as $$select privado.aprovar_contestacao($1,$2,$3)$$;
create function public.aprovar_excecao_controle(p_id_excecao uuid,p_aprovar boolean) returns void language sql security invoker set search_path='' as $$select privado.aprovar_excecao_controle($1,$2)$$;
create function public.avaliar_portao_conformidade(p_id_competencia uuid) returns jsonb language sql stable security invoker set search_path='' as $$select privado.avaliar_portao_conformidade($1)$$;
create function public.avaliar_portao_reapresentacao(p_id_ciclo uuid) returns jsonb language sql stable security invoker set search_path='' as $$select privado.avaliar_portao_reapresentacao($1)$$;
create function public.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_acesso_temporario_pacote($1,$2,$3,$4)$$;
create function public.criar_cliente_api(p_id_organizacao uuid,p_nome text,p_escopos text[] default '{}'::text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_cliente_api($1,$2,$3)$$;
create function public.criar_competencia(p_id_contrato uuid,p_competencia_referencia date,p_periodo_inicio date default null,p_periodo_fim date default null,p_data_limite date default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_competencia($1,$2,$3,$4,$5)$$;
create function public.criar_organizacao(p_razao_social text,p_nome_fantasia text default null,p_cnpj varchar default null,p_timezone text default 'America/Bahia') returns uuid language sql security invoker set search_path='' as $$select privado.criar_organizacao($1,$2,$3,$4)$$;
create function public.criar_pacote_evidencias(p_id_organizacao uuid,p_id_contrato uuid,p_escopo jsonb,p_expira_em timestamptz default null) returns uuid language sql security invoker set search_path='' as $$select privado.criar_pacote_evidencias($1,$2,$3,$4)$$;
create function public.criar_webhook(p_id_organizacao uuid,p_nome text,p_url text,p_eventos text[]) returns jsonb language sql security invoker set search_path='' as $$select privado.criar_webhook($1,$2,$3,$4)$$;
create function public.definir_acesso_contrato_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true) returns void language sql security invoker set search_path='' as $$select privado.definir_acesso_contrato_usuario($1,$2,$3,$4)$$;
create function public.definir_vinculo_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true) returns uuid language sql security invoker set search_path='' as $$select privado.definir_vinculo_usuario($1,$2,$3,$4,$5)$$;
create function public.encerrar_nao_conformidade(p_id_nao_conformidade uuid,p_fundamento text) returns void language sql security invoker set search_path='' as $$select privado.encerrar_nao_conformidade($1,$2)$$;
create function public.enfileirar_evento_webhook(p_id_webhook uuid,p_evento text,p_entidade_tipo text,p_entidade_id uuid,p_payload_ref jsonb) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_evento_webhook($1,$2,$3,$4,$5)$$;
create function public.enfileirar_processamento_documento(p_id_versao_documento uuid,p_chave_idempotencia text default null) returns uuid language sql security invoker set search_path='' as $$select privado.enfileirar_processamento_documento($1,$2)$$;
create function public.iniciar_consulta_copiloto(p_id_contrato uuid,p_id_sessao uuid,p_texto text,p_filtros jsonb default '{}'::jsonb,p_modelo text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.iniciar_consulta_copiloto($1,$2,$3,$4,$5)$$;
create function public.liberar_reapresentacao(p_id_ciclo uuid,p_fundamento text default null) returns jsonb language sql security invoker set search_path='' as $$select privado.liberar_reapresentacao($1,$2)$$;
create function public.promover_precedente_para_regra(p_id_precedente uuid,p_codigo_regra text,p_descricao text,p_efeito text default 'informativo',p_criticidade text default 'media',p_escopo_aplicacao text default 'contrato') returns uuid language sql security invoker set search_path='' as $$select privado.promover_precedente_para_regra($1,$2,$3,$4,$5,$6)$$;
create function public.publicar_controle(p_id_controle uuid,p_texto text,p_evidencia_requerida jsonb,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_controle($1,$2,$3,$4,$5)$$;
create function public.publicar_regra_candidata(p_id_regra_candidata uuid,p_id_avaliacao_impacto uuid,p_vigencia_inicio date,p_vigencia_fim date default null) returns uuid language sql security invoker set search_path='' as $$select privado.publicar_regra_candidata($1,$2,$3,$4)$$;
create function public.registrar_apresentacao(p_id_competencia uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_apresentacao($1,$2,$3,$4,$5)$$;
create function public.registrar_parecer_contratante(p_id_competencia uuid,p_id_apresentacao uuid,p_id_arquivo uuid,p_resultado_geral text,p_parecer_final_favoravel boolean default false,p_numero_documento text default null,p_data_emissao date default null,p_prazo_resposta date default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_parecer_contratante($1,$2,$3,$4,$5,$6,$7,$8)$$;
create function public.registrar_reapresentacao(p_id_ciclo uuid,p_idempotency_key text,p_protocolo text default null,p_forma_apresentacao text default null,p_id_comprovante_arquivo uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.registrar_reapresentacao($1,$2,$3,$4,$5)$$;
create function public.rotacionar_cliente_api(p_id_cliente uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.rotacionar_cliente_api($1)$$;
create function public.solicitar_analise_competencia(p_id_competencia uuid,p_tipo text default 'completa') returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_analise_competencia($1,$2)$$;
create function public.solicitar_importacao_financeira(p_id_fonte uuid,p_id_arquivo uuid,p_hash text,p_chave_deduplicacao text) returns uuid language sql security invoker set search_path='' as $$select privado.solicitar_importacao_financeira($1,$2,$3,$4)$$;
create function public.tratar_alerta_preventivo(p_id_alerta uuid,p_decisao text,p_fundamento text,p_id_evidencia_versao_documento uuid default null) returns uuid language sql security invoker set search_path='' as $$select privado.tratar_alerta_preventivo($1,$2,$3,$4)$$;

revoke execute on all functions in schema public from public,anon;
grant execute on all functions in schema public to authenticated;

commit;
