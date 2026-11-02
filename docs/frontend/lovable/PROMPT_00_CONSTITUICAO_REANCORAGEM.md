# ContaOS 4.1 — PROMPT 00 — Constituição e reancoragem

**Data:** 02/11/2026  
**Ambiente:** HML  
**Branch de governança:** `design/frontend-master-plan`  
**Fonte:** `Manual_Mestre_Prompts_4_1_100_PRD.docx`  
**Status:** pronto para execução no Lovable  

## Objetivo

Fazer o Lovable repetir e aceitar as regras constitucionais do ContaOS antes de qualquer construção.

## Pré-condição

O Supabase a ser conectado deve ser exclusivamente o projeto HML. PROD não pode ser utilizado durante desenvolvimento.

## A. PLAN MODE — mensagem exata

```text
MODO: PLAN. NÃO ALTERE CÓDIGO NEM BANCO.
Este é o ContaOS. Arquitetura oficial: frontend Lovable/React/TypeScript + backend Supabase próprio conectado ao projeto.
Regras absolutas:
1. Supabase é a única fonte de verdade.
2. Toda tabela de negócio exposta usa RLS e grants mínimos.
3. O frontend nunca recebe secret key, senha de banco ou chave privada.
4. CRUD simples pode usar Data API com RLS.
5. Transições críticas usam RPC/Database Function ou Edge Function autenticada.
6. PODE APRESENTAR AO CONTRATANTE somente com 100,00% dos requisitos obrigatórios e aplicáveis conformes.
7. PODE REAPRESENTAR AO CONTRATANTE somente com 100% dos apontamentos da rodada tratados.
8. VALIDADA somente após parecer final favorável do contratante.
9. Alerta histórico transversal de outro contrato é informativo e não integra o portão de 100% por si só.
10. Documentos não são sobrescritos; nova correção = nova versão.
11. IA não cria obrigação sem fonte, escopo e aprovação humana.
12. Uma tarefa não pode alterar área fora do escopo.
13. Se precisar de algo não autorizado, PARE e explique.
Responda apenas com um resumo dessas regras e diga se o Supabase conectado é o projeto HML. Não implemente nada.
```

## B. BUILD MODE — somente após aprovação do PLAN

```text
MODO: BUILD.
Salve as regras constitucionais aprovadas nas Project Instructions e crie/atualize AGENTS.md e docs/frontend/ARQUITETURA.md com o mesmo conteúdo. Não crie tabelas ainda. Não altere design.
Ao final, liste exatamente os arquivos alterados.
```

## C. TESTE — somente depois do BUILD

```text
NÃO ALTERE NADA.
Confirme:
- Project Instructions contêm backend Supabase próprio;
- AGENTS.md existe;
- nenhuma tabela/migration foi criada;
- nenhum secret foi criado;
- nenhum backend paralelo foi habilitado.
Responda PASS/FAIL por item.
PARE AQUI: Só avance ao próximo número se o teste responder PASS nos itens obrigatórios.
```

## Regras adicionais vinculantes já aprovadas pelo produto

Além do texto literal acima, a execução do Lovable fica subordinada a:

- `docs/frontend/PREMISSAS_IMPLEMENTACAO_LOVABLE_4_1.md`;
- `docs/frontend/DESIGN_SYSTEM.md`;
- `docs/frontend/GOVERNANCA_REGISTRO_VERSIONAMENTO_LOVABLE.md`;
- documentos canônicos `00` a `18`, inclusive `08A` a `08D`;
- backend Supabase HML efetivamente existente e certificado;
- PROMPT 00–99 e Caderno Atômico 001–096;
- registro e versionamento no GitHub de toda decisão, prompt, alteração, teste, evidência, PASS/FAIL e correção.

## Critério de avanço

O PROMPT 00 só é considerado concluído quando o bloco TESTE estiver integralmente PASS. Nenhuma tela do ContaOS poderá ser construída antes disso.
