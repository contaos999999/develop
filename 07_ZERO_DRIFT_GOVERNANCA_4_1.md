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
2. ler `active-task.json`;
3. inspecionar código/banco relacionado;
4. elaborar plano mínimo;
5. verificar se banco/RLS/RPC/Edge/Auth serão tocados;
6. obter autorização conforme manifesto;
7. executar Build mínimo;
8. rodar testes sem autoexpansão de escopo;
9. auditar diff;
10. validar migrations;
11. scan de secrets/segurança;
12. CI;
13. evidência de aceite;
14. concluir tarefa.

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
- arquivos permitidos/proibidos;
- flags de autorização de DB/RLS/Edge/Auth;
- objetos aprovados;
- critérios de aceite;
- testes obrigatórios.

## 7. Context Gate

O repositório deve manter um gate automatizado que:
- confirma presença de todos os documentos canônicos, incluindo 08A–08D;
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

## 10. Complemento canônico — BRAND-01 / Identidade Visual Oficial v1.0

A partir de 02/11/2026, qualquer tarefa com impacto de identidade visual deve ler integralmente `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md` e `20_PROMPT_000_BRAND_01.md` **antes do PLAN**.

O PROMPT 000 / BRAND-01 é um gate transversal exclusivamente visual. Ele complementa estas regras Zero-Drift e não as substitui.

Para BRAND-01:
- a faixa atômica é 000–096; 001–096 permanecem inalterados;
- a cobertura do PRD continua 96/96;
- backend, arquitetura, regras funcionais, rotas, permissões, estados, cálculos e integrações ficam fora do escopo;
- o Design System existente deve ser preservado;
- não criar segunda paleta, Design System paralelo ou hardcodes visuais espalhados;
- não redesenhar nem deformar assets oficiais;
- a marca deve se adaptar ao ContaOS, não o contrário;
- se o PLAN exigir mudança fora do escopo visual, classificar `PLAN: NÃO APROVÁVEL` e parar;
- a fase TESTE não altera código;
- o diff final deve conter somente alterações visuais/documentais previstas no plano aprovado.

No manifesto de uma tarefa visual, registrar também `brand_context = ContaOS Brand v1.0` e `prompt_000_brand_01_read = true`.
## 11. Gate transversal obrigatório em TODOS os prompts: identidade visual e economia Lovable

**Aplicação universal, sem exceções:** todo prompt operacional do ContaOS 4.1, seja regular 00–99, transversal 000–096, PLAN, BUILD, correção, auditoria ou TESTE C, deve conter **literalmente uma seção identificada** `ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE`. A obrigação alcança prompts de frontend e de backend. No backend, o agente declara `impacto_visual: N/A (justificado)`; nunca transforma uma tarefa técnica em redesenho.

### 11.1. Identidade visual como critério de aceite de CADA frontend

1. Antes de planejar, ler `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`, `20_PROMPT_000_BRAND_01.md`, o Design System e os assets oficiais já integrados. Fazer inventário do componente existente. Confirmar uso da marca **ContaOS Brand v1.0**, sem redesenhar SVG/logotipo/símbolo.
2. Preservar identidade em **todas as telas e estados modificados**: logo e versão para fundo claro/escuro, paleta institucional (Navy `#0F172A`, azul `#0EA5E9`, teal `#14B8A6`, superfície `#F1F5F9`), tipografia Inter quando já compatível, tokens, ícones, componentes existentes, hierarquia, espaçamento, bordas, botões, inputs, tabelas, drawers, modais, feedback de erro/loading/empty/success, contraste, foco e legibilidade. A paleta é referência da marca, **não licença para hardcode**: precedência `REUTILIZAR > ESTENDER > CRIAR`.
3. Não introduzir paleta paralela, novos padrões de componente, bibliotecas de UI ou redesenho global em tarefa funcional. Reusar `ContaOSMarca`, assets oficiais e tokens existentes, preservando visual e comportamento das telas certificadas e da V1 anterior.
4. Em PLAN: seção obrigatória com baseline visual, componentes/tokens a reutilizar, riscos de drift visual, arquivos que NÃO serão modificados e matriz de validação de 1440/1280/768/390 px nos temas claro e escuro.
5. Em BUILD: implementar o menor delta com consistência da marca; nenhum componente isolado poderá destoar da identidade já homologada. É proibido alterar assets/estilos globais sem autorização explícita no manifesto.
6. Em TESTE e Teste C **read-only**: comprovar evidências visuais reais da tela alterada nos quatro tamanhos e nos dois temas, incluindo pelo menos loading, vazio, erro e sucesso quando aplicáveis; conferir logomarca, tokens/cores, tipografia, componentes, contraste, responsividade, overflow, acessibilidade, estado de foco e interação. Quando ferramenta visual não estiver disponível, registrar `NÃO VERIFICADO` e **não declarar conformidade visual PASS**.
7. Se houver desvio visual, reportar o **primeiro arquivo/componente e comportamento** com evidência; corrigir em BUILD autorizado e repetir os gates invalidados. Não mudar código dentro do Teste C.
8. **GATE:** prompt sem cláusula ou PLAN sem matriz visual pertinente = `PLAN: NÃO APROVÁVEL`. Entrega frontend sem prova visual válida e requisitos BRAND-01 = `IDENTIDADE VISUAL: NÃO CERTIFICADA`, impedindo `CONCLUÍDO`.

### 11.2. Economia obrigatória de créditos Lovable em CADA prompt

1. **Nunca sacrificar qualidade ou segurança por créditos.** TDD RED→GREEN, CI, Zero-Drift, revisão de diff, Teste C separado, requisitos PRD, evidência, acessibilidade e responsividade são inegociáveis.
2. Antes de enviar instrução ao Lovable: inspecionar estado, commits, contexto, contrato de backend, escopo e testes; preferir **GitHub** para arquivos/diffs/governança/documentação e **Supabase HML** para inspeção/provas de backend, sem consumir crédito Lovable desnecessário.
3. Consolidar instruções completas e compatíveis num turno PLAN e, depois de aprovado, num BUILD delimitado; evitar mensagens fragmentadas, repetições de contexto, reconstrução de componentes ou integrações já certificadas.
4. **Não reenviar** prompt enquanto houver turno `queued`, `running` ou `awaiting_input`. Consultar o ID/status do mesmo turno; responder a cada gate humano obrigatório apenas com aprovação do usuário. Nenhuma aprovação ampla substitui um gate humano específico.
5. Reutilizar bibliotecas, componentes, helper, tokens, testes e evidências ainda válidos; selecionar a **menor alteração conforme**. Não executar o Lovable para atividade executável diretamente em GitHub/Supabase com mesma prova.
6. Preferir scans, diff, verificações documentais e revisões de SQL fora do Lovable; usar o editor/runtime/preview Lovable quando realmente necessário para construir ou validar frontend. Evitar modo de maior custo sem justificativa técnica e autorização adequada.
7. Não duplicar testes, scans ou builds sem alteração que invalide a evidência; entretanto, **nunca pular regressões obrigatórias nem Teste C isolado**. Cada correção deve repetir os gates que possa afetar.
8. PLAN, BUILD e TESTE devem registrar brevemente as decisões de economia adotadas, sem inventar valores de créditos economizados nem estimativas não medidas.
9. **GATE:** ausência da seção de economia ou atalho que suprima controle obrigatório = `ZERO-DRIFT: FAIL`.

### 11.3. Bloco mínimo para copiar em TODOS os prompts

```text
ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE (OBRIGATÓRIO)
Marca: ContaOS Brand v1.0 / BRAND-01; ler 19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md e 20_PROMPT_000_BRAND_01.md para qualquer alteração frontend. Preservar assets oficiais, ContaOSMarca, Design System e tokens (REUTILIZAR > ESTENDER > CRIAR), componentes e estados; sem hardcodes, redesign ou bibliotecas paralelas. PLAN deve informar baseline visual, riscos e matriz de aceite; BUILD deve manter consistência; TESTE/TESTE C devem provar 1440/1280/768/390 nos temas claro/escuro, acessibilidade, marca e estados, sem alterações durante Teste C. Se prompt não envolver frontend, declarar impacto visual N/A justificado e garantir ausência de alteração visual.
Economia Lovable: checar turno/estado/commit antes de enviar; usar GitHub e Supabase diretamente quando possível; consolidar instruções; executar o menor delta; reutilizar testes/evidências válidos; não reenviar turno pendente nem duplicar builds/scans; nunca pular aprovação humana obrigatória, TDD, segurança, CI, Zero-Drift, fidelidade ao PRD, validação visual ou Teste C separado.
Entregar evidências e classificar: IDENTIDADE VISUAL PASS/FAIL/NÃO VERIFICADO/N/A; ECONOMIA LOVABLE CONFORME/NÃO CONFORME; ZERO-DRIFT PASS/FAIL. Sem prova não declarar PASS.
```

Este gate aplica-se a todos os prompts futuros e a **todo prompt em andamento ainda não executado**, inclusive o Prompt 38 / V1-17. Não reescreve retrospectivamente históricos ou decisões certificadas. O texto do prompt operacional deve conter a cláusula, mesmo quando a tarefa for somente backend, documentando o N/A visual justificado.
