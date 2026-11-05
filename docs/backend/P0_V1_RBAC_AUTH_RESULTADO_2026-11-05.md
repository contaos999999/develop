# P0 V1: resultado real de Auth, organizações e baseline RBAC
Data: 05/11/2026, Brasília. Projeto HML gklhhhyosgasnyoxlrui. V1 não certificada; V2 bloqueada; PROD intocada.

## Resultado comprovado
**133/133 verificações válidas PASS** com chamadas HTTP reais a Auth e Data API. Doze identidades sintéticas: MASTER global sem vínculo físico, dez perfis existentes e usuário sem vínculo com user_metadata falso de administrador. Tokens foram emitidos por /auth/v1/token e confirmados por /auth/v1/user, não por set_config nem fabricação local de JWT.
- 98 asserts de login, identidade, listagem/RLS de organizações, administração e auditoria, anônimo e JWT inválido.
- 18 asserts de INSERT negado em contratantes e ausência de efeito persistido, em nove identidades sem permissão.
- 2 asserts após revogar vínculo de Contabilidade com o mesmo JWT.
- 1 logout global MASTER HTTP 204; 2 asserts demonstrando que o token antigo é negado e a RLS não retorna organização.
- 12 logouts de cleanup solicitados; consulta SQL independente confirmou zero sessões.

### Matriz administrativa efetivamente testada
| Perfil | Organizações sintéticas visíveis | Administrar usuários A | Auditoria A |
|---|---|---|---|
| MASTER sem vínculo | A e B | Sim | Sim |
| administrador | A | Sim | Sim |
| auditor | A | Não | Sim |
| contabilidade | A | Não | Não |
| direcao_aprovador | A | Não | Não |
| financeiro | A | Não | Não |
| gestor_contrato | A | Não | Não |
| juridico_conformidade | A | Não | Sim |
| leitor | A | Não | Não |
| prestacao_contas | A | Não | Não |
| rh_dp | A | Não | Não |
| sem vínculo, metadata de admin falso | nenhuma | Não | Não |
Todos os perfis comuns receberam negação administrativa e false para Auditoria em B. MASTER sem vínculo confirmou zero linhas em vinculos_usuarios e acesso positivo às duas organizações.

### Matriz nativa de negócio: fonte estrutural consultada, não E2E certificado
| Recurso/ação | Perfis previstos nas políticas atuais |
|---|---|
| Contratantes e contratos: criar/editar | administrador, gestor_contrato; MASTER herda administrador |
| Orçamento: inserir/editar proposta | administrador, gestor_contrato, financeiro, contabilidade |
| Documentos de competência: editar | administrador, gestor_contrato, prestacao_contas, financeiro, contabilidade, rh_dp, juridico_conformidade |
| Documentos contratuais/listas: inserir/editar | administrador, gestor_contrato, prestacao_contas, juridico_conformidade |
| Normativo: inserir/editar | administrador, gestor_contrato, juridico_conformidade |
| Auditoria: consultar | administrador, auditor, juridico_conformidade |
| Parecer interno: inserir | administrador, gestor_contrato, prestacao_contas, auditor, juridico_conformidade |
Leitura permanece condicionada a organização/contrato. Aprovação especializada não é automaticamente concedida ao MASTER. Políticas, grants, RPCs e estados de domínio continuam sendo autoridade. Esta tabela não prova execução positiva de todos os CRUDs.

## Limpeza e estado seguro verificados
O conector exigiu confirmação para a transação de DELETE de contas Auth; ela expirou. Nenhum DELETE dessa transação foi declarado executado.
Alternativa segura executada e verificada:
- 12 contas sintéticas bloqueadas por 100 anos e senhas substituídas por valores aleatórios não retidos;
- 0 sessões Auth dessas contas;
- 0 concessões MASTER ativas;
- 0 vínculos ativos;
- 2 organizações sintéticas inativas;
- 0 contratantes gravados indevidamente.
**Remoção definitiva pendente** de confirmação do conector. Os registros sintéticos permanecem em quarentena, não constituem cleanup de zero linhas. Auditoria foi preservada. Nenhuma conta real foi modificada.
Identificação segura para limpeza posterior: email com prefixo p0rbac-, domínio example.invalid e raw_user_meta_data.scope=P0-V1-RBAC; organizações com razao_social p0rbac-. Antes de excluir, conferir bloqueio e ausência de sessões/vínculos ativos. Não remover eventos históricos para apagar rastreabilidade.

## Limitação de uma tentativa de setup
Uma confirmação SQL de revogação expirou. Dois asserts foram iniciados antes da revogação comprovada e classificados como **INVALIDADOS POR SETUP**, preservando o resultado original (um false e um true). Após UPDATE confirmado, a fase foi repetida com o mesmo JWT e os dois asserts válidos passaram. Os dois inválidos não integram o total de 133 e não foram convertidos para PASS.

## GitHub e metodologia
- PLAN #50: HEAD 8bbaca4466557743aa960eea2615d676f1c2de55; CI 42103701903 SUCCESS; merge 2eea1f137eec33e4b006ca544fa5c9a3856899dc.
- GATE #51: HEAD c25a2d660328a11b72fc1085a14e6ec8d12749df; CI 42103964226 SUCCESS; merge cb62628f797294200fcf137c11a7b5243379e521.
- Probe #52: código e resultado nesta branch. CI do código 4f5c55ca53345d4601e1e6fa772a3030515073c6: 42112254536 SUCCESS. Conferir novo HEAD após adicionar este relatório.
- Python padrão, chamadas HTTP reais, timeout 20s, quatro workers somente para identidades independentes. Fases dependentes executadas separadamente.
- Credenciais, JWT, refresh tokens e IDs/dados reais não foram incluídos no Git ou neste relatório.
- O probe depende de fixture.json, public-key.json e sessions.json locais privados; não executar sem fixture própria e manifesto autorizado. As credenciais desta rodada foram invalidadas, não reutilizar as contas.
- Não houve alteração de schema, RLS, grants, funções, cliente Supabase, types.ts ou produção. Houve criação, revogação e bloqueio de dados sintéticos de teste autorizados.

## O que NÃO foi entregue nesta rodada
**Matriz granular persistente/editável e sua UI ainda não implementadas.** Lacuna registrada na issue backend #53 e frontend #166, com PLAN #50. A matriz acima descreve o baseline nativo e suas provas, não um novo mecanismo RBAC.
Não comprova CRUD positivo completo, contratos A/B autenticados, escopo por contrato, acesso a todas as telas MASTER, upload/worker, WCAG privado, nem certificação integral V1.
Próxima tarefa: manifesto BUILD dedicado com catálogo exato de recursos/ações V1, tabelas/objetos, migração, RLS/RPC por operação, edição exclusiva MASTER, auditoria, concorrência/idempotência e integração ADM-01/sidebar. O manifesto atual autoriza provas, não DDL.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: somente teste e documentação backend, Brand v1.0 e assets preservados. GitHub/Supabase diretos, sem BUILD Lovable, sem serviço pago adicional. Nenhum gate foi dispensado. CI desta branch não certifica novo RBAC ou frontend. V1 permanece NO-GO para certificação integral.

## Evidências individuais válidas
| Nº | Verificação | Resultado | HTTP |
|---:|---|---|---:|
| 1 | master: Auth login real | PASS | 200 |
| 2 | master: identidade confirmada pelo Auth | PASS | 200 |
| 3 | master: lista organizações no escopo | PASS | 200 |
| 4 | master: RLS organizaçoes direta | PASS | 200 |
| 5 | master: administrar org_a | PASS | 200 |
| 6 | master: auditoria org_a | PASS | 200 |
| 7 | master: administrar org_b | PASS | 200 |
| 8 | master: auditoria org_b | PASS | 200 |
| 9 | administrador: Auth login real | PASS | 200 |
| 10 | administrador: identidade confirmada pelo Auth | PASS | 200 |
| 11 | administrador: lista organizações no escopo | PASS | 200 |
| 12 | administrador: RLS organizaçoes direta | PASS | 200 |
| 13 | administrador: administrar org_a | PASS | 200 |
| 14 | administrador: auditoria org_a | PASS | 200 |
| 15 | administrador: administrar org_b | PASS | 403 |
| 16 | administrador: auditoria org_b | PASS | 200 |
| 17 | auditor: Auth login real | PASS | 200 |
| 18 | auditor: identidade confirmada pelo Auth | PASS | 200 |
| 19 | auditor: lista organizações no escopo | PASS | 200 |
| 20 | auditor: RLS organizaçoes direta | PASS | 200 |
| 21 | auditor: administrar org_a | PASS | 403 |
| 22 | auditor: auditoria org_a | PASS | 200 |
| 23 | auditor: administrar org_b | PASS | 403 |
| 24 | auditor: auditoria org_b | PASS | 200 |
| 25 | contabilidade: Auth login real | PASS | 200 |
| 26 | financeiro: Auth login real | PASS | 200 |
| 27 | gestor_contrato: Auth login real | PASS | 200 |
| 28 | direcao_aprovador: Auth login real | PASS | 200 |
| 29 | direcao_aprovador: identidade confirmada pelo Auth | PASS | 200 |
| 30 | gestor_contrato: identidade confirmada pelo Auth | PASS | 200 |
| 31 | contabilidade: identidade confirmada pelo Auth | PASS | 200 |
| 32 | financeiro: identidade confirmada pelo Auth | PASS | 200 |
| 33 | direcao_aprovador: lista organizações no escopo | PASS | 200 |
| 34 | contabilidade: lista organizações no escopo | PASS | 200 |
| 35 | financeiro: lista organizações no escopo | PASS | 200 |
| 36 | gestor_contrato: lista organizações no escopo | PASS | 200 |
| 37 | direcao_aprovador: RLS organizaçoes direta | PASS | 200 |
| 38 | gestor_contrato: RLS organizaçoes direta | PASS | 200 |
| 39 | contabilidade: RLS organizaçoes direta | PASS | 200 |
| 40 | financeiro: RLS organizaçoes direta | PASS | 200 |
| 41 | gestor_contrato: administrar org_a | PASS | 403 |
| 42 | contabilidade: administrar org_a | PASS | 403 |
| 43 | direcao_aprovador: administrar org_a | PASS | 403 |
| 44 | financeiro: administrar org_a | PASS | 403 |
| 45 | direcao_aprovador: auditoria org_a | PASS | 200 |
| 46 | financeiro: auditoria org_a | PASS | 200 |
| 47 | contabilidade: auditoria org_a | PASS | 200 |
| 48 | gestor_contrato: auditoria org_a | PASS | 200 |
| 49 | contabilidade: administrar org_b | PASS | 403 |
| 50 | gestor_contrato: administrar org_b | PASS | 403 |
| 51 | financeiro: administrar org_b | PASS | 403 |
| 52 | direcao_aprovador: administrar org_b | PASS | 403 |
| 53 | direcao_aprovador: auditoria org_b | PASS | 200 |
| 54 | financeiro: auditoria org_b | PASS | 200 |
| 55 | gestor_contrato: auditoria org_b | PASS | 200 |
| 56 | contabilidade: auditoria org_b | PASS | 200 |
| 57 | leitor: Auth login real | PASS | 200 |
| 58 | prestacao_contas: Auth login real | PASS | 200 |
| 59 | juridico_conformidade: Auth login real | PASS | 200 |
| 60 | rh_dp: Auth login real | PASS | 200 |
| 61 | leitor: identidade confirmada pelo Auth | PASS | 200 |
| 62 | rh_dp: identidade confirmada pelo Auth | PASS | 200 |
| 63 | juridico_conformidade: identidade confirmada pelo Auth | PASS | 200 |
| 64 | prestacao_contas: identidade confirmada pelo Auth | PASS | 200 |
| 65 | juridico_conformidade: lista organizações no escopo | PASS | 200 |
| 66 | rh_dp: lista organizações no escopo | PASS | 200 |
| 67 | leitor: lista organizações no escopo | PASS | 200 |
| 68 | prestacao_contas: lista organizações no escopo | PASS | 200 |
| 69 | prestacao_contas: RLS organizaçoes direta | PASS | 200 |
| 70 | rh_dp: RLS organizaçoes direta | PASS | 200 |
| 71 | leitor: RLS organizaçoes direta | PASS | 200 |
| 72 | juridico_conformidade: RLS organizaçoes direta | PASS | 200 |
| 73 | juridico_conformidade: administrar org_a | PASS | 403 |
| 74 | prestacao_contas: administrar org_a | PASS | 403 |
| 75 | rh_dp: administrar org_a | PASS | 403 |
| 76 | leitor: administrar org_a | PASS | 403 |
| 77 | rh_dp: auditoria org_a | PASS | 200 |
| 78 | leitor: auditoria org_a | PASS | 200 |
| 79 | juridico_conformidade: auditoria org_a | PASS | 200 |
| 80 | prestacao_contas: auditoria org_a | PASS | 200 |
| 81 | prestacao_contas: administrar org_b | PASS | 403 |
| 82 | juridico_conformidade: administrar org_b | PASS | 403 |
| 83 | rh_dp: administrar org_b | PASS | 403 |
| 84 | leitor: administrar org_b | PASS | 403 |
| 85 | juridico_conformidade: auditoria org_b | PASS | 200 |
| 86 | leitor: auditoria org_b | PASS | 200 |
| 87 | prestacao_contas: auditoria org_b | PASS | 200 |
| 88 | rh_dp: auditoria org_b | PASS | 200 |
| 89 | sem_vinculo: Auth login real | PASS | 200 |
| 90 | sem_vinculo: identidade confirmada pelo Auth | PASS | 200 |
| 91 | sem_vinculo: lista organizações no escopo | PASS | 200 |
| 92 | sem_vinculo: RLS organizaçoes direta | PASS | 200 |
| 93 | sem_vinculo: administrar org_a | PASS | 403 |
| 94 | sem_vinculo: auditoria org_a | PASS | 200 |
| 95 | sem_vinculo: administrar org_b | PASS | 403 |
| 96 | sem_vinculo: auditoria org_b | PASS | 200 |
| 97 | anônimo: organizações negadas | PASS | 401 |
| 98 | JWT inválido: organizações negadas | PASS | 401 |
| 99 | contabilidade: INSERT contratante negado | PASS | 403 |
| 100 | direcao_aprovador: INSERT contratante negado | PASS | 403 |
| 101 | financeiro: INSERT contratante negado | PASS | 403 |
| 102 | auditor: INSERT contratante negado | PASS | 403 |
| 103 | direcao_aprovador: INSERT negado sem efeito persistido | PASS | 200 |
| 104 | contabilidade: INSERT negado sem efeito persistido | PASS | 200 |
| 105 | financeiro: INSERT negado sem efeito persistido | PASS | 200 |
| 106 | auditor: INSERT negado sem efeito persistido | PASS | 200 |
| 107 | juridico_conformidade: INSERT contratante negado | PASS | 403 |
| 108 | leitor: INSERT contratante negado | PASS | 403 |
| 109 | prestacao_contas: INSERT contratante negado | PASS | 403 |
| 110 | rh_dp: INSERT contratante negado | PASS | 403 |
| 111 | juridico_conformidade: INSERT negado sem efeito persistido | PASS | 200 |
| 112 | leitor: INSERT negado sem efeito persistido | PASS | 200 |
| 113 | prestacao_contas: INSERT negado sem efeito persistido | PASS | 200 |
| 114 | rh_dp: INSERT negado sem efeito persistido | PASS | 200 |
| 115 | sem_vinculo: INSERT contratante negado | PASS | 403 |
| 116 | sem_vinculo: INSERT negado sem efeito persistido | PASS | 200 |
| 117 | Contabilidade: vínculo revogado nega com mesmo JWT | PASS | 200 |
| 118 | Contabilidade: RLS nega após revogação | PASS | 200 |
| 119 | MASTER: logout global para revogar sessão | PASS | 204 |
| 120 | MASTER: sessão revogada nega JWT ainda assinado | PASS | 403 |
| 121 | MASTER: RLS nega após revogar sessão | PASS | 200 |
| 122 | contabilidade: logout solicitado | PASS | 204 |
| 123 | master: logout solicitado | PASS | 403 |
| 124 | auditor: logout solicitado | PASS | 204 |
| 125 | administrador: logout solicitado | PASS | 204 |
| 126 | financeiro: logout solicitado | PASS | 204 |
| 127 | direcao_aprovador: logout solicitado | PASS | 204 |
| 128 | gestor_contrato: logout solicitado | PASS | 204 |
| 129 | leitor: logout solicitado | PASS | 204 |
| 130 | rh_dp: logout solicitado | PASS | 204 |
| 131 | sem_vinculo: logout solicitado | PASS | 204 |
| 132 | juridico_conformidade: logout solicitado | PASS | 204 |
| 133 | prestacao_contas: logout solicitado | PASS | 204 |

## Tentativa de setup preservada e excluída
| Verificação | Resultado original | Classificação |
|---|---|---|
| Contabilidade: vínculo revogado nega com mesmo JWT | false | INVALIDADO POR SETUP, confirmação anterior expirada |
| Contabilidade: RLS nega após revogação | true | INVALIDADO POR SETUP, confirmação anterior expirada |
