# V1-04 / PROMPT 25 — Lista de contratos

Data: 02/11/2026. Ambiente alvo: HML. PROD intocado.

## Intenção

Construir `/contratos` para listar, de forma paginada e responsiva, somente contratos que o backend Supabase autoriza para o usuário na organização ativa. A tela deve cumprir o contrato canônico V1-04: `FilterBar`, `DataTable`, `StatusBadge`, `Pagination`, `PageHeader`, estados loading/empty/error/success, ações Novo contrato/Abrir contrato, paginação server-side e ausência de N+1.

## Objetivos

- RLS é autoridade de acesso a cada contrato.
- Organização selecionada é somente contexto/filtro, nunca autorização local.
- Paginação ocorre no servidor com `select(..., { count: "exact" })` + `range`.
- Um único request de lista por chave de consulta, sem request por linha.
- Filtros apenas em colunas reais/expostas da Data API: `situacao` e `criticidade`.
- Exibir informações críticas sem buscar detalhe: número, objeto, situação, criticidade, vigência e valor global.
- PT-BR, datas brasileiras e valor em BRL.
- 1440/1280/768/390 sem esconder informação crítica.

## Não objetivos

- Criar contrato (V1-05).
- Implementar detalhe do contrato (V1-06).
- Editar contrato.
- Buscar documentos, competências, orçamento ou histórico por linha.
- Criar RPC ou backend paralelo para listagem.
- Alterar RLS, Auth, Storage, `client.ts`, V1-01/V1-02/V1-03, SYS ou ADM.

## Restrições e evidência backend

`public.contratos` tem RLS ativa e SELECT apenas para `authenticated`. A policy `contratos_select` usa `privado.usuario_tem_acesso_contrato(id)`, que exige sessão ativa e vínculo válido; quando o vínculo não cobre todos os contratos, exige vínculo ativo em `vinculos_usuario_contratos`.

Teste sintético com rollback no HML passou em três cenários:
- vínculo restrito na organização A viu apenas A1;
- vínculo com escopo total na organização A viu A1 e A2;
- usuário da organização B viu apenas B1.

A policy de `vinculos_usuarios` permite ao usuário autenticado ler o próprio vínculo. Isso permite um gate UX único para verificar vínculo ativo e derivar se o CTA Novo contrato pode aparecer; a autorização real da lista continua na RLS de `contratos`.

## Abordagens consideradas

### 1. Inferir contratos pela organização local

Rejeitada. Filtrar somente por `id_organizacao` não prova autorização por contrato e violaria o requisito de não inferir acesso no React.

### 2. Criar uma RPC de listagem

Rejeitada. É desnecessária para um SELECT não crítico: a arquitetura 4.1 manda usar Data API + RLS para CRUD/leitura comum, e a policy já implementa o escopo por contrato.

### 3. Data API paginada + contexto de organização + RLS

Escolhida. A query aplica `id_organizacao` apenas como contexto da organização ativa e filtros `situacao`/`criticidade`; a RLS continua decidindo quais linhas chegam. Usa `count: "exact"`, ordenação determinística e `range`, sem joins nem pré-carregamento de detalhes.

## Fluxo

1. `getUser()` valida sessão; ausência real de sessão -> `/login`; erro técnico -> estado de retry, sem logout automático.
2. Ler preferência de organização; ausência -> `/selecionar-organizacao`.
3. Consultar o próprio vínculo para a organização ativa.
   - vínculo ausente/inativo/fora da vigência -> acesso negado;
   - vínculo válido -> pode listar;
   - perfil administrador/gestor_contrato -> CTA Novo contrato visível;
   - demais perfis -> CTA oculto.
4. Query de lista em `contratos`:
   - `id_organizacao = organização ativa` como contexto;
   - `situacao = filtro` quando diferente de todos;
   - `criticidade = filtro` quando diferente de todas;
   - `order(numero asc).order(id asc)`;
   - `range(from,to)` com 25 por página;
   - `count: exact`.
5. Estados vazios distinguem lista realmente vazia de filtros sem resultado. Erro/403 nunca viram empty.

## Dados exibidos

Campos selecionados: `id,id_organizacao,numero,objeto,situacao,criticidade,inicio,fim,valor_global`.

Não selecionar `configuracao_*`, `versao_registro`, documentos, competências ou detalhes pesados. Não buscar contratante por linha.

## Filtros

- Situação: Todos, Rascunho, Ativo, Suspenso, Encerrado, Cancelado.
- Criticidade: Todas, Baixa, Média, Alta, Crítica.
- Alterar filtro volta à página 1.
- Não haverá busca textual neste prompt, evitando inventar parâmetro não exigido pelo contrato e evitando `.or()` desnecessário.

## Navegação incremental

O contrato canônico exige ações `Novo contrato` e `Abrir contrato`, mas V1-05 e V1-06 serão construídas nos prompts seguintes. A V1-04 deve renderizar links simples para os destinos canônicos `/contratos/novo` e `/contratos/{id}` sem pré-carregar dados. Isso não cria rota fictícia nem consulta antecipada; os destinos passam a funcionar quando V1-05/V1-06 forem implementados.

## Responsividade

- 1440/1280: tabela completa com número, objeto, situação, criticidade, vigência, valor e ação.
- 768: tabela pode manter scroll horizontal controlado ou reorganizar sem esconder dados críticos.
- 390: cards com todos os dados críticos e ação Abrir contrato; filtros empilhados.
- Nenhum overflow da página; somente container de tabela pode ter scroll controlado se necessário.

## Acessibilidade

Um H1 `Contratos`; labels reais para filtros; status com ícone + texto; paginação com nomes acessíveis; foco visível; teclado no fluxo principal; alvo de ação >=44px; estado de erro/negado com semântica apropriada.

## Critérios de sucesso

- somente linhas devolvidas pela Data API/RLS;
- paginação server-side real;
- zero N+1;
- filtros somente em `situacao` e `criticidade`;
- denied != empty;
- quatro larguras validadas;
- regressão, typecheck, build e Security Scan verdes;
- zero drift fora do escopo.
