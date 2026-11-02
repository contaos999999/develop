begin;

-- Gestão de perfil, ativação e escopo de contratos é operação de autorização.
-- A RPC definir_vinculo_usuario() já valida perfil administrativo, perfil alvo
-- e registra evento de auditoria. DML direto permitiria contornar essa trilha.

revoke insert, update on table public.vinculos_usuarios from authenticated;

drop policy if exists vinculos_admin_insert on public.vinculos_usuarios;
drop policy if exists vinculos_admin_update on public.vinculos_usuarios;

-- Leitura permanece regida pela policy existente. Mutação deve ocorrer somente
-- pelas RPCs oficiais public.definir_vinculo_usuario() e
-- public.definir_acesso_contrato_usuario().

commit;
