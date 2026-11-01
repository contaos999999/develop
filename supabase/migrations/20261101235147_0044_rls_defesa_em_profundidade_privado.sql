alter table privado.configuracoes_internas enable row level security;
alter table privado.consumo_rate_limit_api enable row level security;

revoke all on privado.configuracoes_internas from public, anon, authenticated;
revoke all on privado.consumo_rate_limit_api from public, anon, authenticated;

comment on table privado.configuracoes_internas is 'Configurações internas do ContaOS. RLS habilitada como defesa em profundidade; sem policies para roles de cliente.';
comment on table privado.consumo_rate_limit_api is 'Contador interno de rate limit. RLS habilitada como defesa em profundidade; sem policies para roles de cliente.';
