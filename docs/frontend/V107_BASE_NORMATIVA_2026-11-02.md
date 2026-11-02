# PROMPT 28 / V1-07 — Revisão do PLAN e lacuna de backend HML
Data:02/11/2026. **BUILD NÃO APROVADO; frontend/backend/PROD não alterados.**
Base frontend certificado9c26e97e992ee6db529ba3615f2bd10f8ceefbb8; PROMPT27 C18/18.
Rastreabilidade: https://github.com/contaos9999/develop/issues/24.
Plano Lovable: ab8cd8d49559d57d252501d7bbb6480d944d57ba, mensagemumsg_01m6f1spx9fmssvpgr096akj9p, gateplan--show .lovable/plan.md pendente. CustoPLAN informado1crédito. Não reenviar turno pendente nem aprovar recorte incompleto.

## Revisão contra4.1
Regular28/FEV1-07 /contratos/:id/base-normativa. Atômicos001/V1-CON-001,002/V1-CON-002,004/V1-CON-004,005/V1-CON-005, NFR005 assíncrono,007concorrência,008idempotência,009paginação conforme operações.
O plano propôs somenteleitura e reconheceu que não entregaria featureintegral. Isso não atende autorização do usuário para avançar somente com conformidade integral. Não foi emitido certificado parcial como se completo fosse.

### Desvios do plano corrigíveis com evidência existente
1. NFR005 significa assincronicidade, não PT-BR/formatos; corrigir associação.
2. id_arquivo em versoes_fontes_normativas é nullable: nova versão não exige sempreupload. Não usar essa suposição como lacuna genérica.
3. Download protegido JÁ EXISTE: Edge storage-sign-download, JWTAuthorization, bodyid_arquivo, SELECTarquivos sobRLS, signedURL privada, validade60–3600s, nome sanitizado. Logo ausência de download não é lacuna geral; confirmar compatibilidade/escopo e consumir fluxo existente quando aplicável.
4. Q-T do plano não passa AbortSignal, e truncar5.000 caracteres depois de selecionar texto/metadados inteiros não limita payload no servidor. Corrigircancelamento e definir carregamentosobdemanda compatível comRNF semafirmarlimites inexistentes.
5. Fonteglobal visível na organização não implica aplicabilidade/validação ao contrato. Origem e aprovação precisam continuar objetivas.

## Lacunas reais confirmadas por catálogo/grants/funções HML (somente leitura)
- public.aplicabilidades_fonte: authenticated possui apenasSELECT, semINSERT/UPDATE; aRLS existente éSELECT por acesso ao contrato.
- Não há operação pública específica de criar/aprovar aplicabilidade identificada. Busca pornomes fonte/normativa/aplicabilidade e referências dasfunções públicas/privadas às tabelas encontrou consumidores de contexto/vinculação de regra, não operação de manutenção/aprovação de fontes/aplicabilidades.
- public.vincular_fonte_formal_regra exigeversão já aprovada e, seglobal, aplicabilidade previamente aprovada. Não cria essas aprovações, nem pode ser usada como substituto.
- versoes_fontes_normativas permiteSELECT/INSERT; nãoUPDATE/DELETE. Há camposaprovado_por/em noINSERT, mas expô-los aoReact para simular aprovação material violaria a exigência de RPC/operação autenticada e atorbackend.
- fontes_normativas possui dois triggers com incremento de versão: controlar_versao_registro e tocar_atualizado_em. Antes de edição, o contrato otimista precisa ser provado; não contornar incrementos noReact.
- Triggers consultados de fontes/versões sãocontroledeversão,touch,BOPLA eescopo; nenhuma auditoria material de criação/alteração de fonte encontrada nessa listagem. Provar/corrigir em tarefaespecífica antes de declarar mutações conformes.
- RLS de todas as três tabelas está ativa. Não removernemafrouxar.
- Advisorsecurity: apenasWARNauth_leaked_password_protection preexistente, remediação https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection . SemnovoCritical observado na inspeção; não é substituto deSecurityScanfrontend.
- NenhumDDL, migration, alteração degrant/RLS/Auth/Storage ou dado de negócio foi executado.

## Menor tarefa backend proposta (requer autorização específica antes deDDL)
Objetivo: fechar somente os comandos necessários à base normativaV1-07, consumindo tabelas ehelpers existentes, sembackendparalelo.
1. Elaborar contrato oficial de manutenção da fonte e versão: criação consistente, versãoimutável, vigênciasválidas, hash/origem, auditoria econtroleotimista quandoeditável. ReutilizarDataAPI apenas onde RLS+constraints+auditoria+concorrência comprovarem conformidade; não criarRPC desnecessária.
2. Acrescentar operações autenticadas de aprovação de versão e definição/aprovação de aplicabilidade quando necessárias, com wrapperspúblicosSECURITYINVOKER eimplementação privada protegida, sessão ativa/perfil/escopo real/Master/segregaçãoconforme4.1, ator/data derivados dobackend, auditoria eatomicidade. Não usar INSERT deapproved_por/em noReact.
3. Se duploincremento prejudicar contrato, corrigir somente trigger/function específicos de fontes_normativas; não alterar tocar_atualizado_em global nemmigrationsaplicadas.
4. Não criar tabela ouEdge nova; não alterarAuth/Storage/buckets/clientfrontend/PROD. NenhumaRPClocaldeautoridade noReact.
5. Verificar hash/contexto pós-liberação: mudança material normativa não pode deixar portão antigo válido. Não ampliar este trabalho para outros módulos.
6. TDD RED real antes deDDL; positivos/negativos, same/cross-tenant, semescopo, leitor, perfisautorizados eMaster, versãoobsoleta, replayidempotente/auditoriaúnica, preservação deversões, validadehash/contexto, grantsmínimos eanonnegado. Dados sintéticos comROLLBACK integral, regressão completa pertinente, Advisor, restore limpo se houvermigration, ContextGate/ZeroDrift/ArchitectureGuard eGitHub.
7. Migration corretiva nova comtimestamp oficial viaCLI, nunca reescreverhistórico. Reversão por migrationcompensatória; compatibilidade comfrontendcertificado.
8. Depois debackendcertificado, corrigir PLAN28 comcontratos exatos e executar umBUILDconforme, testes eC18/18. Não desenvolver UI fictícia enquanto caminho material estiversemcontrato.

## Decisão
Parar o caminho deBUILD doPROMPT28. A autonomia autorizada resolve revisão/frontend dentro do pacote, mas não autoriza alteração de backendcertificado: 00/AGENTS/18 exigem tarefa eautorização específicas. Solicitar somente essaautorizaçãoextra; não repetir aprovação dePROMPT27nem deescopofrontendjádelegado.

---

# Atualização de certificação — BUILD Lovable concluído

Data: 02/11/2026. O plano corrigido foi aprovado e o BUILD foi executado exclusivamente no Lovable, sobre o backend HML V107 certificado. PROD permaneceu intocado.

## Frontend entregue

- Repositório: `contaos9999/contaos-hml-control`
- HEAD final no `main`: `3ac193a57efb69e7a9982184a8916c197909dca1`
- Rota pública: `/contratos/:id/base-normativa`
- Arquivo de rota canônico TanStack: `src/routes/contratos_.$id_.base-normativa.tsx`
- Acesso 403/404: classificação `classificar_acesso_contrato_v106` somente após SELECT RLS sem linhas
- Sem pré-carregamento de documentos/competências pesadas; listas sob paginação/carga sob demanda
- Escritas normativas somente pelos quatro RPCs V107; sem DML local de autoridade
- Upload/download reutilizam os Edge Functions certificados; upload resumível encerra com segurança quando o backend sinaliza suporte não implementado

## Verificações finais

- TDD focado V1-07: **62/62 PASS**
- Suíte completa: **361/361 PASS**
- Typecheck: **PASS**
- Build: **PASS**
- Validação responsiva/browser: **PASS** em 1440/1280/768/390
- Teste C separado, read-only: **18/18 PASS**, HEAD estável durante a execução
- Security Scan: **0 Critical / 0 High**; somente aviso informativo preexistente
- Zero-Drift: **PASS**; `src/integrations/supabase/types.ts` não contém `_v107` e preserva `confirmar_upload_arquivo`
- Diferença funcional limitada aos oito arquivos V1-07 previstos; o merge documental BRAND/PROMPT 000 concorrente foi preservado sem alteração

## Rastreabilidade e limites

O backend permanece no head certificado `06d65093746a584efa3b7d9f72bede1ccb38172d`, com Restore Isolado `41538249128`, Zero-Drift `41538249093`, focused 32/32, regressão SQL 18/18, concorrência real 2.573 ms/estado final `Depois:2`, e Advisor 0 Critical/0 High. Nenhuma tabela, migration, RLS, Edge Function, Auth, Storage ou segredo foi criado no frontend. O próximo passo é o próximo prompt canônico; não há ação pendente para PROMPT 28/V1-07.

