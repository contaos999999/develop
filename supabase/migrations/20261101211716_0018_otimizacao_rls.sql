begin;

-- auth.uid() como initPlan, evitando reavaliação por linha.
drop policy if exists usuarios_select_self on public.usuarios;
create policy usuarios_select_self on public.usuarios for select to authenticated using (id_usuario = (select auth.uid()));
drop policy if exists usuarios_update_self on public.usuarios;
create policy usuarios_update_self on public.usuarios for update to authenticated using (id_usuario = (select auth.uid())) with check (id_usuario = (select auth.uid()));

drop policy if exists vinculos_select on public.vinculos_usuarios;
create policy vinculos_select on public.vinculos_usuarios for select to authenticated using (id_usuario = (select auth.uid()) or privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor']::text[]));

drop policy if exists consultas_semanticas_select on public.consultas_semanticas;
create policy consultas_semanticas_select on public.consultas_semanticas for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists sessoes_copiloto_select on public.sessoes_copiloto;
create policy sessoes_copiloto_select on public.sessoes_copiloto for select to authenticated using(criado_por=(select auth.uid()) and privado.usuario_tem_acesso_organizacao(id_organizacao) and (id_contrato is null or privado.usuario_tem_acesso_contrato(id_contrato)));

drop policy if exists mensagens_copiloto_select on public.mensagens_copiloto;
create policy mensagens_copiloto_select on public.mensagens_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.sessoes_copiloto s where s.id=id_sessao and s.criado_por=(select auth.uid())));

drop policy if exists fontes_resposta_copiloto_select on public.fontes_resposta_copiloto;
create policy fontes_resposta_copiloto_select on public.fontes_resposta_copiloto for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao) and exists(select 1 from public.mensagens_copiloto m join public.sessoes_copiloto s on s.id=m.id_sessao where m.id=id_mensagem and s.criado_por=(select auth.uid())));

-- Substitui FOR ALL por INSERT/UPDATE explícitos. DELETE permanece negado por ausência de policy.
drop policy if exists contratos_fornecedores_write on public.contratos_fornecedores;
create policy contratos_fornecedores_insert on public.contratos_fornecedores for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[]));
create policy contratos_fornecedores_update on public.contratos_fornecedores for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists controles_write on public.controles_conformidade;
create policy controles_insert on public.controles_conformidade for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy controles_update on public.controles_conformidade for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists documentos_competencia_write on public.documentos_competencia;
create policy documentos_competencia_insert on public.documentos_competencia for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]));
create policy documentos_competencia_update on public.documentos_competencia for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists documentos_contrato_write on public.documentos_contrato;
create policy documentos_contrato_insert on public.documentos_contrato for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy documentos_contrato_update on public.documentos_contrato for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists entidades_org_write on public.entidades_organizacionais;
create policy entidades_org_insert on public.entidades_organizacionais for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));
create policy entidades_org_update on public.entidades_organizacionais for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade']::text[]));

drop policy if exists fontes_financeiras_write on public.fontes_financeiras;
create policy fontes_financeiras_insert on public.fontes_financeiras for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[]));
create policy fontes_financeiras_update on public.fontes_financeiras for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists fontes_write on public.fontes_normativas;
create policy fontes_insert on public.fontes_normativas for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy fontes_update on public.fontes_normativas for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));

drop policy if exists fornecedores_write on public.fornecedores;
create policy fornecedores_insert on public.fornecedores for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy fornecedores_update on public.fornecedores for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

drop policy if exists itens_lista_write on public.itens_lista;
create policy itens_lista_insert on public.itens_lista for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy itens_lista_update on public.itens_lista for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists linhas_orcamentarias_write on public.linhas_orcamentarias;
create policy linhas_orcamentarias_insert on public.linhas_orcamentarias for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy linhas_orcamentarias_update on public.linhas_orcamentarias for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists listas_write on public.listas_verificacao;
create policy listas_insert on public.listas_verificacao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy listas_update on public.listas_verificacao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists nao_conformidades_write on public.nao_conformidades;
create policy nao_conformidades_insert on public.nao_conformidades for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy nao_conformidades_update on public.nao_conformidades for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists planos_acao_write on public.planos_acao;
create policy planos_acao_insert on public.planos_acao for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy planos_acao_update on public.planos_acao for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists planos_remediacao_write on public.planos_remediacao;
create policy planos_remediacao_insert on public.planos_remediacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));
create policy planos_remediacao_update on public.planos_remediacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','auditor']::text[]));

drop policy if exists propostas_write on public.propostas_orcamentarias;
create policy propostas_insert on public.propostas_orcamentarias for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy propostas_update on public.propostas_orcamentarias for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists recursos_admin_write on public.recursos_organizacao;
create policy recursos_admin_insert on public.recursos_organizacao for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy recursos_admin_update on public.recursos_organizacao for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));

drop policy if exists regras_conformidade_write on public.regras_conformidade;
create policy regras_conformidade_insert on public.regras_conformidade for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));
create policy regras_conformidade_update on public.regras_conformidade for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists riscos_corporativos_write on public.riscos_corporativos;
create policy riscos_corporativos_insert on public.riscos_corporativos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));
create policy riscos_corporativos_update on public.riscos_corporativos for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','juridico_conformidade','direcao_aprovador']::text[]));

drop policy if exists tarefas_alerta_write on public.tarefas_alerta;
create policy tarefas_alerta_insert on public.tarefas_alerta for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
create policy tarefas_alerta_update on public.tarefas_alerta for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

drop policy if exists tarefas_diligencia_write on public.tarefas_diligencia;
create policy tarefas_diligencia_insert on public.tarefas_diligencia for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));
create policy tarefas_diligencia_update on public.tarefas_diligencia for update to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[])) with check(privado.usuario_tem_acesso_contrato(id_contrato));

commit;
