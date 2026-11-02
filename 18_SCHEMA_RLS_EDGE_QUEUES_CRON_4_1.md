# ContaOS 4.1 — Schema Lógico, RLS, Edge Functions, Queues e Cron

Consolidação de `SCHEMA_LOGICO_1_A_5.md`, `MATRIZ_RLS.md`, `PLANO_EDGE_QUEUES_CRON.md` e do backend certificado.

## 1. Regra de schema

O schema é organizado por módulos funcionais e tenant. Nomes existentes no banco certificado são a referência operacional. Não renomear entidades só para aproximar um documento antigo se a implementação 4.1 já possui equivalente certificado.

## 2. Domínios de dados

### Identidade/tenant
`organizacoes`, perfis/vínculos, escopos por contrato e auditoria.

### Contrato/normativo
contratantes, contratos, versões, fontes normativas, versões/aplicabilidades, propostas, versões e linhas orçamentárias.

### Checklist/auditoria mensal
listas, versões, itens, competências, requisitos, execuções de análise, resultados, evidências, apontamentos internos, ações corretivas, pareceres internos, aprovações, pacotes e apresentações.

### Documentos
arquivos, documentos de contrato/competência, versões, processamento, páginas, fragmentos.

### Histórico
relatórios, apontamentos, respostas, desfechos, precedentes e regras preventivas.

### Diligências
ciclos, pareceres do contratante, apontamentos, análises, planos/tarefas, contestações, reapresentação e desfechos.

### Financeiro
fontes/importações, transações, documentos, fornecedores, contratos de fornecedores, consumo orçamentário, conciliações, alertas e tratamentos.

### Inteligência
relacionamentos, consultas semânticas, similaridades, alertas transversais, risco, padrões/perfis, retornos, regras candidatas, copiloto e fontes de resposta.

### Compliance 5.0
entidades organizacionais, controles/versões/aplicabilidades/execuções/exceções, não conformidades/remediações, alterações normativas/impactos/publicações, riscos, clientes API/escopos, webhooks/eventos, pacotes/acessos/exportações de evidência.

## 3. RLS

Matriz RLS segue princípios:
- nenhum tenant lê outro tenant;
- contrato pode ter escopo adicional;
- perfil controla ações materiais;
- leitura não implica autorização para aprovação;
- `anon` não recebe execução de função privilegiada;
- schemas privados não são concedidos ao cliente;
- testes A/B obrigatórios.

Estado certificado: 117 tabelas públicas + 2 privadas com RLS.

## 4. RPCs/Database Functions

Usadas para regras que precisam de atomicidade/autoridade, como portões, aprovações, reprocessamento, validações, remediação, publicação e registro material. Frontend deve preferir as operações existentes em vez de montar sequências de updates.

## 5. Edge Functions

Duas categorias:
- chamadas de usuário, com JWT/autorização;
- workers internos, com autenticação service-to-service.

Edge não deve devolver stack/secret. Erros para usuário são PT-BR e correlation id pode ser usado para suporte.

## 6. Filas oficiais

A implementação certificada separa workloads de:
- documentos;
- OCR;
- IA;
- embeddings;
- financeiro;
- relatórios;
- integrações;
- webhooks.

Não fundir filas sem avaliação de bulkhead/capacidade.

## 7. Retry/DLQ

Jobs devem ser idempotentes. Após limite de tentativas, falha deve ficar rastreável/DLQ conforme desenho. Não criar loop infinito nem apagar falha para “limpar painel”.

## 8. Cron

Cron dispara tarefas periódicas/consumidores/saúde de acordo com configuração homologada. Alterar frequência pode mudar custo/carga e exige avaliação.

## 9. Storage

Bucket de documentos privado. Browser usa autorização temporária. Workers processam metadados/arquivo conforme escopo. Não tornar público.

## 10. Observabilidade

Preservar logs sanitizados, eventos de auditoria, alertas operacionais, métricas, health checks, correlation id e estado de filas.

## 11. Proibição para frontend

O frontend não cria tabelas/filas/RPCs/Edge Functions apenas porque uma tela precisa de dados. Primeiro deve localizar o mecanismo já certificado. Se houver lacuna real, abrir tarefa de backend separada e reexecutar gates correspondentes.
