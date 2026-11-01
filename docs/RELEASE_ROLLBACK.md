# ContaOS - Release e Rollback HML -> PROD

Este runbook separa homologação de produção. O HML nunca é convertido em PROD e dados do HML nunca são copiados como base operacional.

## Pré-condições para liberar uma versão

1. HML aprovado funcionalmente.
2. `supabase/tests/hml_acceptance.sql` sem cenário reprovado.
3. `supabase/tests/queues_edge_auth.sql` validado.
4. Security Advisor sem erro crítico.
5. Performance Advisor revisado.
6. Edge Functions homologadas e versionadas.
7. Nenhum segredo presente no GitHub.
8. Teste de carga executado com dados sintéticos.
9. Política de backup/PITR do projeto PROD confirmada e restauração testada em ambiente isolado.
10. Janela de release e responsável pelo go/no-go definidos.

## Preparação do repositório

1. No `contaos9999/develop`, executar `node supabase/scripts/materialize-migrations.mjs`.
2. Confirmar que não há divergências entre checkpoint e migrations individuais.
3. Registrar o commit homologado.
4. Promover esse commit para o fluxo/repositório de produção somente após aprovação.
5. Não alterar migrations já aplicadas. Correção de schema sempre entra como nova migration.

## Preparação do Supabase PROD

1. Confirmar projeto PROD separado do HML.
2. Configurar Auth, URLs permitidas, SMTP e políticas de senha conforme ambiente PROD.
3. Configurar Secrets/Vault no PROD sem copiar valores para GitHub:
   - `OPENAI_API_KEY`;
   - token interno dos workers;
   - URL do projeto;
   - segredos de webhooks quando aplicável.
4. Confirmar Storage privado e políticas RLS.
5. Confirmar `America/Sao_Paulo`, `pt-BR` e BRL.
6. Confirmar backup/PITR e ponto de recuperação anterior ao release.

## Aplicação das migrations

1. Vincular a CLI ao projeto PROD correto.
2. Executar dry-run do push de banco.
3. Revisar toda operação destrutiva antes de aplicar.
4. Aplicar migrations em ordem cronológica.
5. Conferir `supabase_migrations.schema_migrations` após a aplicação.
6. Nunca usar o HML como origem de dados de negócio para PROD.

## Deploy das Edge Functions

1. Deployar somente funções versionadas no commit homologado.
2. Manter JWT ativo em funções de usuário.
3. Funções service-to-service sem `verify_jwt` devem exigir token interno equivalente ao HML.
4. Validar que `service_role` e `OPENAI_API_KEY` não chegam ao navegador.
5. Executar smoke tests de autenticação positiva e negativa.

## Smoke test obrigatório pós-release

Validar, no mínimo:

- login e sessão;
- criação/seleção de organização conforme perfil;
- isolamento entre organizações;
- acesso a contrato autorizado e bloqueio de contrato alheio;
- upload e download assinados;
- processamento documental;
- OCR;
- fila de IA;
- portão `PODE APRESENTAR AO CONTRATANTE`;
- portão `PODE REAPRESENTAR AO CONTRATANTE`;
- jobs, retries e DLQ;
- cron de saúde operacional;
- Security Advisor sem Critical.

## Estratégia de rollback

### Frontend

Reverter para o último commit/release aprovado e restabelecer as variáveis do ambiente anterior quando necessário.

### Edge Functions

Redeployar a versão anterior versionada. Não editar função diretamente no painel sem refletir a mudança no repositório.

### Banco de dados

Preferência 1: migration compensatória nova, quando a mudança puder ser desfeita sem perda de dados.

Preferência 2: manter compatibilidade entre versões durante a janela de release, permitindo rollback do frontend/Edge sem reversão imediata do schema.

Preferência 3: em mudança destrutiva ou corrupção de dados, usar restauração/PITR para o ponto aprovado anterior ao release. Não improvisar `DROP`, `TRUNCATE` ou reversão manual em produção sem backup validado.

## Go/No-Go

A promoção é NO-GO quando houver qualquer um dos itens abaixo:

- Security Advisor com erro crítico;
- teste RLS A/B reprovado;
- portão crítico liberando com pendência;
- Storage público ou vazamento de segredo;
- migration não reproduzível;
- Edge Function crítica sem autenticação;
- backup/PITR indisponível para uma migration destrutiva;
- teste de carga com degradação não compreendida;
- provedor externo crítico indisponível sem estratégia operacional aprovada.

## Registro da release

Para cada release, registrar commit, migrations incluídas, versões das Edge Functions, resultado dos testes, responsáveis, data/hora em Brasília e decisão de go/no-go.
