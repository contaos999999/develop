# Applied history — Security Alerts HML — 02/11/2026

Projeto Supabase HML: `gklhhhyosgasnyoxlrui`
PROD: intocado

## Migrations aplicadas

1. Supabase version `20261102101304`
   - name: `hardening_security_alert_visibility`
   - source GitHub: `supabase/migrations/20261102103000_hardening_security_alert_visibility.sql`
   - efeito: substituição de policies SELECT amplas por `privado.usuario_possui_vinculo_ativo()`, remoção de SELECT/EXECUTE anônimo no escopo.

2. Supabase version `20261102101651`
   - name: `remove_unused_pg_net`
   - source GitHub: `supabase/migrations/20261102104000_remove_unused_pg_net.sql`
   - efeito: remoção `RESTRICT` de `pg_net`, após comprovação de ausência de dependências.

## Verificações pós-aplicação

- policies amplas `USING(true)` no escopo: 0;
- SELECT anon no escopo: 0;
- `pg_net`: ausente;
- Security Advisor: somente `auth_leaked_password_protection` permanece;
- scanner Lovable: 0 achados anteriores de RLS/exposição; apenas informação de senha vazada;
- smoke SYS-01/SYS-02: PASS;
- dependências `normalizar_paginacao`, `normalizar_erro_backend` e `obter_mensagem_sistema`: PASS;
- sessões sintéticas remanescentes: 0.

## Pendência externa

Leaked Password Protection exige Supabase Pro ou superior. Organização atual: Free/tier_free.
