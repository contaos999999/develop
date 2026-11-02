# SEC-BACKEND-ALERTS-HML-2026-11-02 — Resultado final

Data: 02/11/2026
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`
Branch: `security/backend-alerts-hml-2026-11-02`
PROD: intocado

## Conclusão

Os alertas de RLS/exposição identificados pelo scanner do Lovable foram corrigidos no HML. O warning oficial `extension_in_public` também foi eliminado com a remoção segura da extensão `pg_net`, que estava sem dependências.

Permanece 1 warning oficial: `auth_leaked_password_protection`. A documentação oficial do Supabase informa que Leaked Password Protection está disponível somente no plano Pro ou superior. A organização ContaOS está no plano Free (`tier_free`), portanto esse warning não pode ser eliminado sem alteração de plano. Nenhum workaround caseiro foi criado.

## Migrations aplicadas no HML

| Versão Supabase | Nome | Arquivo versionado |
|---|---|---|
| `20261102101304` | `hardening_security_alert_visibility` | `supabase/migrations/20261102103000_hardening_security_alert_visibility.sql` |
| `20261102101651` | `remove_unused_pg_net` | `supabase/migrations/20261102104000_remove_unused_pg_net.sql` |

## RLS e grants

Foram endurecidas:
- `public.configuracao_api`
- `public.configuracao_upload`
- `public.perfis_usuarios`
- `public.catalogo_mensagens_sistema`
- `public.catalogo_status_ui`
- `public.configuracao_localizacao`

Todas as policies SELECT do escopo agora exigem `privado.usuario_possui_vinculo_ativo()`, que combina sessão Auth ativa com vínculo ativo no ContaOS.

Estado final estrutural:
- policies SELECT amplas `USING(true)`: **0**;
- grants `anon` SELECT no escopo: **0**;
- `pg_net` instalado: **0**;
- helper `privado.usuario_possui_vinculo_ativo()`: presente.

As RPCs `public.obter_mensagem_sistema(text)` e `public.normalizar_erro_backend(text,text)` deixaram de ser executáveis por `anon` e permanecem disponíveis a `authenticated`/`service_role` conforme o uso interno.

## Teste positivo autenticado

Foi executado teste transacional sem emissão de token, usando o usuário HML de teste já existente e uma sessão sintética sem credencial, removida antes do commit.

Resultado com sessão ativa + vínculo ativo:
- `configuracao_api`: 1 linha visível;
- `configuracao_upload`: 1 linha visível;
- `perfis_usuarios`: 10 linhas visíveis;
- `catalogo_mensagens_sistema`: 38 linhas visíveis;
- `catalogo_status_ui`: 23 linhas visíveis;
- `configuracao_localizacao`: 1 linha visível;
- `obter_mensagem_sistema(...)`: retorno não nulo;
- `normalizar_paginacao(1,25)`: retorno válido;
- `normalizar_erro_backend('42501',null)`: retorno válido.

Sessões sintéticas remanescentes após os testes: **0**.

## Teste negativo anônimo

Com somente publishable key e sem Bearer/session, o teste REST retornou HTTP 401 e nenhum dado para as seis tabelas. As RPCs `obter_mensagem_sistema` e `normalizar_erro_backend` também retornaram HTTP 401 / `42501`.

## Scanner Lovable pós-hardening

Os 6 achados anteriores não reapareceram:
- leitura ampla `authenticated` de `configuracao_api`;
- leitura ampla `authenticated` de `configuracao_upload`;
- leitura ampla `authenticated` de `perfis_usuarios`;
- leitura `anon` de `catalogo_mensagens_sistema`;
- leitura `anon` de `catalogo_status_ui`;
- leitura `anon` de `configuracao_localizacao`.

Scanner atual: 1 achado informativo, `People can choose a password that is already leaked`, correspondente à configuração de Auth bloqueada pelo plano Free.

## Smoke de regressão SYS-01 / SYS-02

Foi executado smoke test read-only no preview Lovable após o hardening:

- `/login`: HTTP 200; E-mail, Senha e Entrar visíveis;
- credencial propositalmente inválida: Auth HTTP 400, copy neutra `E-mail ou senha inválidos.`, permanência em `/login`;
- `/esqueci-senha`: HTTP 200; E-mail e `Enviar link` visíveis;
- uma solicitação de recuperação para alias controlado: HTTP 200, copy neutra, nenhuma sessão criada;
- console: nenhum erro de aplicação ou dado sensível;
- network: nenhuma `secret/service_role`;
- `git status`: vazio e idêntico antes/depois;
- nenhuma correção ou alteração de código realizada nesse smoke.

O caminho autenticado de leitura das tabelas endurecidas foi coberto diretamente no backend pelo teste positivo com sessão sintética sem token e vínculo ativo.

## pg_net

Baseline: `pg_net 0.20.4` estava no schema `public` e `relocatable=false`.

Antes de remover:
- nenhuma função `public/internal` usando `net.*`;
- nenhum trigger de Database Webhook / `supabase_functions.http_request`;
- nenhum job `pg_cron` usando `net.*`, `http_request`, `http_post` ou `http_get`;
- `DROP EXTENSION pg_net RESTRICT` executou com sucesso dentro de transação seguida de `ROLLBACK`, comprovando ausência de dependentes.

Foi então aplicada migration `DROP EXTENSION IF EXISTS pg_net RESTRICT`, sem `CASCADE`. Jobs cron existentes continuaram executando após a remoção.

## Supabase Security Advisor final

O warning `extension_in_public` desapareceu.

Resta apenas:
- `auth_leaked_password_protection` — Leaked Password Protection Disabled.

Dependência externa: upgrade do Supabase para Pro ou superior.

## Observação de migration

O conector `apply_migration` já encapsula o SQL em transação. Como os arquivos versionados continham `BEGIN/COMMIT`, os logs registraram avisos `there is already a transaction in progress` / `there is no transaction in progress`, sem falha funcional. Para próximas migrations executadas por esse conector, enviar o corpo sem `BEGIN/COMMIT`, mantendo os arquivos históricos imutáveis.

## Estado final

- RLS/exposição: **CORRIGIDO**.
- Exposição anônima: **CORRIGIDA**.
- `pg_net` em `public`: **CORRIGIDO / EXTENSÃO REMOVIDA**.
- Leaked Password Protection: **PENDÊNCIA EXTERNA DE PLANO (FREE → PRO+)**.
- Backend PROD: **NÃO ALTERADO**.
- Frontend: **NÃO ALTERADO durante esta tarefa**.
- Smoke SYS-01/SYS-02: **PASS**.
