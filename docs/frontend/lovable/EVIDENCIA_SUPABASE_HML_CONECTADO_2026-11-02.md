# Evidência de conexão Lovable ↔ Supabase HML

**Data:** 02/11/2026  
**Projeto Lovable:** ContaOS HML  
**Lovable Project ID:** `b113dd59-6caf-4c92-8302-457a037a0c6f`  
**Supabase HML esperado:** `gklhhhyosgasnyoxlrui`

## Resultado da verificação

A verificação foi executada em **Plan Mode**, sem autorização para alterar código ou banco.

Resultado retornado pelo Lovable:

- backend Supabase ativo no projeto: **sim**;
- project ref conectado: `gklhhhyosgasnyoxlrui`;
- correspondência exata com o HML oficial: **PASS**;
- backend paralelo/Lovable Cloud adicional como segunda fonte de verdade: **não detectado**;
- criação de tabela durante a verificação: **não**;
- criação de migration durante a verificação: **não**;
- criação de secret durante a verificação: **não**;
- criação de Edge Function durante a verificação: **não**.

## Observação técnica

A conexão já existe na configuração da plataforma Lovable. O agente informou que o scaffold do projeto ainda não possui arquivos locais de integração como `supabase/config.toml`, `.env` de frontend e `src/integrations/supabase`. Esses arquivos somente poderão ser criados em etapa BUILD autorizada e devem apontar exclusivamente para o HML, usando apenas credenciais públicas apropriadas ao navegador.

## Governança

- PROD permanece proibido.
- Não provisionar Lovable Cloud/backend paralelo.
- Não criar schema, tabela, migration, RLS, RPC, Edge Function ou Storage por conveniência do frontend.
- Qualquer necessidade real de backend deve ser registrada como `LACUNA DE BACKEND` e tratada em tarefa separada.

## Veredito

**CONEXÃO SUPABASE HML: PASS**

O PROMPT 00 pode prosseguir para a aprovação do plano interno e, depois, para o BUILD constitucional, desde que permaneça sem alteração de banco ou design.