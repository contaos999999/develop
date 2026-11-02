# PROMPT TRANSVERSAL BRAND-01
## IMPLANTAÇÃO DA IDENTIDADE VISUAL OFICIAL CONTAOS v1.0

### CONTEXTO

Este é o projeto **ContaOS Arquitetura 4.1**.

Arquitetura oficial e imutável:

- Frontend: Lovable / React / TypeScript
- Backend: Supabase próprio
- Ambiente atual: HML
- GitHub: obrigatório para todo código e alteração
- Supabase: única fonte de verdade para dados de negócio
- Zero-Drift: obrigatório
- Idioma da aplicação: Português do Brasil
- Datas e horários: padrão brasileiro, timezone Brasília
- Responsividade obrigatória: 1440 / 1280 / 768 / 390 px

Foi aprovado o pacote oficial de identidade visual:

**ContaOS_Marca_Oficial_v1.0_FINAL.zip**

Este pacote passa a ser a **fonte oficial da identidade visual da marca ContaOS**, porém NÃO substitui o Design System, a arquitetura, o PRD, as premissas, requisitos funcionais ou qualquer outra regra do pacote mestre 4.1.

A implantação da marca é uma alteração EXCLUSIVAMENTE VISUAL.

Nenhuma regra funcional, banco de dados, RLS, autenticação, autorização, RPC, Edge Function, integração, fluxo, status, cálculo, rota ou comportamento de negócio poderá ser alterado.

---

# REGRAS ABSOLUTAS DE ZERO-DRIFT

Antes de qualquer alteração, considere obrigatórias todas as regras constitucionais já existentes no projeto.

Em especial:

1. NÃO criar, excluir ou modificar tabelas do Supabase.

2. NÃO criar ou modificar migrations.

3. NÃO modificar RLS.

4. NÃO alterar grants.

5. NÃO criar RPCs ou Database Functions.

6. NÃO criar ou modificar Edge Functions.

7. NÃO modificar Supabase Auth.

8. NÃO modificar o cliente Supabase existente.

9. NÃO alterar variáveis de ambiente.

10. NÃO inserir secret keys, senhas ou credenciais no frontend.

11. NÃO alterar APIs ou integrações.

12. NÃO alterar rotas.

13. NÃO alterar permissões de usuários.

14. NÃO alterar perfis ou RBAC.

15. NÃO alterar regras de negócio.

16. NÃO alterar estados oficiais do ContaOS.

17. NÃO alterar cálculos.

18. NÃO alterar conteúdo funcional das telas.

19. NÃO alterar estrutura de dados.

20. NÃO alterar componentes que não sejam necessários para aplicação da identidade visual.

21. NÃO criar um Design System paralelo.

22. NÃO substituir componentes existentes por outros apenas por preferência estética.

23. NÃO introduzir bibliotecas visuais desnecessárias.

24. NÃO alterar arquivos fora do plano aprovado.

25. NÃO refatorar código não relacionado à identidade visual.

26. NÃO aproveitar esta tarefa para corrigir ou modificar outras funcionalidades.

27. Se qualquer alteração necessária ultrapassar o escopo visual desta tarefa:

**PARE e reporte como LACUNA ou CONFLITO.**

Não improvise.

---

# FONTE DE VERDADE DA MARCA

O pacote:

**ContaOS_Marca_Oficial_v1.0_FINAL.zip**

é a fonte de verdade para:

- logomarca;
- símbolo;
- favicon;
- ícones PWA;
- versões horizontal e vertical;
- aplicações sobre fundo claro;
- aplicações sobre fundo escuro;
- versões monocromáticas;
- regras de proteção;
- tamanhos mínimos;
- paleta institucional;
- aplicação da marca;
- Manual de Identidade Visual.

O pacote 4.1 continua sendo a fonte de verdade para:

- arquitetura;
- Design System;
- UX;
- componentes;
- layout;
- navegação;
- comportamento;
- responsividade;
- acessibilidade;
- funcionalidades;
- segurança;
- backend;
- banco;
- regras de negócio.

Em caso de conflito:

**o pacote 4.1 prevalece sobre qualquer decisão estética que afete comportamento ou arquitetura.**

---

# PALETA OFICIAL DA MARCA

Usar:

- Navy / Principal: `#0F172A`
- Azul Institucional: `#0EA5E9`
- Teal / Destaque: `#14B8A6`
- Superfície: `#F1F5F9`

IMPORTANTE:

Não criar uma segunda paleta global.

Primeiro analise os tokens existentes no Design System do ContaOS.

Sempre que houver correspondência semântica, reutilize os tokens existentes.

A identidade deverá ser integrada ao Design System existente, e não sobreposta a ele.

Não espalhar cores hardcoded pelos componentes.

Se algum token específico de marca for realmente necessário, centralizá-lo no sistema de tokens existente.

---

# TIPOGRAFIA

A identidade utiliza a família:

**Inter**

Antes de alterar qualquer tipografia:

1. verifique qual fonte o ContaOS atualmente utiliza;
2. verifique se Inter já está disponível;
3. preserve a tipografia oficial existente quando já houver compatibilidade;
4. não introduza uma segunda família tipográfica sem necessidade;
5. não provoque alterações globais de largura, altura ou quebra de layouts apenas para adaptar a logomarca.

A identidade visual deve se adaptar ao ContaOS.

O ContaOS não deve ser reconstruído para se adaptar à logomarca.

---

# ARQUITETURA CONCEITUAL DA MARCA

O símbolo oficial representa:

**Governança + Rastreabilidade + Arquitetura Modular**

A estrutura modular representa a integração entre:

Contrato  
↓  
Evidência  
↓  
Auditoria  
↓  
Financeiro  
↓  
Compliance  
↓  
Inteligência

O espaço negativo central representa:

**a fonte única da verdade do contrato.**

A rastreabilidade foi propositalmente simplificada para preservar leitura em tamanhos reduzidos.

Não redesenhar o símbolo.

Não adicionar elementos.

Não adicionar gradientes diferentes.

Não alterar proporções.

Não deformar.

Não recriar manualmente quando houver SVG oficial disponível.

---

# FASE A — PLAN MODE

**MODO: PLAN.**

### NÃO ALTERE CÓDIGO.
### NÃO ALTERE BANCO.
### NÃO ALTERE ARQUIVOS.

Analise primeiro:

1. estrutura atual do frontend;
2. Design System existente;
3. tokens atuais;
4. layout global;
5. sidebar;
6. header;
7. tela de login;
8. favicon atual;
9. PWA/manifest atual;
10. componentes que atualmente exibem nome ou símbolo do ContaOS;
11. modo claro;
12. modo escuro;
13. responsividade;
14. estrutura da pasta `public`;
15. configuração do `manifest`;
16. metadados HTML;
17. arquivos de tema;
18. documentação frontend;
19. AGENTS.md;
20. regras Zero-Drift existentes.

Depois analise integralmente:

**ContaOS_Marca_Oficial_v1.0_FINAL.zip**

e especialmente:

- Manual de Identidade Visual;
- SVG horizontal;
- SVG vertical;
- símbolo isolado;
- PNG transparente;
- versões fundo claro;
- versões fundo escuro;
- versões monocromáticas;
- favicon 16 px;
- favicon 32 px;
- favicon 48 px;
- favicon.ico;
- PWA 192 px;
- PWA 512 px;
- versões maskable;
- tokens CSS;
- exemplo de manifest;
- README de implementação.

---

## NO PLAN, INFORME EXATAMENTE

### 1. Arquivos atuais que serão alterados

Liste caminho completo.

Exemplo:

`src/...`

`public/...`

Nunca use expressões vagas como:

“arquivos relacionados”.

---

### 2. Arquivos novos que serão adicionados

Liste caminho completo.

---

### 3. Arquivos que NÃO serão alterados

Confirme explicitamente:

- Supabase;
- migrations;
- RLS;
- Edge Functions;
- RPCs;
- autenticação;
- autorização;
- rotas;
- regras de negócio;
- integrações;
- dados.

---

### 4. Mapeamento da marca

Explique onde será utilizada cada versão:

- logo horizontal;
- logo vertical;
- símbolo;
- favicon;
- PWA;
- versão clara;
- versão escura;
- versão monocromática.

---

### 5. Design System

Informe:

- tokens existentes encontrados;
- quais tokens já correspondem à marca;
- quais podem ser reutilizados;
- se algum token adicional é realmente necessário.

Prioridade:

**REUTILIZAR > ESTENDER > CRIAR.**

Nunca criar Design System paralelo.

---

### 6. Pontos de aplicação

Verifique pelo menos:

- Login;
- Sidebar expandida;
- Sidebar recolhida;
- Header, se aplicável;
- Navegação mobile;
- Favicon;
- PWA;
- Manifest;
- Browser metadata;
- telas de loading/boot, se já existirem;
- telas de erro globais, somente se atualmente utilizarem marca;
- documentos ou áreas frontend que exibam logo, somente se já existentes.

---

### 7. Responsividade

Planeje validação em:

- Desktop 1440 px;
- Desktop 1280 px;
- Tablet 768 px;
- Mobile 390 px.

A marca nunca poderá:

- quebrar sidebar;
- deslocar navegação;
- criar scroll horizontal;
- encobrir conteúdo;
- reduzir área funcional crítica;
- alterar hierarquia de informação.

---

### 8. Acessibilidade

Planeje:

- texto alternativo adequado;
- contraste;
- comportamento em dark mode;
- foco, quando a marca for clicável;
- uso correto de SVG;
- evitar informação funcional transmitida apenas por cor.

---

### 9. GitHub

Informe:

- branch atual;
- arquivos que serão versionados;
- estratégia de commit;
- validações antes do commit.

Toda alteração desta tarefa deverá ficar registrada no GitHub.

---

### 10. Riscos

Liste qualquer risco de:

- regressão visual;
- quebra responsiva;
- conflito de tokens;
- favicon inconsistente;
- PWA inconsistente;
- alteração de layout;
- duplicação de assets;
- drift visual;
- drift funcional.

---

# PORTÃO DO PLAN

Ao finalizar o PLAN:

Classifique:

**PLAN: APROVÁVEL**

ou

**PLAN: NÃO APROVÁVEL**

O PLAN somente é APROVÁVEL se:

- nenhuma regra funcional for alterada;
- nenhum backend for tocado;
- nenhuma arquitetura for alterada;
- o Design System existente for preservado;
- os assets oficiais forem reutilizados;
- não houver arquivos fora do escopo;
- não houver biblioteca desnecessária;
- não houver segredo no frontend;
- não houver conflito com Zero-Drift.

Se houver qualquer desvio:

**NÃO CONSTRUA.**

Explique exatamente o desvio.

---

# FASE B — BUILD MODE

Somente após aprovação do PLAN.

**MODO: BUILD.**

Implemente exclusivamente:

**BRAND-01 — Identidade Visual Oficial ContaOS v1.0**

---

## 1. ASSETS

Criar estrutura centralizada, preferencialmente:

`public/brand/`

ou seguir a estrutura já existente se houver padrão oficial equivalente.

Organizar sem duplicação desnecessária.

Sugestão:

`public/brand/logo/`

`public/brand/icons/`

`public/brand/favicon/`

`public/brand/pwa/`

Não recriar arquivos que já existam no pacote oficial.

---

# 2. LOGO PRINCIPAL

Aplicar a versão horizontal oficial onde houver espaço adequado.

Não alterar:

- proporção;
- espaçamento interno;
- cores;
- símbolo;
- tipografia da marca.

---

# 3. SIDEBAR

### Expandida

Utilizar:

**logo horizontal**, desde que respeite a largura disponível.

### Recolhida

Utilizar:

**símbolo isolado**.

Não usar texto comprimido.

Não reduzir a marca a ponto de perder legibilidade.

---

# 4. LOGIN

Utilizar a identidade oficial respeitando o layout já existente.

NÃO redesenhar a tela de login.

NÃO alterar formulário.

NÃO alterar autenticação.

NÃO alterar mensagens.

NÃO alterar regras.

Somente integrar a marca de forma coerente com o Design System existente.

---

# 5. DARK MODE

Em fundo escuro:

usar exclusivamente a versão aprovada para fundo escuro ou versão monocromática apropriada.

Nunca aplicar o logotipo escuro sobre fundo escuro.

---

# 6. FAVICON

Configurar corretamente:

- 16 × 16;
- 32 × 32;
- 48 × 48;
- favicon.ico;
- SVG, se suportado pela estrutura atual.

Garantir que o navegador utilize o asset correto.

Remover referências antigas somente quando comprovadamente substituídas.

---

# 7. PWA

Se o projeto possuir PWA/manifest:

utilizar:

- 192 × 192;
- 512 × 512;
- maskable 192;
- maskable 512.

Preservar toda configuração PWA funcional existente.

NÃO alterar:

- start_url;
- scope;
- comportamento;
- service worker;
- cache;
- permissões;
- funcionalidade.

Alterar somente assets visuais e metadados estritamente necessários à identidade.

---

# 8. METADADOS

Onde aplicável, revisar:

- favicon;
- apple-touch-icon;
- PWA icons;
- theme-color;
- application-name;
- title já existente.

Não alterar SEO ou metadados funcionais fora deste escopo.

---

# 9. TOKENS

Não espalhar:

`#0F172A`

`#0EA5E9`

`#14B8A6`

`#F1F5F9`

diretamente em múltiplos componentes.

Usar os tokens existentes do Design System.

Caso seja necessário criar tokens específicos de marca, criar de forma centralizada e semanticamente nomeada.

Exemplo conceitual:

`--brand-navy`

`--brand-blue`

`--brand-teal`

`--brand-surface`

Somente criar caso não haja token equivalente já existente.

---

# 10. COMPONENTE DE MARCA

Se houver repetição real da marca em vários pontos, criar um componente reutilizável simples, por exemplo:

`ContaOSBrand`

ou seguir o padrão de nomenclatura existente.

Esse componente poderá receber apenas propriedades estritamente visuais, como:

- variant;
- orientation;
- size;
- theme.

Não adicionar lógica de negócio.

Não acessar Supabase.

Não criar estado global.

---

# 11. NÃO ALTERAR O CONTEÚDO DA INTERFACE

Preservar integralmente:

- textos;
- campos;
- formulários;
- tabelas;
- gráficos;
- fluxos;
- menus;
- status;
- permissões;
- ações;
- dados;
- filtros;
- notificações;
- mensagens funcionais.

Esta tarefa é de identidade visual.

---

# 12. DOCUMENTAÇÃO

Atualizar a documentação frontend apenas para registrar:

**Identidade Visual Oficial: ContaOS Brand v1.0**

Registrar:

- versão;
- localização dos assets;
- fonte oficial;
- tokens;
- regras de uso;
- referência ao Manual de Identidade Visual.

Não substituir a documentação 4.1 existente.

Apenas acrescentar a identidade visual como camada oficial.

---

# 13. GITHUB

Toda alteração deve ser versionada.

Commit sugerido:

`feat(brand): aplicar identidade visual oficial ContaOS v1.0`

Antes do commit:

- lint;
- typecheck;
- build;
- testes existentes;
- testes específicos BRAND-01.

Nenhum arquivo não relacionado deve entrar no commit.

---

# FASE C — TESTE

**NÃO ALTERE CÓDIGO DURANTE A FASE DE TESTE.**

Teste:

**BRAND-01 — Identidade Visual Oficial ContaOS v1.0**

Responda individualmente:

**PASS / FAIL**

para cada item.

---

## A. INTEGRIDADE FUNCIONAL

1. Login continua funcionando.

2. Logout continua funcionando.

3. Navegação continua funcionando.

4. Rotas continuam funcionando.

5. Permissões permanecem iguais.

6. Nenhuma regra de negócio foi modificada.

7. Nenhum cálculo foi modificado.

8. Nenhum status oficial foi modificado.

9. Nenhuma integração foi modificada.

10. Supabase não recebeu alteração desta tarefa.

---

# B. SEGURANÇA

11. Nenhum secret foi inserido no frontend.

12. Nenhuma credencial foi adicionada ao repositório.

13. Nenhuma RLS foi alterada.

14. Nenhum RPC foi criado ou alterado.

15. Nenhuma Edge Function foi criada ou alterada.

16. Nenhuma migration foi criada.

17. Nenhuma request nova utiliza credencial privilegiada.

18. Security scan sem novo Critical.

---

# C. MARCA

19. Logo horizontal correta.

20. Logo vertical correta.

21. Símbolo correto.

22. Cores corretas.

23. Proporções corretas.

24. Nenhum SVG foi redesenhado.

25. Nenhuma versão não oficial foi criada.

26. Logo funciona em fundo claro.

27. Logo funciona em fundo escuro.

28. Monocromática funciona quando necessária.

---

# D. FAVICON

29. 16 × 16 legível.

30. 32 × 32 legível.

31. 48 × 48 legível.

32. favicon.ico carregando.

33. Browser não apresenta ícone antigo.

---

# E. PWA

34. 192 × 192 correto.

35. 512 × 512 correto.

36. maskable correto.

37. Manifest válido.

38. Nenhum comportamento PWA foi alterado.

---

# F. RESPONSIVIDADE

39. Desktop 1440 px correto.

40. Desktop 1280 px correto.

41. Tablet 768 px correto.

42. Mobile 390 px correto.

43. Sem overflow horizontal provocado pela marca.

44. Sidebar expandida correta.

45. Sidebar recolhida correta.

46. Navegação mobile correta.

---

# G. DARK MODE

47. Marca legível.

48. Contraste adequado.

49. Nenhum logo escuro sobre fundo escuro.

50. Nenhum fundo forçado incompatível com o Design System.

---

# H. ACESSIBILIDADE

51. SVG/imagens possuem descrição adequada quando necessária.

52. Marca clicável possui nome acessível.

53. Nenhuma informação funcional depende exclusivamente da cor.

54. Contraste adequado.

---

# I. QUALIDADE DE CÓDIGO

55. Build passa.

56. TypeScript passa.

57. Lint passa.

58. Testes existentes passam.

59. Console sem erro.

60. Console sem log sensível.

61. Sem código morto criado pela tarefa.

62. Sem asset duplicado desnecessariamente.

63. Sem hardcode visual espalhado pelos componentes.

---

# J. ZERO-DRIFT

64. Nenhum backend paralelo criado.

65. Nenhuma arquitetura modificada.

66. Nenhuma regra funcional modificada.

67. Nenhuma tela reconstruída desnecessariamente.

68. Nenhum componente fora do escopo alterado.

69. Nenhuma biblioteca desnecessária adicionada.

70. Design System oficial preservado.

71. Marca integrada ao Design System, e não criada como sistema paralelo.

72. Git diff contém somente alterações necessárias ao BRAND-01.

---

# RESULTADO FINAL

Ao terminar, entregue:

## 1. RESULTADO

`BRAND-01: PASS`

ou

`BRAND-01: FAIL`

---

## 2. ARQUIVOS ALTERADOS

Liste um por um com caminho completo.

---

## 3. ARQUIVOS ADICIONADOS

Liste um por um.

---

## 4. BACKEND

Confirme literalmente:

**“Nenhuma alteração de backend foi realizada nesta tarefa.”**

---

## 5. SUPABASE

Confirme literalmente:

**“Nenhuma tabela, migration, RLS, grant, RPC, Database Function ou Edge Function foi criada, removida ou modificada.”**

---

## 6. ZERO-DRIFT

Informe:

`ZERO-DRIFT: PASS`

ou

`ZERO-DRIFT: FAIL`

---

## 7. GITHUB

Informe:

- branch;
- commit;
- arquivos versionados;
- resultado dos checks.

---

## 8. EVIDÊNCIAS VISUAIS

Apresente evidências das seguintes resoluções:

- 1440 px;
- 1280 px;
- 768 px;
- 390 px;

e também:

- Login;
- Sidebar expandida;
- Sidebar recolhida;
- Fundo claro;
- Fundo escuro;
- Favicon;
- PWA.

---

# CRITÉRIO DE APROVAÇÃO FINAL

A implantação somente poderá ser considerada concluída quando:

- todos os testes críticos estiverem PASS;
- build estiver verde;
- TypeScript estiver verde;
- lint estiver verde;
- testes existentes estiverem verdes;
- Security Scan não apresentar novo Critical;
- nenhuma regra funcional tiver sido alterada;
- nenhuma alteração de backend tiver ocorrido;
- Git diff estiver limitado ao escopo;
- identidade estiver consistente em desktop, tablet e mobile;
- favicon estiver legível em 16 × 16;
- PWA estiver válida;
- dark mode estiver correto;
- Zero-Drift estiver PASS.

Se qualquer item crítico falhar:

**NÃO DECLARE A TAREFA CONCLUÍDA.**

Corrija somente se a correção permanecer dentro do escopo BRAND-01.

Se exigir alteração funcional, backend ou arquitetura:

**PARE E REPORTE O DESVIO.**