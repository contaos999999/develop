# ContaOS 4.1 — Evidência de RLS e revisão das seis RPCs privilegiadas

Data da inspeção: 03/11/2026. Ambiente **exclusivo HML**: `gklhhhyosgasnyoxlrui`. Método: consultas de catálogo e leitura de definições SQL; **nenhuma alteração de schema, dados, funções, roles, Auth ou PROD**.

## Estrutura de acesso atual

| Verificação | Evidência observada | Limite |
| --- | --- | --- |
| Tabelas públicas | **117** | Presença de objeto não demonstra regra funcional |
| RLS habilitada | **117/117** | RLS ativada não prova isolamento efetivo |
| Policies declaradas | **183**, em todas as tabelas | Não é aprovação individual de cada condição USING/WITH CHECK |
| Tabelas sem policy | **0** | Não demonstra grants mínimos |
| Bucket `contaos-documentos` | Privado | Assinatura/expiração/download exigem teste de sessão |
| Execução `SECURITY DEFINER` para `anon` | **0** das seis RPCs sinalizadas | `authenticated` exige verificação contextual por contrato e perfil |

## Revisão das funções privilegiadas sob alerta do Security Advisor

1. `public.adicionar_versao_documento_competencia_v115`: wrapper chama `privado.adicionar_versao_documento_competencia_v115`. Implementação privada verifica `auth.uid()`, `privado.sessao_usuario_ativa()`, acesso ao contrato e perfil autorizado; inclui idempotência, validação de arquivo e nova versão.
2. `public.criar_documento_competencia_v115`: wrapper chama `privado.criar_documento_competencia_v115`; verifica sessão, acesso ao contrato, perfil e idempotência; valida requisito documental e arquivo.
3. `public.obter_analise_competencia_v116`: autenticação e acesso ao contrato verificadas na função pública, além de lista explícita de perfis; erros de acesso são `42501`.
4. `public.obter_detalhe_requisito_v117`: verifica `auth.uid()`, acesso ao contrato, perfil e vínculo composto requisito/competência/contrato/organização; paginações limitadas.
5. `public.obter_documentos_competencia_v115`: wrapper chama helper privado que valida sessão ativa e acesso ao contrato, e separa acesso de leitura/escrita por perfil.
6. `public.obter_visao_geral_competencia`: wrapper chama helper privado que valida usuário e acesso ao contrato e define possibilidades de ação por perfil.

Todas as seis negam `anon` e configuram `search_path`. Esses achados são baseados nas definições do banco, **não em um teste negativo executado como outro usuário**. Não há fundamento para revogar automaticamente EXECUTE nem para declarar que o aviso é falso-positivo em todos os cenários. O Security Advisor continua com seis WARN.

## Pontos obrigatórios para fechamento

- Executar ensaios **A/B com dois titulares de organizações diferentes**, demonstrando acesso autorizado, acesso negado, erro sanitizado e ausência de vazamento cruzado nas seis RPCs.
- Validar negativa com sessão revogada, vínculo inativo, contrato ausente e perfil insuficiente, conforme contrato de cada função.
- Executar caso positivo e negativo de criação de documentos e versão com dados de teste controlados, sem efeitos externos inesperados.
- Revalidar `get_advisors(security)` e documentar decisão sobre as seis advertências, sem enfraquecer permissões.
- Configuração de proteção de senhas comprometidas do Supabase Auth permanece desativada e exige intervenção no painel do provedor; não é corrigível apenas com SQL read-only.

Fontes: observação direta do catálogo `pg_class`/`pg_policies`/`pg_proc` com `pg_get_functiondef`, inspeção da implementação em schema `privado` e Security Advisor de 03/11/2026. Consulta orientativa: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable e https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

**Conclusão:** configuração estrutural PASS no recorte verificado; segurança funcional RLS/RPC real **PENDENTE**. PROD intocado.
