# ContaOS 4.1 — Especificação Canônica do Frontend Lovable

Consolidação do `FE_v4_Manual_Integral_Lovable_Supabase.docx`. O frontend ainda deve ser construído sobre o backend HML certificado; ele não deve reconstruir regras já implementadas no Supabase.

## 1. Princípio de frontend

Lovable/React/TypeScript é camada de experiência. Segurança e autoridade de negócio permanecem no backend.

Frontend deve:
- consumir Supabase HML;
- respeitar RLS;
- chamar RPCs/Edge Functions existentes;
- exibir rótulos/status oficiais retornados;
- fornecer feedback de carregamento/erro/sucesso em PT-BR;
- manter acessibilidade e responsividade;
- não duplicar regra crítica no cliente.

## 2. Telas de sistema/administração

- SYS-01 Login
- SYS-02 Esqueci a senha
- SYS-03 Redefinir senha
- SYS-04 Selecionar organização
- SYS-05 Dashboard
- ADM-01 Usuários e vínculos

## 3. Telas ContaOS 1.0

- V1-01 Contratantes
- V1-02 Novo contratante
- V1-03 Editar contratante
- V1-04 Contratos
- V1-05 Novo contrato
- V1-06 Contrato — visão geral
- V1-07 Contrato — base normativa
- V1-08 Contrato — orçamento
- V1-09 Contrato — listas/regras
- V1-10 Central de documentos
- V1-11 Detalhe/versões de documento
- V1-12 Competências
- V1-13 Nova competência
- V1-14 Competência — visão geral
- V1-15 Competência — documentos
- V1-16 Competência — análise
- V1-17 Requisito — detalhe/evidências
- V1-18 Parecer interno
- V1-19 Wizard de apresentação
- V1-20 Apresentação/protocolo
- V1-21 Histórico do contrato
- V1-22 Ingestão de histórico
- V1-23 Trilha de auditoria

## 4. Telas ContaOS 2.0

- V2-01 Diligências
- V2-02 Ciclo de diligência
- V2-03 Apontamento — detalhe
- V2-04 Plano de ação
- V2-05 Contestação
- V2-06 Wizard de reapresentação
- V2-07 Pareceres do contratante
- V2-08 Linha do tempo externa

## 5. Telas ContaOS 3.0

- V3-01 Dashboard financeiro
- V3-02 Importações financeiras
- V3-03 Nova importação
- V3-04 Transações
- V3-05 Conciliações
- V3-06 Alertas preventivos
- V3-07 Fornecedores
- V3-08 Orçamento vivo

## 6. Telas ContaOS 4.0

- V4-01 Inteligência histórica
- V4-02 Precedente — detalhe
- V4-03 Regras candidatas
- V4-04 Alertas transversais
- V4-05 Perfil do contratante
- V4-06 Mapa de conhecimento
- V4-07 Risco histórico
- V4-08 Copiloto do contrato

## 7. Telas ContaOS 5.0

- V5-01 Controles de conformidade
- V5-02 Controle — detalhe/versões
- V5-03 Execuções de controle
- V5-04 Não conformidades
- V5-05 Remediação
- V5-06 Clientes API
- V5-07 Webhooks
- V5-08 Exceções
- V5-09 Mudanças normativas
- V5-10 Riscos corporativos
- V5-11 Portal de evidências
- V5-12 Painel executivo

## 8. Regras de UI para status críticos

A UI **não cria** estado crítico. Ela chama operação protegida e reflete o resultado.

Rótulos oficiais:
- `PODE APRESENTAR AO CONTRATANTE`
- `PODE REAPRESENTAR AO CONTRATANTE`
- `VALIDADA` apenas quando backend confirmar parecer final favorável.

É proibido usar “Apta para apresentação/reapresentação”.

## 9. Autorização

- esconder/desabilitar botão por perfil melhora UX, mas não é segurança;
- toda ação deve continuar bloqueada no backend se perfil não autorizado chamar diretamente;
- não inferir organização por parâmetro livre sem validação;
- respeitar organização/contrato selecionados e RLS.

## 10. Upload/documentos

- upload direto ao Storage com fluxo autorizado;
- não converter bucket em público;
- mostrar progresso/retry para arquivo grande;
- versão nova deve solicitar motivo quando regra exigir;
- exibir histórico de versões, hash/status de processamento quando pertinente;
- não apagar versão anterior pela UI.

## 11. Listas e grandes volumes

- paginação server-side;
- filtros enviados ao backend;
- não carregar milhares de linhas para filtrar no navegador;
- estados de vazio, carregamento e erro;
- preservar query/filtro na navegação quando fizer sentido.

## 12. Formulários

- validação de formato no cliente para UX, sem substituir checks do banco/backend;
- erros amigáveis em PT-BR;
- impedir duplo clique/duplicidade, apoiando-se também em idempotência backend;
- indicar campos obrigatórios;
- tratar conflito de versão/stale update com mensagem clara e recarga segura.

## 13. IA no frontend

- mostrar fonte, página/trecho e nível de confiança quando houver;
- diferenciar sugestão de decisão aprovada;
- exibir conflito/baixa confiança;
- exigir revisão humana nos fluxos materiais;
- nunca apresentar texto gerado como norma sem fonte formal.

## 14. Alertas transversais

Devem aparecer visualmente como alerta histórico de outro contrato, com origem explícita. Não podem parecer uma não conformidade do contrato atual e não podem alterar o percentual de conformidade na UI.

## 15. Acessibilidade e qualidade

Cada tela deve considerar:
- navegação por teclado;
- foco visível;
- labels associados;
- mensagens de erro compreensíveis;
- estados/status não comunicados apenas por cor;
- semântica adequada;
- responsividade;
- feedback de processamento assíncrono.

## 16. Definition of Done do frontend

Para cada tela/fluxo:
- rota e proteção corretas;
- dados reais do HML, sem mock permanente;
- RLS/perfil verificados;
- loading/empty/error/success;
- validação e PT-BR;
- acessibilidade mínima;
- sem secret no bundle;
- sem backend paralelo;
- sem mudança de schema não autorizada;
- teste happy path + negativo;
- vínculo com requisito(s) e tela(s) da matriz;
- Zero-Drift verde.

## 17. Regra canônica de eficiência de créditos Lovable

O desenvolvimento frontend deve minimizar o consumo de créditos do Lovable sem reduzir a qualidade do produto nem a força das evidências.

Aplicação obrigatória:
- usar GitHub diretamente para documentação, diff, commits, rastreabilidade e leitura de arquivos quando não for necessário editar pelo Lovable;
- usar Supabase diretamente para inspeção e provas de backend/RLS/RPC/Edge/logs quando o frontend não for necessário;
- enviar ao Lovable prompts consolidados, objetivos e completos, evitando mensagens fragmentadas;
- inspecionar código e contratos antes do BUILD para reduzir retrabalho;
- não reenviar turno que ainda esteja processando; recuperar o estado primeiro;
- não repetir plano, build, scan ou suíte que continue válida após mudança não relacionada;
- preferir alteração mínima por delta, preservando componentes/helpers certificados;
- executar no Lovable somente o que realmente depende do editor, runtime, preview, integração visual ou testes frontend específicos;
- entre duas soluções 100% conformes e tecnicamente equivalentes, escolher obrigatoriamente a de menor consumo de créditos Lovable.

A economia é subordinada à conformidade: é proibido economizar créditos reduzindo TDD, Teste C, segurança, Zero-Drift, acessibilidade, responsividade, rastreabilidade, cobertura, evidência ou fidelidade ao PRD 4.1.

## 18. Identidade Visual Oficial — ContaOS Brand v1.0 / PROMPT 000

A identidade visual oficial do frontend passa a ser definida pelo pacote **ContaOS Brand v1.0**, sob governança integral do `PROMPT 000 / BRAND-01` em `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md`.

Esta regra **complementa** a especificação de frontend e não a substitui. Permanecem soberanos neste documento e no pacote 4.1:
- UX funcional;
- estrutura de telas;
- navegação e rotas;
- componentes funcionais;
- conteúdo funcional;
- estados e mensagens de negócio;
- acessibilidade;
- responsividade;
- segurança e autorização;
- contratos de dados e comportamento.

Para aplicação da marca:
- reutilizar os assets oficiais, sem redesenhar SVG, símbolo ou proporções;
- integrar a paleta e tipografia ao Design System existente, sem criar sistema paralelo;
- usar tokens existentes sempre que houver equivalência semântica;
- centralizar token de marca apenas quando realmente necessário;
- não espalhar cores hardcoded em componentes;
- preservar Login, Sidebar, Header, navegação mobile, formulários, tabelas, gráficos, filtros, ações e mensagens funcionais;
- validar 1440 / 1280 / 768 / 390 px, dark mode e acessibilidade;
- favicon/PWA/manifest só podem receber alterações visuais/metadados estritamente necessários, sem alterar comportamento funcional.

O BRAND-01 não autoriza nenhuma alteração no Supabase, migrations, RLS, grants, RPCs, Database Functions, Edge Functions, Auth, cliente Supabase, variáveis de ambiente, integrações, regras de negócio, rotas ou permissões.

Em caso de conflito entre estética e esta especificação funcional, **o pacote 4.1 prevalece**.
