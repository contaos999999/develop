# SEC-BACKEND-ALERTS-HML-2026-11-02 — Baseline

Data: 02/11/2026
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`
PROD: intocado

## Objetivo

Corrigir os alertas de segurança corrigíveis identificados no backend HML, sem alterar o frontend e sem promover nada para produção.

## Baseline oficial Supabase Security Advisor

1. `extension_in_public`: extensão `pg_net` instalada em `public`.
2. `auth_leaked_password_protection`: proteção contra senhas vazadas desabilitada.

## Achados adicionais confirmados por inspeção de policies

### Leitura ampla para `authenticated`
- `public.configuracao_api`: policy `configuracao_api_leitura`, `SELECT`, `USING (true)`.
- `public.configuracao_upload`: policy `configuracao_upload_leitura`, `SELECT`, `USING (true)`.
- `public.perfis_usuarios`: policy `perfis_select`, `SELECT`, `USING (true)`.

### Leitura pública para `anon`
- `public.catalogo_mensagens_sistema`: policy `catalogo_mensagens_leitura`, `SELECT`, `USING (true)` para `{anon,authenticated}`.
- `public.catalogo_status_ui`: policy `catalogo_status_leitura`, `SELECT`, `USING (true)` para `{anon,authenticated}`.
- `public.configuracao_localizacao`: policy `configuracao_localizacao_leitura`, `SELECT`, `USING (true)` para `{anon,authenticated}`.

## Observações preliminares

- `public.normalizar_paginacao(...)` consulta `public.configuracao_api` internamente.
- `public.obter_mensagem_sistema(...)` consulta `public.catalogo_mensagens_sistema` internamente.
- Não foram encontradas, na inspeção preliminar, funções `public`/`internal` nem jobs `pg_cron` chamando `net.*`.
- A organização Supabase atual está no plano `free`; a proteção nativa contra senhas vazadas pode exigir upgrade de plano para habilitação.

## Estratégia

1. mapear dependências e consumidores de cada tabela;
2. criar testes negativos/positivos antes das mudanças;
3. aplicar migrations mínimas e reversíveis;
4. validar funções/rotinas dependentes;
5. mover `pg_net` apenas após confirmar ausência de dependências quebráveis;
6. reexecutar Security Advisor e scanner funcional;
7. documentar exceções de plano e pendências impossíveis no Free.

## Regra de segurança

Nenhuma policy será simplesmente removida sem substituição segura quando houver consumo legítimo. Nenhuma mudança será aplicada em PROD.
