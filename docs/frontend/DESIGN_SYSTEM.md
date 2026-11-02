# ContaOS — Design System Oficial

**Versão:** 1.1  
**Data:** 02/11/2026  
**Direção visual:** Executive Command Center + Audit Workspace  
**Status:** aprovado para prototipação e implementação  
**Fonte funcional:** PRD 4.1, Premissas 4.1, Arquitetura 4.1, Frontend Lovable 4.1 e Frontend Master Design

## 1. Princípio visual

O ContaOS deve comunicar controle, rastreabilidade e confiança sem sacrificar produtividade. A linguagem visual combina:

- **Executive Command Center** para visão geral, dashboards, risco, alertas, IA e portões críticos;
- **Audit Workspace** para documentos, competências, diligências, conciliações, pareceres, controles e auditoria.

Não existem dois temas. Existe um único sistema visual com níveis diferentes de ênfase.

## 2. Personalidade

O produto deve parecer:
- institucional;
- seguro;
- técnico;
- sofisticado;
- legível em jornadas longas;
- denso sem parecer apertado;
- moderno sem estética de entretenimento.

Evitar:
- neon;
- glassmorphism excessivo;
- gradientes decorativos em massa;
- 3D ornamental;
- cards demais;
- gráfico onde tabela ou resumo textual é mais útil;
- status comunicados apenas por cor.

## 3. Paleta semântica

A implementação deve usar tokens semânticos, não cores soltas em componentes.

### 3.1 Base
- `--color-bg-canvas`: fundo global muito claro, neutro e levemente frio.
- `--color-bg-surface`: superfícies principais brancas.
- `--color-bg-subtle`: superfícies secundárias e agrupamentos.
- `--color-bg-command`: fundo profundo usado apenas em áreas executivas de alta hierarquia.
- `--color-border`: divisórias discretas.
- `--color-border-strong`: borda de foco, seleção e separação crítica.

### 3.2 Texto
- `--color-text-primary`: texto principal de alta leitura.
- `--color-text-secondary`: apoio e metadados.
- `--color-text-muted`: informação terciária.
- `--color-text-inverse`: texto sobre superfícies profundas.

### 3.3 Ação
- `--color-action-primary`: ação principal.
- `--color-action-hover`: estado hover.
- `--color-action-soft`: fundos de seleção e ênfase leve.

### 3.4 Status
- `--color-success`: concluído, liberado, conforme.
- `--color-warning`: atenção, pendente, risco moderado.
- `--color-danger`: bloqueio, crítico, erro material.
- `--color-info`: informação, processamento, contexto.
- `--color-neutral`: estado sem criticidade.

Todo status deve combinar **cor + texto + ícone/forma**.

## 4. Tipografia

Fonte principal: stack sans-serif de alta legibilidade compatível com navegador e Lovable.

Escala recomendada:
- Display executivo: 32/40, peso 650–700.
- H1: 28/36, peso 650–700.
- H2: 22/30, peso 600–650.
- H3: 18/26, peso 600.
- Corpo principal: 14/21.
- Corpo confortável: 15/22.
- Metadado: 12/18.
- Tabela: 13/20.

Números financeiros e indicadores devem usar alinhamento tabular quando disponível.

## 5. Espaçamento

Escala base de 4 px:
- 4, 8, 12, 16, 20, 24, 32, 40, 48.

Regras:
- cards operacionais: 16–20 px de padding;
- cards executivos: 20–24 px;
- seções principais: 24–32 px de separação;
- grids: gap de 16–20 px.

## 6. Bordas, raio e sombra

- Raio pequeno: 6 px para controles densos.
- Raio padrão: 10 px para cards e painéis.
- Raio grande: 14 px para módulos executivos especiais.
- Bordas sempre discretas e úteis à hierarquia.
- Sombras apenas para elevação funcional: dropdown, popover, drawer, modal e card executivo em destaque.

## 7. Shell global

### 7.1 Sidebar
A sidebar é o eixo principal da aplicação.

Deve conter:
- marca ContaOS;
- organização atual;
- navegação por áreas;
- estado visual selecionado inequívoco;
- acesso ao perfil/configuração no rodapé;
- modo recolhido em tablet.

Grupos principais:
- Visão geral;
- Contratos;
- Competências;
- Financeiro;
- Inteligência;
- Conformidade;
- Administração.

Itens aparecem conforme versão/perfil, mas o frontend não substitui autorização backend.

### 7.2 Topbar
Deve conter:
- breadcrumb contextual;
- busca quando aplicável;
- indicador de processamento/alertas quando pertinente;
- organização/contrato atual;
- menu do usuário.

### 7.3 Área de conteúdo
- largura fluida com limite de leitura em formulários;
- dashboards podem ocupar largura total;
- tabelas densas priorizam espaço horizontal;
- cabeçalho da página pode ser sticky quando houver ações críticas.

## 8. Padrões de página

### 8.1 Executive Dashboard
Usar para:
- SYS-05 Dashboard;
- V3-01 Dashboard financeiro;
- V5-12 Painel executivo.

Estrutura:
1. contexto e período;
2. indicadores primários;
3. riscos/prioridades;
4. tendência e distribuição;
5. pendências acionáveis;
6. trilha de evidência quando necessário.

### 8.2 Audit Workspace
Usar para documentos, análise, diligência e controles.

Estrutura:
1. cabeçalho contextual compacto;
2. filtros;
3. tabela/lista principal;
4. painel lateral/drawer para detalhe;
5. ações contextualizadas;
6. histórico/evidência próximo da decisão.

### 8.3 Wizard crítico
Usar para apresentação e reapresentação.

Regras:
- progressão em etapas;
- pré-condições vindas do backend;
- resumo antes da confirmação;
- consequência explícita;
- botão crítico desabilitado durante requisição;
- sucesso final só após confirmação backend.

## 9. Componentes-base

### 9.1 Botões
Variantes:
- primário;
- secundário;
- terciário;
- destrutivo;
- crítico de confirmação.

Todos com estados: default, hover, focus-visible, disabled, loading.

### 9.2 Campos
- label sempre visível;
- ajuda e erro próximos ao campo;
- não usar placeholder como substituto do label;
- validação cliente apenas para UX.

### 9.3 Tabelas
- header legível e persistente quando útil;
- filtros e paginação server-side;
- linhas com ações previsíveis;
- valores financeiros alinhados à direita;
- status com badge textual;
- mobile pode virar cards sem perder valor, prazo, status ou ação principal.

### 9.4 Cards
Três famílias:
- `MetricCard`: indicador e tendência;
- `WorkCard`: bloco operacional;
- `RiskCard`: risco, severidade, origem e próxima ação.

### 9.5 Badges e status
Devem usar texto oficial. Nunca criar sinônimo para estado de domínio.

Rótulos protegidos:
- `PODE APRESENTAR AO CONTRATANTE`;
- `PODE REAPRESENTAR AO CONTRATANTE`;
- `VALIDADA` apenas quando backend confirmar parecer final favorável.

É proibido usar “Apta para apresentação” ou “Apta para reapresentação”.

### 9.6 Drawer
Padrão preferido para:
- detalhe de documento;
- requisito/evidência;
- precedente;
- plano de ação;
- contestação.

Mantém contexto da lista e evita navegação desnecessária.

### 9.7 Modal
Usar apenas quando a ação exige foco total e curta duração.

Ao fechar, devolver foco ao elemento de origem.

### 9.8 Tooltip e ajuda contextual
O componente solicitado pelo produto como “lint” corresponde tecnicamente ao **tooltip**.

Deve ser usado sempre que acrescentar compreensão real ao usuário, principalmente em:
- botões somente com ícone;
- campos de significado, formato ou efeito não óbvio;
- termos técnicos e siglas;
- indicadores, métricas, scores, risco e confiança;
- badges/estados que mereçam contexto adicional;
- ações cuja consequência não seja evidente;
- ícones de evidência, fonte, IA, histórico e auditoria;
- controles desabilitados, quando uma explicação curta for adequada;
- cabeçalhos de coluna técnicos/abreviados.

Regras obrigatórias:
- desktop: abrir em `hover` e em `focus` por teclado;
- tablet/mobile: disponibilizar a mesma ajuda por toque, ícone de informação, popover ou padrão equivalente;
- texto curto, objetivo e em PT-BR;
- usar primitiva acessível, com associação equivalente a `aria-describedby` quando aplicável;
- fechamento previsível, incluindo `Escape` quando permanecer aberto;
- não prender foco;
- evitar clipping e posicionar-se dentro da viewport;
- respeitar `prefers-reduced-motion`;
- ser componente reutilizável do Design System.

Tooltip é complementar e **não substitui** label, indicação de obrigatório, erro, aviso de segurança, status crítico, motivo material de bloqueio, consequência relevante nem fonte/evidência exigida pelo PRD.

Não usar indiscriminadamente em texto autoexplicativo. Nunca colocar secret, token, stack trace, SQL, payload sensível ou PII desnecessária dentro de tooltip.

O componente-base deve possuir teste Playwright para hover, foco por teclado, fechamento por `Escape` quando aplicável, interação em viewport mobile e conteúdo acessível.

## 10. IA e explicabilidade

Toda saída de IA material deve separar visualmente:
- dado objetivo;
- extração;
- inferência;
- recomendação;
- decisão humana.

Quando disponível, exibir:
- fonte;
- documento;
- página/trecho;
- confiança;
- data da execução;
- conflito/baixa confiança;
- ação de abrir evidência.

IA nunca deve parecer norma formal sem fonte.

## 11. Portões críticos

### 11.1 PODE APRESENTAR AO CONTRATANTE
A UI somente exibe o estado retornado pelo backend.

Quando liberado:
- destaque positivo de alta hierarquia;
- texto completo do status;
- contexto de competência e versão;
- CTA de apresentação em área separada das ações comuns.

Quando bloqueado:
- não simular percentual local;
- listar motivos vindos do backend;
- CTA indisponível com explicação.

### 11.2 PODE REAPRESENTAR AO CONTRATANTE
Mesmas regras do portão anterior, vinculadas ao ciclo de diligência vigente.

## 12. Estados obrigatórios

Toda tela deve possuir desenho e comportamento para:
- loading;
- empty;
- success;
- erro recuperável;
- 401/não autenticado;
- 403/acesso negado;
- 409/conflito;
- 419/sessão ou contexto expirado quando aplicável;
- 422/validação;
- processamento assíncrono.

Erros devem ser amigáveis, em PT-BR, sem stack trace, SQL, token ou payload sensível.

## 13. Motion e linguagem cinematográfica

Motion serve para orientação, não decoração.

Permitido:
- entrada sutil de painéis;
- transição de drawer/modal;
- mudança de estado de cards;
- skeleton/loading;
- microfeedback de confirmação;
- transição suave entre contexto executivo e detalhe operacional.

Padrão:
- 120–180 ms para microinterações;
- 180–260 ms para painéis;
- easing suave e previsível;
- respeitar `prefers-reduced-motion`.

Evitar parallax, zoom dramático, partículas, animações em loop ou efeitos que prejudiquem leitura.

## 14. Responsividade

Breakpoints de validação obrigatória:
- 1440 px;
- 1280 px;
- 768 px;
- 390 px.

Regras:
- sidebar recolhível no tablet;
- ações secundárias em menu no mobile;
- status, valor, prazo e ação principal nunca somem;
- tabelas críticas podem virar cards estruturados;
- drawers podem ocupar tela inteira no mobile.

## 15. Acessibilidade

Obrigatório:
- foco visível;
- navegação por teclado;
- heading único por página;
- labels associados;
- status não dependente apenas de cor;
- contraste adequado;
- modal/drawer com foco controlado;
- mensagens de erro associadas ao campo;
- alvos de toque adequados no mobile;
- toda ajuda em tooltip disponível também por teclado e, quando aplicável, por toque.

## 16. Segurança visual e funcional

O design não pode induzir implementação insegura.

Proibido:
- `service_role` no browser;
- segredo em variável pública;
- token próprio fora do Supabase Auth;
- cálculo local de portão crítico;
- update genérico de status crítico;
- botão oculto como única barreira de segurança;
- `dangerouslySetInnerHTML` sem sanitização explicitamente aprovada;
- logging de token, documento ou PII.

## 17. Critério de aceite visual

Uma tela só está pronta quando:
- segue este design system;
- respeita a especificação canônica da tela;
- passa 1440/1280/768/390;
- não apresenta clipping/overlap;
- possui estados loading/empty/error/success;
- teclado/foco funcionam;
- status têm texto e não apenas cor;
- ação crítica reflete backend;
- copy está em PT-BR;
- datas, moeda e horários seguem padrão brasileiro;
- tooltips pertinentes funcionam por hover, foco e toque quando aplicável;
- Playwright cobre happy path e pelo menos um fluxo negativo material.

## 18. Regra de evolução

Mudança global de token, navegação, componente-base ou padrão visual deve ser registrada como decisão de design antes de ser aplicada em lote. O Lovable não pode inventar novo padrão visual para resolver uma tela isolada.

## 19. Regra de precedência

Este Design System governa apresentação e interação, mas não pode sobrepor PRD, Premissas, Arquitetura, matriz 96/96, prompts oficiais ou contratos do backend HML. Em qualquer conflito, prevalece a fonte funcional/técnica superior definida no pacote 4.1.