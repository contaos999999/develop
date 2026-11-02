alter policy apontamentos_internos_update on public.apontamentos_internos
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade']::text[]));

alter policy contratos_update on public.contratos
  with check (privado.usuario_tem_acesso_contrato(id) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));

alter policy contratos_fornecedores_update on public.contratos_fornecedores
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','juridico_conformidade']::text[]));

alter policy documentos_competencia_update on public.documentos_competencia
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]));

alter policy documentos_contrato_update on public.documentos_contrato
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

alter policy fontes_financeiras_update on public.fontes_financeiras
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro']::text[]));

alter policy itens_lista_update on public.itens_lista
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

alter policy linhas_orcamentarias_update on public.linhas_orcamentarias
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

alter policy listas_update on public.listas_verificacao
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

alter policy planos_acao_update on public.planos_acao
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]));

alter policy propostas_update on public.propostas_orcamentarias
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));

alter policy regras_conformidade_update on public.regras_conformidade
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','juridico_conformidade']::text[]));

alter policy tarefas_alerta_update on public.tarefas_alerta
  with check (privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato','financeiro','contabilidade']::text[]));
