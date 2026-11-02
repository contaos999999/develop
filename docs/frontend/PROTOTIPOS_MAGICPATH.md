# ContaOS — Protótipos MagicPath

**Data:** 02/11/2026  
**Projeto MagicPath:** 467916888211595264  
**Direção visual:** Executive Command Center + Audit Workspace  
**Status:** conjunto-base concluído e validado visualmente para referência de implementação

## Projeto

MagicPath: https://www.magicpath.ai/files/467916888211595264

## Protótipos de referência

### 1. Login
- Nome: `ContaOS — Login`
- Component ID: `467916892707889152`
- Revision ID: `467916892707889153`
- Finalidade: referência oficial para autenticação, identidade externa do produto, tipografia, contraste e linguagem institucional.

### 2. Dashboard Executivo
- Nome: `ContaOS — Dashboard Executivo`
- Component ID: `467917212368404480`
- Revision ID: `467917212368404481`
- Finalidade: referência para shell global, sidebar, topbar, cards de métrica, prioridades, risco e visão executiva.

### 3. Visão Geral do Contrato
- Nome: `ContaOS — Visão Geral do Contrato`
- Component ID: `467917393608458240`
- Revision ID: `467917393608458241`
- Finalidade: referência do Audit Workspace, cabeçalho contextual de contrato, abas, tabelas, indicadores operacionais, pendências e atividade recente.

### 4. Análise da Competência
- Nome: `ContaOS — Análise da Competência`
- Component ID: `467917566216667136`
- Revision ID: `467917566216667137`
- Finalidade: referência para requisitos, evidências, análise por IA, decisão humana e portão crítico vindo exclusivamente do backend.

Regras demonstradas:
- IA separada de decisão humana;
- fonte/evidência acessível;
- confiança visível;
- portão não calculado no frontend;
- uso literal de `PODE APRESENTAR AO CONTRATANTE` quando pertinente;
- estados bloqueados com motivo vindo do backend.

### 5. Painel Executivo
- Nome: `ContaOS — Painel Executivo`
- Component ID: `467917742725541888`
- Revision ID: `467917742725541889`
- Finalidade: referência para visão multi-contrato, risco, conformidade, prazos, exceções e prioridades da direção.

## Regras de implementação

O Lovable deve usar estes protótipos como referência visual, sem inferir nova linguagem gráfica. O código final deve continuar obedecendo `docs/frontend/DESIGN_SYSTEM.md`, `06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md` e o Frontend Master Design.

É proibido:
- copiar dados de exemplo dos protótipos como dados permanentes;
- transformar mocks em fonte de verdade;
- criar backend paralelo;
- alterar Supabase, RLS, RPC, Edge Functions ou schema durante a tarefa de frontend sem novo manifesto explícito;
- calcular portões críticos no React;
- substituir texto oficial por sinônimos;
- introduzir novo padrão visual isolado para uma tela.

## Critério de adoção

Antes de implementar uma família de telas no Lovable:
1. identificar qual destes protótipos é sua referência estrutural;
2. reutilizar tokens e componentes do Design System;
3. conectar somente dados reais do HML quando a integração começar;
4. manter estados loading/empty/error/success/403/conflito;
5. validar 1440/1280/768/390;
6. cobrir o fluxo com Playwright quando houver implementação executável.
