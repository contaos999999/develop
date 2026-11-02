# V1-04 / PROMPT 25 — Contratos

Data: 02/11/2026. Ambiente alvo: HML. PROD intocado.

## Fontes canônicas

Este design usa exclusivamente o pacote `ContaOS_Pacote_Mestre_Arquitetura_4_1_Lovable_Supabase_100_PRD_2026-11-01`:

- `06_PROMPTS_COPIAR_COLAR/Manual_Mestre_Prompts_4_1_100_PRD.docx` — PROMPT 25;
- `05_FRONTEND_LOVABLE/FE_v4_Manual_Integral_Lovable_Supabase.docx` — SYS-04 e V1-04;
- `08_REQUISITOS_NAO_FUNCIONAIS/ContaOS_RNF_Escalabilidade_Concorrencia_Performance_v2_0_Supabase.docx`;
- `07_ZERO_DRIFT/ZeroDrift_v2_Lovable_Supabase.docx`;
- backend HML real, apenas para confirmar que as operações citadas existem e estão autorizadas.

Materiais de arquiteturas anteriores não são fonte de requisitos para este prompt.

## Intenção

Construir a tela **V1-04 — Contratos** na rota `/contratos`, usando o cliente Supabase existente e **Data API com RLS**. A tela lista somente linhas que o backend autoriza para a **organização ativa selecionada** e trata explicitamente `loading`, `empty`, `success`, `denied` e `error`.

## Regra canônica multi-organização do pacote 4.1

O SYS-04 do pacote 4.1 determina:

- listar apenas organizações vinculadas ao usuário;
- seleção de organização é preferência de navegação;
- RLS continua sendo a autoridade de autorização;
- trocar organização limpa caches/dados da organização anterior.

Consequência obrigatória para V1-04:

1. se o usuário estiver vinculado somente a uma organização, o contexto dessa organização pode ser usado conforme o mecanismo SYS-04 já existente;
2. se estiver vinculado a duas ou mais organizações, ele pode selecionar qualquer uma das organizações autorizadas;
3. `/contratos` deve carregar somente os contratos autorizados da organização atualmente selecionada;
4. ao trocar da Organização A para a Organização B, os contratos da A devem ser removidos imediatamente do estado/cache visível, a página deve voltar para 1 e uma nova consulta deve carregar a B;
5. ao trocar novamente para A, o processo se repete no sentido inverso;
6. em nenhum momento contratos da organização anterior podem permanecer visíveis como dados atuais durante a transição;
7. a seleção da organização nunca substitui a RLS: dentro da organização selecionada, a policy `usuario_tem_acesso_contrato(id)` ainda decide quais contratos chegam ao usuário.

## Objetivos obrigatórios do pacote 4.1

- rota `/contratos`;
- acesso `autorizado`;
- backend autorizado: Data API com RLS + RPCs específicas somente quando crítico;
- não criar tabela, RPC ou Edge Function nova se o backend necessário já existir;
- nenhuma secret key no frontend;
- RLS permanece autoridade;
- nenhum status crítico é calculado localmente;
- não alterar layout global, auth, cliente Supabase ou outra feature fora do plano;
- responsividade em 1440, 1280, 768 e 390;
- teclado, foco, labels e status acessíveis;
- Teste C separado, sem auto-fix.

## Requisito transversal aplicável

O RNF 4.1 torna **paginação obrigatória** em coleções, com tamanho padrão inicial de **25**, filtros/ordenação executados no servidor e nenhum dataset inteiro retornado por padrão. Para V1-04, portanto, a listagem usará paginação server-side de 25 registros e ordenação determinística no backend.

Não serão adicionados filtros de interface que o PROMPT 25 não exige. Se um filtro vier a ser previsto por prompt posterior, ele será implementado no prompt correspondente.

## Evidência backend HML

`public.contratos` existe e possui:

- RLS habilitada;
- `SELECT` concedido a `authenticated`;
- policy `contratos_select` com `privado.usuario_tem_acesso_contrato(id)`;
- índices de organização/situação/vigência;
- campos adequados à lista, incluindo `numero`, `objeto`, `situacao`, `criticidade`, `inicio`, `fim` e `valor_global`.

A função `privado.usuario_tem_acesso_contrato(id)` exige sessão ativa e vínculo válido. Para vínculo com escopo restrito, exige ainda vínculo ativo do usuário com o contrato.

Teste sintético com `ROLLBACK` no HML confirmou:

- usuário com escopo restrito vê somente o contrato explicitamente autorizado;
- usuário com escopo total vê todos os contratos autorizados de sua organização;
- usuário de outra organização não vê contratos da organização anterior.

Não há lacuna backend para a listagem V1-04. Nenhuma RPC nova é necessária.

## Abordagens consideradas

### 1. Inferir autorização no React pela organização selecionada

Rejeitada. A organização selecionada define o contexto de navegação, mas não substitui a policy RLS por contrato.

### 2. Criar RPC própria de listagem

Rejeitada. O pacote 4.1 autoriza Data API com RLS para V1-04 e o backend HML já cumpre o escopo de leitura por contrato. Criar RPC seria backend paralelo desnecessário.

### 3. Data API paginada + contexto SYS-04 + RLS existente

Escolhida. É a solução mínima, alinhada ao pacote 4.1 e com menor consumo de Lovable. A query inclui `id_organizacao` da organização ativa como contexto, paginação server-side e ordenação determinística. A RLS continua decidindo quais contratos da organização ativa são efetivamente retornados. Nenhuma consulta por linha é necessária.

## Fluxo proposto

1. Reutilizar o mecanismo SYS-04 de sessão e organização já existente, sem alterá-lo.
2. Se não houver sessão real, redirecionar para `/login`; erro técnico de sessão gera estado recuperável, sem logout automático.
3. Se o contexto organizacional estiver ausente, redirecionar para `/selecionar-organizacao`.
4. Confirmar que a organização ativa pertence aos vínculos autorizados do usuário usando o mecanismo oficial já existente; isso serve para validar contexto e distinguir `denied` de `empty`, não para substituir RLS.
5. Executar uma única consulta paginada em `public.contratos`, com `id_organizacao = organização ativa`, sempre sujeita à RLS.
6. Mostrar exatamente as linhas devolvidas pelo backend.
7. Quando `id_organizacao` mudar, cancelar/invalidar a query anterior, zerar página para 1, limpar os dados visíveis da organização anterior e carregar a nova organização em estado `loading`.

## Consulta de lista

Selecionar somente os campos necessários para a listagem:

`id,id_organizacao,numero,objeto,situacao,criticidade,inicio,fim,valor_global`

Paginação:

- página inicial 1;
- 25 registros por página;
- `count: "exact"`;
- `range(from, to)`;
- ordenação `numero ASC`, depois `id ASC` para estabilidade;
- query key inclui obrigatoriamente `id_organizacao` e `pagina`;
- **não usar `placeholderData`/`keepPreviousData` entre organizações diferentes**.

Não selecionar `configuracao_*`, documentos, competências, histórico, orçamento ou outros módulos. Não pré-carregar detalhe por linha.

## Estados

- `loading`: sessão/contexto/lista em carregamento, inclusive troca de organização;
- `empty`: usuário autorizado na organização ativa, mas a RLS devolveu zero contratos para ela;
- `success`: lista paginada da organização ativa recebida;
- `denied`: backend/RLS ou contexto oficial indica ausência de acesso à organização/contratos;
- `error`: falha técnica distinta de permissão.

Erro de permissão nunca aparece como simples lista vazia quando houver evidência backend de `denied`.

## Apresentação mínima

A V1-04 exibirá dados oficiais do contrato já presentes na linha retornada:

- número;
- objeto;
- situação;
- criticidade;
- vigência;
- valor global.

`Situacao` e `criticidade` são apenas apresentados a partir do valor oficial retornado pelo backend; não são recalculados no React.

Não serão implementadas neste prompt as funcionalidades de criação (V1-05), detalhe (V1-06) ou edição de contrato.

## Responsividade

- 1440/1280: lista completa e legível;
- 768: reorganização sem ocultar situação, criticidade, vigência ou valor;
- 390: cards ou layout compacto preservando todos os dados críticos;
- nenhum overflow horizontal da página.

## Acessibilidade

- um H1 `Contratos`;
- nomes/labels acessíveis;
- status expresso por texto, não apenas cor;
- foco visível;
- fluxo principal utilizável por teclado;
- estados de erro e acesso negado com semântica apropriada.

## Testes obrigatórios do PROMPT 25

Teste Oficial C, em turno separado e sem edição:

1. rota abre;
2. perfil autorizado funciona;
3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI;
4. loading/empty/error funcionam;
5. nenhuma request usa secret key;
6. nenhuma ação crítica é update direto;
7. desktop 1440 e 1280 ok;
8. tablet 768 ok;
9. mobile 390 preserva dados críticos;
10. teclado/foco/labels ok;
11. console sem erro e sem log sensível;
12. Security Scan sem novo Critical.

Além dos 12 itens, a regressão do PROMPT 25 deve provar explicitamente o fluxo multi-organização do SYS-04:

- A -> mostra somente contratos autorizados de A;
- A -> B -> contratos de A desaparecem antes/ao entrar no loading e somente contratos de B aparecem após a nova resposta;
- B -> A -> comportamento simétrico;
- página volta para 1 em toda troca;
- nenhuma resposta tardia da organização anterior pode substituir dados da organização atual.

Por governança geral do projeto: regressão completa, typecheck/build frescos, git clean e Zero-Drift devem ser comprovados antes da certificação final.

## Regra canônica de crédito

Entre alternativas igualmente conformes, escolher sempre a que consome menos créditos do Lovable. Isso não pode reduzir fidelidade ao pacote 4.1, segurança, TDD, Teste C, Zero-Drift, rastreabilidade ou qualidade da evidência.
