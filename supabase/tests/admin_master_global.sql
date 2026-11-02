-- ContaOS 4.1 — Administrador Master global
-- Teste sintético com ROLLBACK integral.

begin;

create temporary table admin_master_resultados(
  teste text primary key,
  passou boolean not null,
  detalhe text
) on commit drop;

do $$
begin
  if to_regclass('privado.administradores_master') is null then
    raise exception 'RED: tabela privado.administradores_master ainda não existe';
  end if;
  if to_regprocedure('privado.usuario_e_administrador_master()') is null then
    raise exception 'RED: helper privado.usuario_e_administrador_master() ainda não existe';
  end if;
  if to_regprocedure('public.listar_organizacoes_disponiveis()') is null then
    raise exception 'RED: RPC public.listar_organizacoes_disponiveis() ainda não existe';
  end if;
end $$;

-- O restante do teste será executado após a migration, usando usuários/organizações
-- sintéticos e sempre finalizando em ROLLBACK. Critérios obrigatórios:
-- 1 Master ativo sem vínculo: acesso Org A e B;
-- 2 Master ativo: acesso a contratos de Org A e B;
-- 3 Master: usuario_possui_perfil(... administrador ...) = true em A e B;
-- 4 Master: usuario_possui_vinculo_ativo() = true mesmo sem vínculo físico;
-- 5 Master: validar_administrador_organizacao(A/B) passa;
-- 6 Master: listar_organizacoes_disponiveis retorna A e B com perfil administrador_master;
-- 7 administrador comum de A não acessa B;
-- 8 usuário comum sem vínculo não acessa A/B;
-- 9 Master inativo não possui acesso global;
-- 10 Master expirado não possui acesso global;
-- 11 anon/authenticated não possuem DML direto na tabela privada;
-- 12 PROD não é tocado.

rollback;
