# ContaOS 4.1 — Governança, Registro e Versionamento do Lovable

**Status:** obrigatório
**Ambiente:** HML
**Frontend:** Lovable + React + TypeScript
**Backend único:** Supabase HML certificado

## 1. Regra absoluta

Toda atividade executada no desenvolvimento do frontend ContaOS deve deixar evidência documentada, registrada e versionada no GitHub. Nenhuma decisão, prompt, alteração, teste, correção ou aceite relevante pode existir apenas no chat ou apenas no Lovable.

## 2. O que deve ser registrado

Para cada tarefa, tela, fluxo ou correção, registrar no mínimo:

- requisito(s) PRD e prompt(s) relacionados;
- prompt Lovable efetivamente utilizado;
- modo utilizado: Plan, Build, Test ou Audit;
- objetivo e escopo aprovado;
- arquivos autorizados e arquivos efetivamente alterados;
- backend consumido: tabelas, views, RPCs, Edge Functions, Storage, Auth, Queues ou Data API;
- decisões de UX/UI tomadas;
- tooltips e ajuda contextual aplicados quando pertinentes;
- estados tratados: loading, empty, success, saving, processing, erro, 403, conflito e demais aplicáveis;
- responsividade validada em 1440, 1280, 768 e 390 px;
- acessibilidade: teclado, foco, labels, status, tooltip e interação por toque quando aplicável;
- testes executados e resultado PASS/FAIL;
- evidências de RLS/perfil quando aplicável;
- evidências de Playwright/E2E quando aplicável;
- scan de segurança/secrets;
- resultado Zero-Drift/CI;
- desvios encontrados e correções realizadas;
- commit(s), branch, PR e decisão de aceite.

## 3. Versionamento

Toda alteração deve ser versionada no repositório `contaos9999/develop` durante HML.

É obrigatório:

1. trabalhar em branch apropriada quando houver alteração de implementação;
2. usar commits descritivos e específicos;
3. evitar commits genéricos como "update" ou "fix" sem contexto;
4. preservar histórico, sem reescrever migration aplicada;
5. usar PR para integrar alterações relevantes;
6. revisar diff antes da integração;
7. manter PROD intocada até GO formal.

## 4. Registro dos prompts

Os prompts usados no Lovable devem ser preservados em arquivo versionado ou registro de execução, contendo:

- número do prompt oficial do Manual Mestre, quando aplicável;
- IDs dos prompts atômicos/requisitos relacionados;
- texto efetivamente enviado ao Lovable, inclusive complementos;
- data/hora da execução;
- finalidade da execução;
- resultado gerado;
- PASS/FAIL do teste correspondente;
- correções subsequentes, se houver.

Não é permitido alterar silenciosamente um prompt oficial sem registrar a justificativa e sua relação com uma decisão funcional mais recente aprovada.

## 5. Registro por tela

Cada tela deve possuir rastreabilidade suficiente para responder:

- qual requisito a exige;
- qual prompt a criou;
- qual backend ela consome;
- quais permissões são necessárias;
- quais estados de UI existem;
- quais tooltips/ajudas foram aplicados;
- quais testes provam funcionamento;
- em qual commit/PR a versão atual foi produzida.

## 6. Tooltips

A política de tooltip definida em `PREMISSAS_IMPLEMENTACAO_LOVABLE_4_1.md` e `DESIGN_SYSTEM.md` é vinculante.

Sempre que um campo, botão, ícone, métrica, badge, termo, status ou ação se beneficiar de explicação contextual, o uso de tooltip deve ser avaliado e registrado na implementação da tela.

Desktop: hover + focus por teclado.
Tablet/mobile: alternativa por toque/popover/ícone de informação.
Tooltip não substitui label, erro, aviso crítico ou informação obrigatória permanente.

## 7. Evidências de teste

Sempre que tecnicamente possível, preservar no repositório ou nos artifacts do CI:

- saída de testes;
- screenshots de estados relevantes;
- relatório Playwright;
- logs sanitizados;
- resultado de lint/typecheck/build;
- resultado de security scan;
- resultado de Zero-Drift;
- resultado de restore/reprodutibilidade quando o backend for afetado.

Nenhuma evidência deve conter secret, token, senha, chave, PII desnecessária ou conteúdo sensível do usuário.

## 8. FAIL e lacunas

Todo FAIL deve ser registrado. Não ocultar, não apagar e não avançar como se estivesse aprovado.

Quando o frontend revelar ausência de capacidade no Supabase, registrar `LACUNA DE BACKEND`, interromper aquela implementação e abrir tarefa separada de backend. O Lovable não pode criar backend paralelo para contornar a lacuna.

## 9. Aceite

Uma tela, fluxo ou módulo somente poderá ser marcado como concluído quando houver rastreabilidade suficiente entre:

PRD → requisito → prompt → plano → código → backend → testes → evidências → commit/PR → aceite.

## 10. Regra final

Se algo foi decidido, implementado, testado, corrigido ou aprovado, deve existir uma evidência versionada correspondente no GitHub.

Chat, Lovable e Supabase são meios de execução. O GitHub é o registro versionado da implementação e de sua governança durante HML.
