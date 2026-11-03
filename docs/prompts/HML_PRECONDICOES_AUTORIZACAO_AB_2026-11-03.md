# ContaOS 4.1 — Pré-requisitos de testes reais A/B no Supabase HML

Data: 03/11/2026. Referência do projeto: `gklhhhyosgasnyoxlrui`. Consulta SQL somente leitura, sem identificar pessoas e sem alterar qualquer registro.

## Inventário do ambiente de teste

| Métrica | Resultado |
| --- | ---: |
| Organizações cadastradas | **4** |
| Contratos cadastrados | **0** |
| Vínculos de usuário cadastrados | **1** |
| Usuários com vínculo ativo | **1** |
| Organizações com usuários vinculados ativos | **1** |

**Consulta utilizada:** `SELECT count(*) FROM public.organizacoes;`, `SELECT count(*) FROM public.contratos;`, `SELECT count(*) FROM public.vinculos_usuarios;`, `SELECT count(DISTINCT id_usuario) FROM public.vinculos_usuarios WHERE ativo;` e `SELECT count(DISTINCT id_organizacao) FROM public.vinculos_usuarios WHERE ativo;`.

## Consequência técnica

Uma certificação real de RLS/permissões cruzadas exige no mínimo dois titulares de teste com vínculos válidos em organizações distintas e contratos de teste efetivamente associados a cada organização. No estado atual, o HML não dispõe dessas condições. Respostas de UI simuladas e leituras de catálogo não podem ser apresentadas como provas de acesso negado efetivo em A/B.

## Condições para liberar o Teste C funcional de autorização

1. Criar ou disponibilizar **contas próprias de homologação** com caixas de e-mail controladas e perfis distintos, sem publicar senhas/tokens.
2. Dispor de pelo menos dois contratos de teste, um por organização, com dados não sensíveis e critério de limpeza/retorno do ambiente.
3. Registrar cenário positivo e negativo de consulta, edição, função privilegiada e storage, segundo escopo de cada PROMPT 01–15 e 16–38.
4. Gerar evidências sanitizadas de HTTP/status/correlation_id e registrar horário no fuso de Brasília, nunca segredo JWT ou dado pessoal.

**Nenhum usuário, contrato, schema, Auth, RLS, Storage ou PROD foi alterado neste diagnóstico.**

Documentos relacionados: `docs/prompts/AUDITORIA_RLS_117_183_RPC6_HML_2026-11-03.md`, `docs/prompts/PLANO_SANEAMENTO_39_PROMPTS_2026-11-03.json` e `docs/prompts/MATRIZ_416_CRITERIOS_STATUS_E_PROVAS_2026-11-03.json`.
