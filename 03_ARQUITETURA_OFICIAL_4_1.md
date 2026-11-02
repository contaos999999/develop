# ContaOS 4.1 — Arquitetura Oficial Lovable + Supabase

Consolidação de `ARQUITETURA_4_0_OFICIAL_LOVABLE_SUPABASE.docx`, ajustada ao estado certificado 4.1.

## 1. Decisão arquitetural

- **Frontend:** Lovable, React, TypeScript.
- **Backend oficial e único:** Supabase próprio.
- **Banco:** PostgreSQL do Supabase.
- **Auth:** Supabase Auth.
- **Arquivos:** Supabase Storage privado.
- **API de dados:** Data API somente quando grants + RLS forem suficientes.
- **Comandos críticos:** RPC/Database Function e/ou Edge Function autenticada.
- **Assíncrono:** Supabase Queues/PGMQ + workers/Edge Functions + Cron.
- **Vetores/RAG:** pgvector com filtro de escopo antes da similaridade.
- **IA/OCR:** provedor desacoplado; no HML certificado OpenAI.

Backend paralelo, banco alternativo oculto, lógica crítica apenas no React ou segredo no navegador constituem drift arquitetural.

## 2. Responsabilidade do navegador/frontend

O frontend pode:
- autenticar por fluxos suportados;
- coletar entrada;
- exibir dados autorizados;
- chamar Data API/RPC/Edge;
- iniciar upload direto autorizado para Storage;
- apresentar status retornado pelo backend.

O frontend não pode:
- receber `service_role`/secret key;
- acessar senha de banco;
- armazenar OpenAI API key;
- calcular autoridade de portão;
- atualizar status crítico por `update` genérico;
- burlar RLS;
- tornar bucket público para simplificar implementação;
- criar segunda fonte de verdade.

## 3. Multi-organização

`id_organizacao` é fronteira de tenant. O modelo distingue:
- organização usuária do ContaOS;
- contratante;
- contrato;
- vínculos de usuários/perfis;
- escopo a contratos quando necessário.

RLS precisa ser testada com pelo menos organização A e B. Um usuário autenticado não pode enxergar B apenas por conhecer UUID/URL/ID.

## 4. Camadas de acesso

1. Browser recebe Project URL e publishable key.
2. RLS e grants controlam acesso a dados.
3. CRUD comum pode usar Data API.
4. Ação material usa RPC específica ou Edge Function.
5. Função privilegiada precisa de checagem explícita de usuário/perfil/escopo e auditoria.
6. `SECURITY DEFINER` não é atalho para resolver autorização.
7. Schemas internos/privados não são expostos ao cliente.

## 5. Modelo de dados evolutivo

### Núcleo 1.0
organizações, perfis/vínculos, contratantes, contratos/versões, fontes normativas/versões/aplicabilidades, propostas/versões/linhas, listas/versões/itens, arquivos/documentos/versões/processamento/páginas/fragmentos, competências/requisitos, análises/resultados/evidências, apontamentos internos/correções, parecer interno/aprovações, pacotes/apresentações, histórico e precedentes.

### 2.0
ciclos de diligência, pareceres do contratante, apontamentos, análises, planos/tarefas, contestações, pacotes de reapresentação e desfechos.

### 3.0
fontes/importações/transações financeiras, documentos de transação, fornecedores/contratos de fornecedor, consumo orçamentário, conciliações, alertas preventivos e tratamentos.

### 4.0
relacionamentos de conhecimento, consultas semânticas, similaridades, alertas transversais, pontuações de risco, perfis/padrões históricos, retornos de modelo, regras candidatas, sessões/mensagens/fontes do copiloto.

### 5.0
entidades organizacionais, controles/versões/aplicabilidades/execuções/exceções, não conformidades/remediações, mudanças normativas/impactos/publicações, riscos, clientes API/escopos, webhooks/eventos, pacotes/acessos/exportações de evidência.

## 6. RLS

Toda tabela de negócio em schema exposto deve ter RLS. Políticas devem refletir tenant e escopo real, não apenas `TO authenticated`.

Padrões:
- `SELECT`: usuário pertence à organização e, quando necessário, ao contrato;
- `INSERT`: `id_organizacao`/`id_contrato` precisam pertencer ao escopo autorizado;
- `UPDATE`: `USING` e `WITH CHECK`;
- `DELETE`: restrito e, para histórico crítico, normalmente proibido no fluxo normal;
- tabelas append-only: inserir, consultar e corrigir por novo evento/versão.

## 7. RPCs e operações críticas

Devem ser centralizadas no backend, entre outras:
- aprovar/liberar apresentação;
- registrar protocolo/apresentação;
- liberar reapresentação;
- registrar parecer do contratante;
- validar remediação;
- publicar regra/controle/norma;
- ações que exijam lock/idempotência;
- qualquer mudança de status com efeito material.

## 8. Concorrência e idempotência

- `versao_registro` ou equivalente para edição otimista;
- lock de linha em operações críticas;
- chave idempotente em comandos repetíveis;
- transações atômicas;
- retry não pode duplicar apresentação, job, importação, webhook ou efeito financeiro.

## 9. Storage

- bucket de documentos é privado;
- upload/download por URL assinada/autorização temporária;
- arquivo grande usa estratégia resumível/multipart quando aplicável;
- versão de documento é imutável;
- hash SHA-256, origem, ator e metadados preservados;
- arquivo não precisa atravessar Edge Function para ser transferido;
- processamento começa por fila após upload/registro.

## 10. Filas, Edge e Cron

Workloads pesados/externos são assíncronos. Filas separadas impedem uma carga de IA/OCR de bloquear integrações ou tarefas financeiras. Cada worker deve ter autenticação interna, idempotência, retry, DLQ e observabilidade.

## 11. RAG/pgvector

Fluxo obrigatório:
1. documento seguro e versionado;
2. extração/OCR;
3. fragmentação;
4. metadados de tenant/contratante/contrato/competência/vigência/fonte;
5. embedding assíncrono;
6. filtro obrigatório por escopo antes da similaridade;
7. ranking;
8. resposta com fonte/página/trecho;
9. incerteza ou conflito explícitos;
10. nenhum precedente vira regra impeditiva sozinho.

## 12. Ambientes

- Supabase HML e PROD são projetos distintos.
- Repositório `contaos9999/develop` representa HML homologado.
- Repositório `contaos9999/prod` não recebe desenvolvimento prematuro.
- Promoção é de migrations, Edge Functions, configurações versionáveis e frontend homologado, não de dados fictícios.

## 13. Critério de pronto arquitetural

Uma mudança não está pronta se criar qualquer um destes:
- tabela sem RLS;
- endpoint sem autorização;
- secret no frontend;
- status crítico calculado/local;
- processo pesado síncrono;
- perda de histórico;
- ausência de idempotência em comando repetível;
- falta de teste A/B;
- migration aplicada reescrita;
- divergência entre HML e repositório.
