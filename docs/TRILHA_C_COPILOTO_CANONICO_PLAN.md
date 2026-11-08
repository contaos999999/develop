# PLAN C-CHAT-001 — Copiloto conversacional e integração contextual

Status: **PLANO DE BUILD, NÃO CERTIFICADO**. Fonte canônica: `10_IA_OCR_RAG_E_PRECEDENTES_4_1.md` §§1,3,6,8; arquitetura e premissas normativas existentes. Backend baseline `ebda39d15e7f7bcb4170b091487b275b56670ac4`; frontend baseline `6c5d4824fc2a7bac61f1031de33ea1aaf1d1d0a1` (confirmar HEAD vivo antes do BUILD).

## Requisito canônico comprovado

O copiloto conversacional é expressamente previsto. Deve responder sobre contratos, obrigações, histórico e competências, usando contexto temporal correto, citações de fonte/página/trecho, distinção entre fato, norma, precedente e inferência, e revisão humana para conflitos/baixa confiança. **Não pode** aprovar, validar competência, liberar apresentação, inventar fonte ou alterar regras silenciosamente. RAG é scope-first por organização/contrato/competência/vigência, antes de similaridade. Falha da IA não derruba transações.

## Contrato de implementação proposto (sujeito a revisão e testes RED)

1. Persistência aditiva em tabelas próprias `copiloto_conversas`, `copiloto_mensagens`, `copiloto_citacoes`, sem modificar migrations certificadas. Chaves de tenant, autor, contexto e auditoria. RLS com políticas específicas de SELECT/INSERT e negação entre tenants; deleção somente sob governança explícita.
2. RPC/Edge de criação de conversa, envio de pergunta, histórico paginado e encerramento. Validar sessão real, organização ativa, vínculo, recurso, competência, contrato e escopo documental. Nunca confiar em organization_id ou contract_id do cliente sem resolver no backend.
3. Recuperação de documentos somente após filtro de tenant, contrato, vigência e permissões. Citações com origem, versão e página/trecho. Ausência de fonte = resposta com limitação, sem inventar.
4. OpenAI exclusivamente no backend, com segredo no ambiente e limites de tokens/custo, timeout, retry controlado, rate limit e registro auditável. Modelo configurável; não congelar identificador de modelo em lógica normativa.
5. Frontend: painel de chat contextual acessível em AppShell e em cada área autorizada, preservando seleção de organização, contraste, foco, teclado e navegação; histórico por conversa. Mudança de tenant limpa cache e cancela requisições pendentes.
6. Ações sugeridas pelo chat são informativas; nenhum DML, aprovação, exclusão ou liberação executado diretamente por resposta da IA. Operações futuras exigem endpoint canônico, RBAC/RLS e confirmação.

## Matriz RED obrigatória

- C01 JWT ausente/expirado/revogado = NEGADO; C02 tenant B lê tenant A = NEGADO; C03 contrato/competência fora do escopo = NEGADO; C04 RAG cross-tenant = NEGADO; C05 fonte sem vigência = não citada como norma vigente.
- C06 prompt injection em documento = sem instrução privilegiada; C07 solicitação de aprovação/liberação via chat = NEGADA; C08 HTML/script na mensagem = escapado; C09 flood/custo = limitado.
- C10 IA indisponível = erro recuperável, núcleo intacto; C11 duas sessões/organizações alternadas = contexto isolado; C12 fonte e página corretas = PASS; C13 histórico/paginação/retention = PASS; C14 mudança de contexto = cancela resposta antiga.
- C15–C41 navegação autenticada das 27 páginas e CTAs, com deep-link/back/refresh, perfis MASTER/comum, screenshots e SHA256, sem alterar provas A/B.

## Gates

Inventário estático → revisão independente do PLAN e impacto em RLS/worker → testes RED → PR de migrations/RPC/Edge aditivas → CI/SQL negativo HML → PR frontend em branch independente → testes unitários/integração → HML Teste C com evidências e cleanup → certificação formal no mesmo HEAD.

**Não usar SKIP como PASS.** Não modificar backend/PROD certificado sem nova prova de impacto. Este arquivo apenas documenta o plano; não autoriza declarar implantação ou certificação.
