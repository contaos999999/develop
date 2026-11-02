# Evidência — PROMPT 00 TEST — ContaOS HML

Data: 02/11/2026, Horário de Brasília
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Supabase HML: `gklhhhyosgasnyoxlrui`

## Resultado

Teste executado em modo somente leitura, sem alteração de código ou banco.

- Project Instructions contêm backend Supabase próprio: **PASS**.
- `AGENTS.md` existe no projeto Lovable: **PASS**.
- Nenhuma tabela/migration criada: **PASS**. Não existe pasta `supabase/migrations`; apenas `supabase/config.toml` da conexão.
- Nenhum secret criado: **PASS**. O `.env` local do Lovable contém apenas URL e chave pública/publishable da conexão, sem `service_role`, senha, secret key ou token privado.
- Nenhum backend paralelo habilitado: **PASS**. Lovable Cloud segue desativado; único backend é o Supabase HML oficial.

## Observação sobre arquivos de conexão

A conexão Supabase realizada pela plataforma Lovable criou/configurou localmente arquivos de integração como `supabase/config.toml`, `.env` e `src/integrations/supabase`. Isso não representa criação de schema, migration, RLS, Edge Function, Auth, Storage ou segundo backend.

O `.env` não será versionado no GitHub. Credenciais, mesmo publicáveis, não devem ser copiadas para evidências textuais além da identificação do project ref HML.

## Decisão

**PROMPT 00: PASS integral.**

O próximo passo não é executar os prompts de fundação/backend 01 em diante de forma cega, pois o backend HML 4.1 já está certificado. Deve-se localizar o primeiro prompt de frontend aplicável e consumir exclusivamente o backend existente, conforme `12_PROMPTS_PROTOCOLO_IMPLEMENTACAO_4_1.md` e as premissas de implementação Lovable.
