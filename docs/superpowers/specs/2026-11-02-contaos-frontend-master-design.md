# ContaOS — Frontend Master Design

**Data:** 02/11/2026  
**Status:** proposta para aprovação  
**Escopo:** frontend ContaOS 1.0 a 5.0  
**Base:** PRD Mestre, Arquitetura 4.1, manual frontend Lovable/Supabase, schema/migrations HML e Zero-Drift  
**Direção escolhida:** Executive Command Center + Audit Workspace

---

## 1. Intenção

O frontend do ContaOS deve transmitir três atributos simultaneamente:

1. **controle executivo** sobre contratos, competências, riscos, prazos e conformidade;
2. **produtividade operacional** para jornadas longas de auditoria, documentos, diligências e análise financeira;
3. **rastreabilidade e confiança**, deixando claro o que é dado, evidência, inferência da IA, decisão humana e estado oficial do backend.

O sistema deve parecer uma plataforma corporativa madura para contratos públicos, e não um dashboard genérico de SaaS.

A linguagem visual adotada combina:

- **Executive Command Center** nas áreas de visão geral, direção, indicadores, inteligência, risco, alertas e portões de apresentação;
- **Audit Workspace** nas áreas de trabalho intensivo, como contratos, documentos, competências, diligências, conciliações, pareceres, controles e auditoria.

Essas duas expressões pertencem ao mesmo design system. Não existirão dois temas concorrentes.

---

## 2. Objetivos

### 2.1 Objetivos de produto

- Fazer o usuário entender em poucos segundos qual é o estado atual do contrato ou competência.
- Tornar pendências, bloqueios e riscos visíveis sem depender de interpretação de cor.
- Permitir jornadas densas sem sensação de poluição visual.
- Destacar evidências e fontes sempre que houver IA, análise ou decisão relevante.
- Manter as ações críticas claramente separadas das ações operacionais comuns.
- Tornar os portões `PODE APRESENTAR AO CONTRATANTE` e `PODE REAPRESENTAR AO CONTRATANTE` visualmente inequívocos, sempre refletindo o estado oficial retornado pelo backend.

### 2.2 Objetivos técnicos

- React + TypeScript strict.
- Compatível com o scaffold atual do Lovable/TanStack.
- Cliente Supabase oficial com publishable key apenas.
- Nenhuma regra crítica calculada no frontend.
- Nenhuma alteração direta de estado crítico quando existir RPC/Edge Function oficial.
- Responsividade validada em 1440, 1280, 768 e 390 px.
- Acessibilidade de teclado, foco, labels, status textual e contraste.
- Testes E2E com Playwright para fluxos críticos.

---

## 3. Não objetivos

- Não redesenhar regras de negócio definidas pelo PRD.
- Não criar backend paralelo.
- Não substituir RLS/RPC por ocultação de botão.
- Não transformar o frontend em autoridade de segurança.
- Não adicionar animação decorativa que atrase trabalho operacional.
- Não adotar glassmorphism excessivo, neon, 3D ornamental ou estética de jogo.
- Não usar dashboards cheios de gráficos quando tabela, lista ou resumo textual for mais útil.
- Não esconder valor, prazo, status, risco ou ação principal no mobile.

---

## 4. Abordagens consideradas

### 4.1 Executive Command Center

**Força:** comunicação de controle, prioridade, risco e visão executiva.  
**Risco:** se aplicado a todas as telas, pode ficar pesado e reduzir produtividade.

### 4.2 Audit Workspace

**Força:** excelente para tabelas, documentos, formulários, análise e jornadas longas.  
**Risco:** sozinho pode parecer excessivamente utilitário e pouco diferenciador.

### 4.3 Cinematic Compliance

**Força:** identidade marcante, profundidade visual e impacto.  
**Risco:** efeitos demais poderiam competir com a leitura, a densidade documental e a acessibilidade.

### 4.4 Decisão

Combinar **Executive Command Center + Audit Workspace**, usando princípios cinematográficos apenas como acabamento: composição, profundidade, contraste, transições e foco. O conteúdo operacional permanece legível, sóbrio e rápido.

---

## 5. Personalidade visual

### 5.1 Conceito

**“Sala de controle para auditoria e conformidade.”**

O ContaOS deve parecer seguro, preciso, institucional e contemporâneo. A interface precisa passar confiança suficiente para um diretor, auditor, jurídico ou financeiro tomar decisões, sem parecer fria ou hostil para o usuário operacional.

### 5.2 Superfícies

- Sidebar e áreas de comando: escuras, profundas e estáveis.
- Área principal de trabalho: clara ou levemente tonalizada para favorecer leitura prolongada.
- Cards executivos: maior contraste e hierarquia.
- Tabelas e documentos: fundos simples, bordas discretas, densidade controlada.
- IA/inteligência: identidade própria, porém integrada ao sistema e sem aparência de chatbot separado do produto.

---

## 6. Sistema de cores proposto

A paleta será tokenizada. Valores abaixo são base de design e poderão sofrer ajuste fino de contraste na etapa visual.

### 6.1 Neutros

- `navy-950`: #07111F — sidebar e superfícies executivas profundas
- `navy-900`: #0B1728 — painéis de comando
- `slate-950`: #111827 — texto principal em superfície clara
- `slate-700`: #334155 — texto secundário
- `slate-500`: #64748B — texto auxiliar
- `slate-200`: #E2E8F0 — borda
- `slate-100`: #F1F5F9 — superfície secundária
- `slate-50`: #F8FAFC — fundo de trabalho
- `white`: #FFFFFF — cards e tabelas

### 6.2 Marca e ação

- `brand-700`: #155E75
- `brand-600`: #0E7490
- `brand-500`: #0891B2
- `brand-100`: #CFFAFE

O azul-petróleo/ciano comunica tecnologia e confiança sem reproduzir o azul corporativo genérico de sistemas administrativos.

### 6.3 Semânticas

- Sucesso/conforme: verde com texto + ícone, nunca só cor.
- Atenção/prazo: âmbar.
- Risco alto/bloqueio: vermelho controlado.
- Informação: azul.
- IA/inferência: violeta/ciano em baixa saturação.
- Histórico/arquivado: cinza.

Os status críticos terão texto explícito, ícone e, quando necessário, explicação curta.

---

## 7. Tipografia

### 7.1 Fonte principal

**Inter** ou fonte equivalente já suportada pelo scaffold, priorizando legibilidade e consistência.

### 7.2 Fonte técnica auxiliar

Fonte monoespaçada apenas para:

- hashes;
- IDs;
- correlation IDs;
- códigos de controle;
- chaves técnicas;
- pequenos trechos estruturados.

### 7.3 Escala

- Display executivo: 28–36 px, uso restrito.
- H1 de página: 24–28 px.
- H2/seções: 18–20 px.
- H3/cards: 15–17 px.
- Corpo: 14–16 px.
- Tabelas densas: 13–14 px.
- Metadados: 12–13 px.

Não usar texto abaixo de 12 px em informação funcional.

---

## 8. Densidade e espaçamento

A unidade base será 4 px.

- Espaçamento interno padrão: 16/20/24 px.
- Cards executivos: 20–28 px.
- Tabelas: linhas de 44–52 px no desktop.
- Modo compacto poderá existir para listas/tabelas, mas não será o padrão inicial.
- Máximo de conteúdo principal recomendado: 1600 px em telas muito largas, com colunas responsivas.

A densidade deve parecer profissional, não “arejada demais”.

---

## 9. Arquitetura de navegação

### 9.1 App Shell

Estrutura principal:

1. **Sidebar esquerda** recolhível.
2. **Topbar contextual**.
3. **Breadcrumb/Context Bar** quando necessário.
4. **Main Workspace**.
5. **Painel lateral/drawer** para detalhes secundários sem perder contexto.

### 9.2 Sidebar

Agrupamentos propostos:

- Visão geral
- Contratantes
- Contratos
- Competências
- Documentos
- Diligências
- Financeiro
- Inteligência
- Conformidade
- Administração

Itens aparecem conforme permissão e estágio funcional disponível, sem considerar isso mecanismo de segurança.

### 9.3 Topbar

Elementos:

- organização ativa;
- contexto do contrato quando aplicável;
- busca global/command palette;
- notificações;
- ajuda contextual;
- avatar/perfil/sessão.

Trocar organização deve deixar a mudança de contexto inequívoca e limpar dados/cache da organização anterior.

### 9.4 Navegação contextual de contrato

Dentro de `/contratos/:id`, usar subnavegação consistente:

- Visão geral
- Base normativa
- Orçamento
- Regras/listas
- Documentos
- Competências
- Histórico
- Financeiro
- Inteligência

Somente itens existentes/permitidos na versão funcional serão exibidos.

### 9.5 Navegação contextual de competência

Em `/competencias/:id`, manter cabeçalho persistente com:

- competência;
- contrato;
- status oficial;
- completude oficial;
- pendências críticas;
- última análise;
- acesso rápido às evidências.

Subnavegação:

- Visão geral
- Documentos
- Análise
- Parecer
- Diligências quando existentes
- Apresentações

---

## 10. Shells de tela

### 10.1 Auth Shell

Usado em login, recuperação e redefinição de senha.

- Layout limpo e focado.
- Marca ContaOS com composição mais cinematográfica.
- Nenhum dashboard ilustrativo fake.
- Mensagens de autenticação seguras e amigáveis.

### 10.2 Executive Shell

Usado em:

- dashboard geral;
- painel executivo;
- dashboards financeiros;
- inteligência histórica;
- risco;
- alertas;
- conformidade consolidada.

Características:

- resumo de situação no topo;
- cards de prioridade;
- tendências e exceções;
- chamadas visuais para itens que exigem decisão;
- gráficos somente quando agregam leitura.

### 10.3 Audit Workspace Shell

Usado em:

- documentos;
- competências;
- requisitos;
- análise;
- diligências;
- pareceres;
- transações;
- conciliações;
- controles;
- não conformidades;
- trilha de auditoria.

Características:

- maior densidade;
- filtros persistentes;
- tabela/lista central;
- drawer de detalhe;
- ações em contexto;
- metadados claros;
- evidência acessível sem perder a posição na tela.

### 10.4 Wizard Shell

Usado em apresentação, reapresentação, importação e fluxos multi-etapa.

- etapas visíveis;
- progresso real;
- resumo lateral em desktop;
- validação por etapa;
- nenhuma promessa de conclusão antes da confirmação do backend.

---

## 11. Componentes fundamentais

### 11.1 Componentes de estrutura

- `AppSidebar`
- `Topbar`
- `ContextHeader`
- `PageHeader`
- `Breadcrumbs`
- `SectionTabs`
- `WorkspaceSplit`
- `DetailDrawer`
- `CommandPalette`

### 11.2 Componentes de dados

- `DataTable`
- `FilterBar`
- `SavedView`
- `Pagination`
- `KpiCard`
- `TrendCard`
- `StatusBadge`
- `RiskBadge`
- `DeadlineBadge`
- `ProgressIndicator`
- `Timeline`
- `AuditTrail`

### 11.3 Componentes documentais

- `DocumentCard`
- `DocumentVersionList`
- `ProcessingStatus`
- `EvidenceLink`
- `SourceReference`
- `UploadDropzone`
- `FilePreviewPanel`
- `HashDisplay`

### 11.4 Componentes de IA e explicabilidade

- `AiInsightCard`
- `InferenceBadge`
- `ConfidenceDisplay` quando existir dado oficial de confiança
- `SourcesPanel`
- `EvidenceChain`
- `HumanDecisionBadge`

Regra: IA nunca será apresentada visualmente como fato objetivo sem diferenciação.

### 11.5 Componentes de ação crítica

- `CriticalActionButton`
- `ConfirmationDialog`
- `ConsequenceSummary`
- `GateStatus`
- `ApprovalPanel`

Toda ação crítica deve informar consequência, impedir duplo envio e aguardar resposta do backend.

---

## 12. Portões críticos

### 12.1 PODE APRESENTAR AO CONTRATANTE

O frontend não calcula esse estado.

Quando o backend retornar liberação:

- exibir `GateStatus` em destaque;
- texto integral: **PODE APRESENTAR AO CONTRATANTE**;
- mostrar data/hora oficial;
- mostrar resumo de requisitos conformes;
- permitir abrir evidências e parecer;
- ação de apresentação separada da simples visualização do status.

Quando bloqueado:

- exibir `AINDA NÃO PODE APRESENTAR AO CONTRATANTE`;
- listar bloqueadores oficiais;
- indicar caminho para resolução;
- não sugerir que aprovação humana possa ignorar requisito obrigatório.

### 12.2 PODE REAPRESENTAR AO CONTRATANTE

Mesmo padrão visual e de autoridade de backend.

O bloco deve diferenciar:

- apontamentos recebidos;
- providências executadas;
- evidências anexadas;
- itens ainda pendentes;
- liberação oficial da reapresentação.

---

## 13. Estados obrigatórios

Cada tela ou componente assíncrono deve prever:

- inicial;
- loading;
- skeleton quando apropriado;
- empty;
- success;
- saving;
- processing;
- erro recuperável;
- erro não recuperável;
- 401/não autenticado;
- 403/sem permissão;
- 409/conflito de versão;
- 419/sessão expirada quando aplicável;
- 422/validação;
- rate limit;
- backend temporariamente indisponível.

Erro técnico nunca expõe stack trace, SQL, token ou segredo.

---

## 14. Formulários

- Labels sempre visíveis.
- Placeholder não substitui label.
- Erro junto ao campo.
- Ajuda curta para regras não óbvias.
- Auto-save somente em cenários aprovados e não críticos.
- Botão principal com verbo específico: `Salvar contrato`, `Enviar para análise`, `Registrar apresentação`.
- Desabilitar durante requisição quando houver risco de duplicidade.
- Confirmação para ações irreversíveis ou de alto impacto.

---

## 15. Tabelas e listas

### Desktop

- cabeçalho fixo em listas longas;
- ordenação apenas quando suportada pelo backend;
- filtros server-side quando relevantes;
- ações secundárias em menu contextual;
- coluna de status textual;
- prazos e valores nunca escondidos.

### Tablet

- colunas menos prioritárias podem migrar para detalhe expansível;
- navegação recolhível.

### Mobile

- tabela pode virar cards;
- preservar status, valor, prazo e ação principal;
- detalhes adicionais em expansão/drawer.

---

## 16. Motion e linguagem cinematográfica

Motion deve orientar atenção, não decorar.

### 16.1 Tempos

- feedback de botão: 80–120 ms;
- hover/focus: 120–160 ms;
- drawer/modal: 180–240 ms;
- transição de contexto: 200–280 ms;
- destaque de mudança de estado: até 320 ms.

### 16.2 Regras

- preferir opacity + transform leves;
- evitar paralaxe em workspace operacional;
- evitar animação contínua;
- skeletons sutis;
- respeitar `prefers-reduced-motion`;
- portões críticos podem usar uma transição de confirmação discreta, nunca celebração exagerada.

---

## 17. Acessibilidade

- WCAG 2.2 AA como meta prática.
- Navegação por teclado no fluxo principal.
- Focus ring sempre visível.
- Contraste mínimo validado.
- Ícone nunca substitui texto em status relevante.
- Modais/drawers com foco contido e retorno de foco.
- Toasts não carregam informação exclusiva.
- Gráficos precisam de alternativa textual/resumo.
- Tabelas precisam de cabeçalhos semânticos.
- Inputs com `label`, `aria-describedby` quando necessário e mensagens de erro associadas.

---

## 18. Responsividade

Breakpoints de validação obrigatória:

- 1440 px
- 1280 px
- 768 px
- 390 px

### Regra de preservação

Em nenhum breakpoint podem desaparecer:

- status;
- valor crítico;
- prazo;
- risco;
- ação principal;
- fonte/evidência quando necessária para explicabilidade.

---

## 19. Busca e Command Palette

A busca global deve permitir, conforme permissões:

- contratos;
- competências;
- documentos;
- diligências;
- precedentes;
- controles;
- não conformidades.

A Command Palette poderá expor atalhos seguros de navegação e ações não críticas. Ações críticas não serão executadas instantaneamente pela palette sem confirmação/contexto.

---

## 20. Dashboards

Dashboard não será coleção de cards decorativos.

Prioridades:

1. o que exige ação agora;
2. o que está bloqueando apresentação/reapresentação;
3. prazos próximos;
4. risco e não conformidade;
5. contratos/competências em andamento;
6. tendências relevantes.

Gráficos devem responder a uma pergunta concreta. Caso contrário, usar lista, ranking ou tabela.

---

## 21. Inteligência e IA

Telas V4 devem ter padrão próprio de explicabilidade:

- pergunta/insight;
- resposta;
- fontes;
- evidências;
- data de referência;
- distinção entre histórico e norma vigente;
- possibilidade de abrir o documento de origem;
- indicação de decisão humana quando houver promoção/aprovação de precedente/regra.

O design deve reduzir a chance de o usuário confundir uma inferência com uma obrigação normativa.

---

## 22. Financeiro

O módulo financeiro deve priorizar:

- valores com formatação pt-BR;
- competência/período claros;
- conciliação visual entre origem e destino;
- divergências explícitas;
- alertas com causa e evidência;
- importações com progresso e resultado de processamento.

Nenhum cálculo financeiro crítico será refeito apenas no browser para substituir o valor oficial do backend.

---

## 23. Conformidade

Os controles e não conformidades devem ter linguagem operacional:

- controle aplicável;
- execução;
- resultado;
- evidência;
- responsável;
- prazo;
- remediação;
- validação;
- encerramento.

A interface deve permitir entender a cadeia causal sem abrir múltiplas telas desnecessariamente.

---

## 24. Segurança refletida na UX

- Nunca persistir segredo no frontend.
- Nunca exibir token interno.
- Não guardar credenciais em localStorage.
- Não usar service role no browser.
- Acesso negado deve ser tratado explicitamente.
- Alteração concorrente deve gerar conflito compreensível, não sobrescrita silenciosa.
- Download/upload deve mostrar estado real do backend.
- A interface pode esconder ações sem permissão, mas o backend continua sendo a autoridade.

---

## 25. Testes frontend

### 25.1 Gate técnico

- typecheck PASS;
- lint PASS;
- unit/component tests PASS;
- build PASS;
- sem dependência inesperada;
- sem secrets no bundle.

### 25.2 Playwright

Fluxos E2E prioritários:

1. login e seleção de organização;
2. navegação entre organizações sem vazamento de contexto;
3. contrato → competência → documentos → análise;
4. portão de apresentação bloqueado;
5. portão de apresentação liberado;
6. apresentação;
7. diligência → plano de ação → reapresentação;
8. importação financeira e tratamento de erro;
9. inteligência com abertura de fonte/evidência;
10. controle de conformidade e remediação;
11. 403/RLS em ação proibida;
12. conflito otimista;
13. sessão expirada;
14. responsividade visual nos quatro breakpoints.

### 25.3 Testes visuais

Screenshots de referência em:

- 1440;
- 1280;
- 768;
- 390.

Critérios:

- sem clipping;
- sem overlap;
- status legível;
- ação principal acessível;
- tabelas adaptadas corretamente;
- contraste e foco visíveis.

---

## 26. Estratégia de construção

### Fase A — Fundação visual

- tokens;
- tipografia;
- sidebar/topbar;
- shells;
- botões;
- campos;
- badges;
- tabelas;
- drawers/modais;
- estados globais.

### Fase B — Telas sistêmicas

- login;
- recuperação;
- seleção de organização;
- dashboard;
- administração.

### Fase C — ContaOS 1.0

Construir todo o fluxo de contrato, competência, documento, análise, parecer e apresentação.

### Fase D — ContaOS 2.0

Diligências, planos de ação, contestação e reapresentação.

### Fase E — ContaOS 3.0

Financeiro, importações, transações, conciliações e alertas.

### Fase F — ContaOS 4.0

Inteligência histórica, precedentes, regras candidatas, alertas transversais, perfil e mapa de conhecimento.

### Fase G — ContaOS 5.0

Controles, execuções, não conformidades, remediação, API/webhooks, evidências e painel executivo.

---

## 27. Uso de MagicPath

Antes do Lovable, o MagicPath será usado para validar visualmente:

1. App Shell;
2. Dashboard executivo;
3. Workspace de competência;
4. Central de documentos;
5. Tela de análise;
6. Gate de apresentação;
7. Diligência/reapresentação;
8. Dashboard financeiro;
9. Inteligência histórica;
10. Painel de conformidade.

Essas telas representam os principais padrões que depois se repetem no catálogo completo.

---

## 28. Uso do Lovable

O Lovable entra **depois** da aprovação dos padrões visuais e componentes-base.

Regras de handoff:

- prompts derivados do PRD/manual 4.1;
- nenhum prompt genérico para “melhorar design” sem escopo;
- nenhuma alteração de backend sem tarefa específica;
- nenhuma regra crítica local;
- cada tela deve usar componentes e tokens já aprovados;
- mudanças globais exigem alteração explícita do design system;
- cada lote deve passar por Playwright e gate visual antes do próximo.

---

## 29. Critérios de aceite do design system

O design system só será considerado aprovado quando:

- App Shell estiver consistente em todos os breakpoints;
- Dashboard representar claramente prioridade e risco;
- workspace operacional suportar alta densidade sem confusão;
- portões críticos forem inequívocos;
- IA e evidência forem visualmente distinguíveis;
- estados de erro/empty/loading/403/409 existirem;
- teclado e foco funcionarem;
- componentes principais estiverem documentados;
- Playwright tiver uma base para os fluxos críticos;
- o sistema não conflitar com PRD, backend ou Zero-Drift.

---

## 30. Decisão visual resumida

**ContaOS será uma sala de controle executiva por fora e uma bancada de auditoria por dentro.**

A experiência executiva deve transmitir confiança, prioridade e domínio da situação. A experiência operacional deve permitir trabalhar por horas com documentos, tabelas, evidências e decisões sem fadiga visual.

A sofisticação virá de hierarquia, profundidade, contraste, motion contido e consistência, não de efeitos decorativos.

---

## 31. Itens deixados para a etapa de implementação

- escolha final da biblioteca de ícones já disponível no scaffold;
- confirmação da fonte disponível no bundle;
- implementação de tokens em CSS/Tailwind;
- definição final de componentes equivalentes do ecossistema Lovable;
- detalhes de cache/server state conforme scaffold efetivo;
- Playwright e CI após o frontend existir no repositório;
- ajuste fino de contraste após protótipos renderizados.

Esses itens não alteram a direção visual aprovada e devem seguir os padrões definidos neste documento.
