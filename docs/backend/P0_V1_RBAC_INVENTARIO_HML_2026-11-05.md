# Inventário RBAC HML | P0 V1 | 05/11/2026

> Registro histórico de 05/11/2026. Reconciliado em 06/11/2026 com main@01fa7d7a803ba8507a5ca6d89eb4ce45b2893bea, preservando integralmente docs/tasks/active-task.json da main. As contagens e o impedimento CLI abaixo descrevem aquela coleta, não o estado atual. A main já registra a implantação RBAC e provas posteriores; este merge não as substitui nem certifica V1. Nenhum DDL ou mudança de permissão.

Fonte: consulta read-only ao catálogo PostgreSQL do Supabase HML `gklhhhyosgasnyoxlrui`. PR #56 integrado, CI 42116057685 SUCCESS; RED real P0001 confirmado.

## Contagem de superfície de autorização
- 184 políticas RLS em public e storage, distribuídas em 118 tabelas com políticas.
- 284 funções nos schemas public e privado, sendo 178 SECURITY DEFINER.
- 1 política RLS em storage.
- 0 tabelas RBAC e 0 RPCs RBAC propostas no manifesto #54.

## Evidência amostral de dependências
- public.contratantes INSERT/UPDATE: privado.usuario_possui_perfil(administrador, gestor_contrato); SELECT: privado.usuario_tem_acesso_organizacao.
- public.contratos INSERT: perfil administrador/gestor_contrato; SELECT: privado.usuario_tem_acesso_contrato; UPDATE: escopo de contrato E perfil.
- public.organizacoes SELECT: privado.usuario_tem_acesso_organizacao.
- public.vinculos_usuarios SELECT: próprio usuário OU perfil administrador/auditor.
- Funções privado.usuario_e_administrador_master, privado.usuario_possui_perfil, privado.usuario_tem_acesso_organizacao são SECURITY DEFINER; RPCs públicas de leitura/validação já existentes são INVOKER.

## Decisão de segurança
Não substituir indiscriminadamente 184 políticas. O catálogo novo deve ser inicialmente aditivo e privado; mudanças de enforcement serão por recurso e dependência, com default deny e testes reais. Funções privilegiadas exigem revisão individual. Aprovação especializada permanece independente de MASTER. Sem alteração em produção.

## Impedimento de ferramenta
Supabase CLI não está instalada no ambiente de execução atual (verificação `command -v supabase` sem executável). Portanto **nenhum nome de migration foi inventado** e nenhuma migration criada. A próxima etapa precisa executar `supabase migration new ...` com CLI disponível, verificar arquivo exato, ajustar allowlist BUILD e CI antes de DDL HML. Este inventário NÃO equivale à reconciliação exaustiva das 284 funções/184 políticas.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Backend sem impacto visual; Brand 1.0 e AppShell preservados. Sem consumo Lovable.
