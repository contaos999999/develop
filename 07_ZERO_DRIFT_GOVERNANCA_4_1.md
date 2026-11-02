# ContaOS 4.1 — Zero-Drift e Governança de Alterações

Consolidação de `ZeroDrift_v2_Lovable_Supabase.docx`, `README_ZERO_DRIFT.md` e controles instalados no repositório.

## 1. Objetivo

Impedir que uma tarefa localizada altere arquitetura, domínio, segurança ou comportamento fora do escopo. Quanto mais crítica a regra, menos ela deve depender da memória do chat.

## 2. Camadas de proteção

- documentos canônicos na raiz;
- `AGENTS.md` e instruções por agente;
- `docs/tasks/active-task.json`;
- allowed/forbidden paths;
- autorização explícita para banco/RLS/Edge/Auth;
- Plan Mode antes do Build;
- migrations versionadas e imutáveis;
- testes separados;
- revisão de diff;
- Architecture Guard;
- scan de secrets;
- CI Zero-Drift;
- restore/reprodutibilidade;
- revisão humana.

## 3. Regras absolutas

1. uma tarefa deve ter objetivo delimitado;
2. não refatorar fora do objetivo;
3. mudança de banco exige autorização explícita;
4. mudança de RLS exige autorização explícita;
5. Auth/cliente Supabase/governança não são alterados em tarefa comum;
6. prompt funcional não pode afrouxar Zero-Drift;
7. frontend não é autoridade de segurança;
8. nenhum secret no browser;
9. nenhum portão crítico em React;
10. nenhum update genérico de status crítico;
11. documentos/evidências em Storage privado;
12. migration aplicada não é reescrita;
13. falha de teste não autoriza corrigir componente não relacionado;
14. entre alternativas igualmente conformes, a execução deve usar a que consome menos créditos do Lovable;
15. economia de crédito nunca autoriza reduzir teste, segurança, rastreabilidade, acessibilidade, responsividade, evidência, fidelidade ao PRD ou qualquer gate do pacote 4.1.

## 4. Ciclo obrigatório

1. ler integralmente o contexto raiz 00–18, incluindo as quatro partes 08A–08D da matriz 96/96;
2. ler `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` antes de qualquer alteração; em tarefa visual, executar também o protocolo PLAN/BUILD/TESTE do BRAND-01;
3. ler `active-task.json`;
4. inspecionar código/banco relacionado;
5. elaborar plano mínimo;
6. verificar se banco/RLS/RPC/Edge/Auth serão tocados;
7. obter autorização conforme manifesto;
8. executar Build mínimo;
9. rodar testes sem autoexpansão de escopo;
10. auditar diff;
11. validar migrations;
12. scan de secrets/segurança;
13. CI;
14. evidência de aceite;
15. concluir tarefa.

Durante esse ciclo, usar Lovable apenas quando a etapa realmente depender do editor/runtime/frontend Lovable. GitHub e Supabase devem ser usados diretamente para tarefas de documentação, inspeção, rastreabilidade e evidência que não exijam o Lovable.

## 5. Sinais clássicos de drift

- tabela não pedida;
- coluna/status “mais simples” inventado;
- policy afrouxada para teste passar;
- bucket tornado público;
- secret usado no frontend;
- botão React alterando status crítico;
- migration antiga editada;
- correção de bug diferente “aproveitando a oportunidade”;
- alteração em PROD durante HML;
- precedente transversal entrando no portão;
- texto oficial alterado;
- novo backend ou serviço de estado paralelo;
- remoção de auditoria/hash/versionamento para simplificar;
- repetição desnecessária de turns, builds, scans ou testes no Lovable quando a evidência já é válida;
- reenvio de prompt Lovable enquanto o turno anterior ainda está processando;
- uso do Lovable para tarefa que poderia ser concluída diretamente via GitHub ou Supabase sem perda de evidência.

## 6. Manifesto de tarefa

Toda tarefa que altere implementação deve registrar no `active-task.json`, no mínimo:
- id/título/status;
- contexto 4.1 lido e fingerprint atual;
- `brand_pack_version = ContaOS Brand v1.0`;
- `brand_01_read_acknowledged = true`;
- indicação se a tarefa possui escopo visual/brand;
- arquivos permitidos/proibidos;
- flags de autorização de DB/RLS/Edge/Auth;
- objetos aprovados;
- critérios de aceite;
- testes obrigatórios.

## 7. Context Gate

O repositório deve manter um gate automatizado que:
- confirma presença de todos os documentos canônicos, incluindo 08A–08D;
- confirma presença de `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` como camada complementar obrigatória;
- calcula fingerprint SHA-256 do conjunto;
- exige declaração de leitura do contexto em tarefa ativa quando houver alteração de implementação;
- bloqueia alteração de implementação usando manifesto desatualizado;
- permite atualização controlada dos próprios documentos de governança sem exigir falsa declaração de uma tarefa funcional.

O gate não prova biologicamente que uma IA “leu”, mas transforma a leitura em obrigação explícita, verificável e ligada ao hash da versão do contexto.

## 8. Disciplina canônica de economia de créditos Lovable

A eficiência de créditos faz parte da governança operacional do projeto:

1. preferir ferramentas diretas e de menor custo quando produzirem a mesma evidência e conformidade;
2. consolidar instruções compatíveis em um único turno Lovable;
3. evitar duplicação de prompts, planos, builds, testes e scans;
4. recuperar o estado de um turno em processamento antes de reenviar qualquer instrução;
5. validar contratos, backend e diffs fora do Lovable sempre que possível;
6. usar mudanças incrementais mínimas, evitando reconstrução sem necessidade;
7. reutilizar testes e evidências ainda válidos, reexecutando apenas o que uma mudança realmente invalidou;
8. manter separação BUILD/Teste C quando exigida, mesmo que isso consuma crédito adicional;
9. nunca trocar qualidade por economia.

## 9. Critério final

O agente pode propor. O manifesto autoriza. RLS limita. RPC protege. O diff revela. O teste prova. O CI bloqueia. O humano decide. A eficiência de créditos otimiza o caminho, mas nunca enfraquece o resultado.

## 10. Zero-Drift visual — PROMPT 000 / BRAND-01

O BRAND-01 é uma camada transversal de identidade visual, não uma autorização para alterar arquitetura ou funcionalidade.

Regras adicionais obrigatórias:

1. o pacote `ContaOS Brand v1.0` é fonte de verdade apenas para identidade visual;
2. o pacote 4.1 permanece soberano para arquitetura, Design System estrutural, UX funcional, navegação, comportamento, acessibilidade, segurança, backend, dados e regras de negócio;
3. não criar Design System paralelo;
4. não redesenhar ou reconstruir assets oficiais quando houver SVG/PNG oficial;
5. não espalhar cores da marca hardcoded por componentes; reutilizar tokens existentes ou estender centralmente quando indispensável;
6. não alterar texto funcional, campo, tabela, gráfico, fluxo, menu, status, permissão, ação, dado, filtro, notificação ou mensagem funcional para aplicar a marca;
7. não alterar Supabase, migrations, RLS, grants, RPCs, Database Functions, Edge Functions, Auth, cliente Supabase, variáveis de ambiente ou integrações em tarefa BRAND-01;
8. não alterar rotas, RBAC, regras de negócio, cálculos ou estrutura de dados;
9. alterações visuais devem ficar limitadas aos arquivos aprovados no PLAN;
10. Teste BRAND-01 é read-only: durante a fase C não se altera código;
11. validar obrigatoriamente 1440, 1280, 768 e 390 px, dark mode, acessibilidade, favicon e PWA quando aplicável;
12. qualquer necessidade além da camada visual é **LACUNA ou CONFLITO** e exige parada, não improvisação.

A nova faixa atômica **000–096** não altera a certificação **96/96**: `000` é transversal visual; `001–096` continuam correspondendo aos 96 requisitos explícitos do PRD.
