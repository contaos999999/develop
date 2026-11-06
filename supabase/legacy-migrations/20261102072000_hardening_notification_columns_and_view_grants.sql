begin;

-- A central financeira é uma view security_invoker somente de leitura.
-- Remover grants de escrita evita superfície latente caso sua definição mude.
revoke insert, update, delete on table public.v_central_excecoes_financeiras from authenticated;

-- O usuário final pode somente marcar/desmarcar a própria notificação como lida.
-- Campos de conteúdo e entrega são produzidos/geridos pelo backend e workers.
revoke update on table public.notificacoes from authenticated;
grant update (lida_em) on table public.notificacoes to authenticated;

-- A policy notificacoes_update existente continua impondo ownership da linha.

commit;
