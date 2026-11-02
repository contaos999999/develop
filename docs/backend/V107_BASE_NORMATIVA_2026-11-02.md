# V1-07 — certificação do backend normativo HML

Data:02/11/2026. Issue: #25. Autorização específica do usuário: «autorizo». Ambiente: HML `gklhhhyosgasnyoxlrui`; PROD intocado. Head final certificado: `06d65093746a584efa3b7d9f72bede1ccb38172d` (PRs #26, #27 e #28).

## Contrato entregue

Migration imutável aplicada no histórico HML como `20261102215515_v107_base_normativa_autorizada`.

- `salvar_fonte_normativa_v107`: fonte rascunho/edição otimista; situação material exige administrador e versão aprovada.
- `registrar_versao_fonte_v107`: append-only, vigência, arquivo seguro opcional ou texto, numeração sob lock e SHA-256 no backend.
- `aprovar_versao_fonte_v107`: administrador ou `direcao_aprovador`, fundamento humano, ator/data backend e hash esperado.
- `definir_aplicabilidade_fonte_v107`: versão aprovada, contrato no escopo, fundamento, CAS por timestamp, ator/data backend.
- Replays revalidam sessão/perfil/escopo antes do cache; payload divergente gera PT409; resposta e auditoria são únicas.
- DML direto de `fontes_normativas`, `versoes_fontes_normativas` e `aplicabilidades_fonte` foi retirado de `authenticated`; SELECT/RLS permanecem.
- Contexto oficial inclui apenas fonte ativa, versão aprovada, vigente e efetivamente aplicável. Sem base efetiva, o hash legado é preservado.
- Toda competência afetada é travada em ordem antes da mutação; a invalidação ocorre somente quando o snapshot normativo antes/depois muda. Norma global sem aplicabilidade e vigência futura não alteram o portão atual.
- O touch específico corrige o incremento duplo sem alterar o helper global.

A `direcao_aprovador` aprova versão/aplicabilidade. Edição da fonte e mudança de sua situação exigem o perfil CRUD e de aprovação; a interseção atual é `administrador`. A interface deve refletir esse contrato.

## TDD e revisão

RED real antes do DDL:31 casos,2 PASS/29 FAIL; comandos ausentes, grants de bypass e auditoria/contexto inexistentes. Fixtures revertidas.

Revisão independente encontrou invalidação excessiva, corrida com liberação e mudança retroativa de hash. Correções: comparação de snapshot efetivo, lock de todas as competências e chave condicional no snapshot. Nenhum outro bloqueador estático restou.

GREEN fresco:32/32 PASS, incluindo tenant/contrato/perfil/Master/sessão expirada/anon, replay após revogação, idempotência, versão obsoleta, CAS, hash, imutabilidade, auditoria, global sem aplicação, vigência futura, invalidação e captura de competência em análise. Todas as fixtures da suíte usam BEGIN/ROLLBACK.

Regressão SQL completa:18/18 arquivos PASS. Nove testes antigos foram alinhados ao schema já vigente: campo obrigatório `contratos.inicio`, wrapper ADM atual, UUID corrigido e remoção intencional de `pg_net`. Não houve relaxamento de expectativa de produto.

Advisor Security após DDL:0 Critical/0 High; permanece somente WARN preexistente `auth_leaked_password_protection` (https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Advisor Performance: apenas INFOs preexistentes de FKs sem índice; a migration não criou tabelas/FKs.

Grants comprovados: wrappers públicos SECURITY INVOKER, privados SECURITY DEFINER com `search_path=''`; authenticated EXECUTE, anon negado. Nas três tabelas, authenticated mantém somente SELECT.

## Concorrência e restore

O conector Supabase serializou duas chamadas concorrentes; essa tentativa não é contada como prova temporal. Ela gerou três eventos de auditoria imutáveis, uma organização e um usuário sintéticos inertes (`d707...`), sem sessões, vínculos, fontes, contratos ou competências. Não foi burlado o trigger de imutabilidade para apagá-los.

A prova temporal real está verde no restore isolado final: duas sessões PostgreSQL, lock de 3s na competência, mutação aguardou **2.573 ms** e terminou em `Depois:2`. A mesma reconstrução executou a suíte V107 em **32/32**, todos os testes históricos do workflow e registrou o histórico reconstruído. Evidências: [Restore Isolado 41538249128](https://github.com/contaos9999/develop/actions/runs/41538249128) e [Zero-Drift 41538249093](https://github.com/contaos9999/develop/actions/runs/41538249093), ambos `success` no head final. O run anterior 41537026213 já havia provado a concorrência (2.545 ms), mas falhou depois do PASS por um CR residual no fim do shell; a PR #28 normalizou somente esse byte e o rerun final ficou verde.

## Limites

Nenhuma tabela, Edge Function, Auth, Storage ou bucket novo. Nenhum segredo. Nenhuma edição no frontend fora do Lovable. Backend V1-07 certificado em HML; o PROMPT 28 segue para o plano corrigido do Lovable. PROD permaneceu intocado.
