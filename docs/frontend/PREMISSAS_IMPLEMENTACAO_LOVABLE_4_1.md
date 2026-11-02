# ContaOS 4.1 — Premissas Vinculantes para Implementação no Lovable

**Data:** 02/11/2026  
**Status:** obrigatório antes de qualquer Build no Lovable  
**Ambiente:** HML  
**Frontend:** Lovable + React + TypeScript  
**Backend único:** Supabase HML certificado

## 1. Regra de autoridade

Toda implementação do frontend deve obedecer, nesta ordem:

1. decisão funcional mais recente e expressamente aprovada pelo responsável do produto;
2. PRD Mestre 4.1;
3. Premissas Funcionais e Técnicas 4.1;
4. Arquitetura Oficial 4.1 Lovable + Supabase;
5. Zero-Drift e governança;
6. matriz oficial dos 96 requisitos e critérios de aceite;
7. schema, migrations, RLS, RPCs, Edge Functions, Storage, Queues, Cron e testes efetivamente certificados no HML;
8. documentação auxiliar e prompts do pacote.

Nenhuma decisão de UX, design, biblioteca, gerador, Lovable ou IA pode reduzir ou reinterpretar regra funcional para facilitar implementação.

## 2. Documentos obrigatórios

Antes de qualquer alteração de implementação, considerar lidos e vinculantes os documentos canônicos `00` a `18` da raiz, inclusive `08A`, `08B`, `08C` e `08D`, além do estado certificado do HML e do certificado técnico do backend.

O mapa do pacote 4.1 determina que a leitura correta combina intenção original do pacote, premissas, arquitetura e estado real certificado do HML. O frontend não deve recriar estruturas antigas nem voltar no tempo quando o backend certificado já possui implementação equivalente ou mais recente.

## 3. Manual Mestre de Prompts

O `Manual_Mestre_Prompts_4_1_100_PRD.docx` é vinculante como protocolo de execução.

Foram confirmados todos os blocos numerados de `PROMPT 00` a `PROMPT 99`, sem lacunas.

Cada capacidade aplicável deve seguir o fluxo previsto no próprio manual:

1. **PLAN MODE**: identificar requisito, tela, backend existente, arquivos, segurança, estados, responsividade, acessibilidade e testes, sem editar;
2. **aprovação do plano**;
3. **BUILD MODE**: implementar apenas o escopo aprovado;
4. **TESTE**: executar os critérios correspondentes e registrar PASS/FAIL;
5. não avançar quando houver FAIL obrigatório;
6. não corrigir automaticamente componente fora do escopo.

Prompts de backend/fundação existentes no manual não autorizam reconstruir o backend. O backend HML já certificado deve ser consumido. Se o frontend revelar uma ausência real, registrar `LACUNA DE BACKEND`, interromper aquele caminho e abrir tarefa de backend separada, com autorização própria.

## 4. Caderno dos 96 Prompts Atômicos

O `Caderno_96_Prompts_Atomicos_PRD_v1_0.docx` é obrigatório e possui exatamente os prompts atômicos `001` a `096`.

Para cada tela/fluxo, antes do Build devem ser identificados todos os IDs atômicos impactados. Um requisito só pode ser considerado atendido com evidência compatível com seu texto literal, incluindo, quando aplicável:

- backend e dados;
- RLS/grants e isolamento;
- UI/fluxo;
- fonte/evidência;
- auditoria;
- idempotência/concorrência;
- Queue/Cron/Edge;
- happy path;
- teste negativo;
- rastreabilidade.

A certificação final exige 84 requisitos funcionais + 12 NFR = 96/96.

## 5. Prompts 90 a 99 como gates finais

Os prompts finais não são opcionais. Eles abrangem auditorias dos requisitos funcionais, NFRs, épicos, telas, relatórios, notificações, LGPD/segurança/segregação, regressão completa, ensaio HML/carga/backup/restauração e certificação GO/NO-GO.

O `PROMPT 99` somente permite GO quando os requisitos explícitos, épicos, telas e gates críticos estiverem em PASS conforme o pacote.

## 6. Frontend não é autoridade de negócio

O React/Lovable pode coletar entrada, exibir dados autorizados, chamar Data API/RPC/Edge Functions, iniciar upload autorizado e apresentar estados oficiais.

É proibido no frontend:

- receber ou expor `service_role`, senha de banco, OpenAI API key, token interno ou outro secret;
- criar backend paralelo;
- calcular autoridade dos portões;
- alterar status crítico por `update` genérico;
- contornar RLS;
- tornar bucket público;
- criar segunda fonte de verdade;
- promover alerta histórico transversal para regra impeditiva;
- usar botão oculto como barreira de segurança.

Operações críticas devem consumir RPC/Database Function/Edge Function já existente e autorizada.

## 7. Estados e rótulos protegidos

A interface deve preservar os textos oficiais retornados pelo backend:

- `PODE APRESENTAR AO CONTRATANTE`;
- `PODE REAPRESENTAR AO CONTRATANTE`;
- `VALIDADA`, somente quando o backend confirmar parecer final favorável.

São proibidas as expressões “Apta para apresentação” e “Apta para reapresentação”.

100% é portão objetivo e não média ponderada. O frontend não recalcula nem simula autoridade de liberação.

## 8. Histórico, temporalidade, fontes e IA

O frontend deve tornar compreensíveis e rastreáveis, quando aplicável:

- origem e versão do documento;
- página e trecho;
- vigência;
- competência e contrato;
- hash/contexto;
- execução de análise;
- método determinístico, semântico ou IA;
- confiança;
- divergência/conflito;
- revisão ou decisão humana.

IA deve aparecer visualmente como assistência, nunca como autoridade normativa ou aprovador.

Precedente do próprio contrato e precedente transversal não podem parecer equivalentes. Resultado exclusivamente transversal deve ser identificado como `ALERTA HISTÓRICO TRANSVERSAL DO CONTRATANTE` e não pode ser apresentado como não conformidade atual.

## 9. Estados obrigatórios de tela

Toda tela deve prever, conforme aplicável:

- loading;
- empty;
- success;
- saving;
- processing;
- erro recuperável;
- acesso negado/403;
- sessão/contexto expirado;
- conflito de versão/stale update;
- validação de entrada;
- retry de operação assíncrona.

Erro de permissão não pode ser apresentado como lista vazia.

## 10. Responsividade e acessibilidade

Validação obrigatória em:

- 1440 px;
- 1280 px;
- 768 px;
- 390 px.

Obrigatório:

- navegação por teclado;
- foco visível;
- heading coerente;
- labels associados;
- status não dependente apenas de cor;
- mensagens de erro vinculadas ao contexto;
- controles com alvos adequados no mobile;
- preservação de valor, prazo, status e ação principal.

## 11. Tooltips e ajuda contextual obrigatória

O componente solicitado pelo produto é denominado **tooltip**. Ele deve ser usado em todo o frontend sempre que acrescentar compreensão real ao usuário, especialmente em:

- botões representados apenas por ícone;
- campos cujo significado, formato ou efeito não seja imediatamente óbvio;
- termos técnicos, siglas e conceitos do domínio;
- indicadores, métricas, scores, risco e confiança;
- badges ou estados cuja interpretação mereça contexto;
- ações com consequência material não evidente;
- ícones de evidência, fonte, IA, histórico e auditoria;
- controles desabilitados, para explicar o motivo quando a explicação curta for adequada;
- cabeçalhos de coluna técnicos ou abreviados;
- informações que ajudem o usuário a entender “o que é”, “para que serve” ou “o que acontecerá”.

### 11.1 Comportamento obrigatório

No desktop, o tooltip deve abrir no **hover** e também no **focus** por teclado. Não pode depender apenas do mouse.

No tablet/mobile, onde hover não existe de forma confiável, a mesma ajuda deve estar acessível por toque em alvo apropriado, ícone de informação, popover ou padrão equivalente.

Deve:

- ter texto curto e objetivo em PT-BR;
- ser associado de modo acessível ao elemento que explica, usando primitiva adequada e semântica equivalente a `aria-describedby` quando aplicável;
- permitir fechamento previsível, inclusive por `Escape` quando permanecer aberto;
- respeitar foco e não prender navegação;
- respeitar `prefers-reduced-motion`;
- ser reutilizável como componente do Design System.

### 11.2 O tooltip não substitui informação obrigatória

Tooltip é ajuda contextual complementar. Ele **não pode substituir**:

- label visível de formulário;
- indicação de campo obrigatório;
- mensagem de erro;
- aviso de segurança;
- status crítico;
- motivo material de bloqueio;
- consequência jurídica/operacional que precise permanecer visível;
- fonte/evidência que o PRD exija explicitamente na tela.

Não usar tooltip indiscriminadamente em textos autoexplicativos, para evitar ruído e fadiga.

Nunca exibir em tooltip secret, token, SQL, stack trace, payload sensível ou PII desnecessária.

### 11.3 Teste de tooltip

O componente-base deve possuir teste automatizado para:

- hover desktop;
- foco por teclado;
- fechamento por `Escape` quando aplicável;
- interação por toque/mobile;
- conteúdo acessível;
- ausência de clipping relevante em viewport estreita.

## 12. Performance e comportamento assíncrono

- grandes coleções usam paginação server-side;
- filtros são enviados ao backend;
- não carregar dataset inteiro para filtrar no browser;
- debounce somente quando apropriado;
- upload/download direto ao Storage por autorização temporária;
- arquivos grandes usam fluxo resumível quando aplicável;
- jobs de OCR/IA/embeddings/relatórios/importações exibem progresso/estado sem prender request web;
- polling não deve ser agressivo;
- stale update deve apresentar conflito amigável, nunca sobrescrever silenciosamente;
- duplo clique deve ser bloqueado na UX sem substituir idempotência do backend.

## 13. Design System

A direção visual aprovada é **Executive Command Center + Audit Workspace**.

O Design System pode melhorar apresentação, hierarquia, densidade, motion e compreensão, mas nunca alterar uma premissa funcional. Em caso de conflito entre estética e PRD, o PRD prevalece.

Tooltips, estados, tabelas, wizards, drawers, badges, IA/evidência e portões devem seguir os padrões oficiais em `docs/frontend/DESIGN_SYSTEM.md`.

## 14. Processo obrigatório por tela

Antes de implementar cada tela:

1. identificar seu código e rota oficiais;
2. localizar o `PROMPT XX` correspondente no Manual Mestre;
3. identificar todos os prompts atômicos/requisitos 96/96 que a tela materializa;
4. confirmar o backend real existente no HML;
5. registrar plano e arquivos autorizados;
6. definir dados, RPC/Edge/Data API e permissões;
7. definir estados e tooltips aplicáveis;
8. definir responsividade e acessibilidade;
9. escrever/definir testes;
10. somente então executar Build.

Depois do Build:

1. happy path;
2. negativo/perfil/RLS quando aplicável;
3. loading/empty/error/processing;
4. acessibilidade;
5. tooltips pertinentes;
6. Playwright E2E;
7. 1440/1280/768/390;
8. scan de secrets/segurança;
9. Zero-Drift;
10. diff e evidência PASS/FAIL.

## 15. Condições de parada

Parar a implementação da capacidade e reportar quando ocorrer:

- backend necessário inexistente;
- divergência entre PRD e backend;
- necessidade de migration/RLS/Auth/Edge/Storage não autorizada;
- tentativa do Lovable de criar backend paralelo;
- conexão com PROD;
- secret no browser;
- cálculo local de portão crítico;
- tentativa de afrouxar autorização/RLS para a UI funcionar;
- FAIL obrigatório do prompt/teste correspondente.

## 16. Regra final

O Lovable executa. O PRD e as premissas governam. O Supabase HML é a autoridade de dados e segurança. O Design System organiza a experiência. Os prompts controlam a sequência. Os testes e o Zero-Drift provam a implementação.

Nenhuma tela será considerada concluída apenas por “estar bonita” ou “funcionar visualmente”. Ela deve estar fiel ao PRD, integrada ao backend certificado, acessível, responsiva, testada e rastreável aos requisitos oficiais.