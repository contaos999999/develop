create policy privado_configuracoes_sem_acesso_cliente
on privado.configuracoes_internas
for all
to anon, authenticated
using (false)
with check (false);

create policy privado_rate_limit_sem_acesso_cliente
on privado.consumo_rate_limit_api
for all
to anon, authenticated
using (false)
with check (false);

comment on policy privado_configuracoes_sem_acesso_cliente on privado.configuracoes_internas is 'Bloqueio explícito para roles de cliente. Acesso permitido apenas por funções internas/roles privilegiadas.';
comment on policy privado_rate_limit_sem_acesso_cliente on privado.consumo_rate_limit_api is 'Bloqueio explícito para roles de cliente. Acesso permitido apenas por funções internas/roles privilegiadas.';
