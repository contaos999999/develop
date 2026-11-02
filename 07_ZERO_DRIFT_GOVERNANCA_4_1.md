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
- revisão humana;
- gate transversal BRAND-01 para qualquer mudança de identidade visual.

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
15. economia de crédito nunca autoriza reduzir teste, segurança, rastreabilidade, acessibilidade, responsividade, evidência, fidelidade ao PRD ou qualquer gate do pacote 4.1;
16. qualquer alteração visual deve ler `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md` e executar `20_PROMPT_000_BRAND_01.md` antes do Build;
17. BRAND-01 não autoriza backend, arquitetura, regras funcionais, rotas, permissões, estados, cálculos ou integrações;
18. não criar Design System paralelo, não redesenhar asset oficial e não reconstruir tela apenas para adaptar a marca.

## 4. Ciclo obrigatório

1. ler integralmente o contexto raiz 00–20, incluindo as quatro partes 08A–08D da matriz 96/96 e a camada Brand v1.0;
2. ler `active-task.json`;
3. inspecionar código/banco relacionado;
4. elaborar plano mínimo;
5. verificar se banco/RLS/RPC/Edge/Auth serão tocados;
6. se a tarefa for visual, executar o PLAN do PROMPT 000 e classificar `PLAN: APROVÁVEL` ou `PLAN: NÃO APROVÁVEL`;
7. obter autorização conforme manifesto;
8. executar Build mínimo;
9. rodar testes sem autoexpansão de escopo;
10. auditar diff;
11. validar migrations quando aplicável;
12. scan de secrets/segurança;
13. CI;
14. evidência de aceite;
15. concluir tarefa.

Durante esse ciclo, usar Lovable apenas quando a etapa realmente depender do editor/runtime/frontend Lovable. GitHub e Supabase devem ser usados diretamente para tarefas de documentação, inspeção, rastreabilidade e evidência que não exijam o Lovable.

Em BRAND-01, se o PLAN indicar necessidade de alteração funcional, backend ou arquitetura, o plano é **NÃO APROVÁVEL** e a tarefa deve parar.

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
- uso do Lovable para tarefa que poderia ser concluída diretamente via GitHub ou Supabase sem perda de evidência;
- criação de segunda paleta ou Design System para aplicar a marca;
- redesenho manual de SVG existente;
- hardcode de cores da marca em múltiplos componentes;
- alteração de layout, conteúdo, rotas ou comportamento justificada apenas pela identidade visual;
- uso de BRAND-01 para corrigir bug ou refatorar área fora do escopo.

## 6. Manifesto de tarefa

Toda tarefa que altere implementação deve registrar no `active-task.json`, no mínimo:
- id/título/status;
- contexto 4.1 lido e fingerprint atual;
- arquivos permitidos/proibidos;
- flags de autorização de DB/RLS/Edge/Auth;
- objetos aprovados;
- critérios de aceite;
- testes obrigatórios.

Quando a tarefa for visual, registrar também:
- `brand_context = ContaOS Brand v1.0`;
- `prompt_000_brand_01_read = true`;
- assets oficiais que serão utilizados;
- arquivos visuais permitidos;
- confirmação explícita de que backend e comportamento funcional estão fora do escopo.

## 7. Context Gate

O repositório deve manter um gate automatizado que:
- confirma presença de todos os documentos canônicos, incluindo 08A–08D, `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md` e `20_PROMPT_000_BRAND_01.md`;
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

## 9. Regra transversal BRAND-01

A faixa de prompts atômicos passa a ser **000–096**. O 000 é BRAND-01, exclusivamente visual; 001–096 permanecem os 96 requisitos PRD/NFR sem renumeração. A cobertura de requisitos continua 96/96.

A fase TESTE de BRAND-01 é read-only. O diff final deve conter somente alterações visuais/documentais previstas no plano aprovado.

## 10. Critério final

O agente pode propor. O manifesto autoriza. RLS limita. RPC protege. O diff revela. O teste prova. O CI bloqueia. O humano decide. A eficiência de créditos otimiza o caminho, mas nunca enfraquece o resultado. A marca oficial complementa o produto, mas não pode alterar sua constituição funcional.
