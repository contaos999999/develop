# ContaOS 4.1 — PRD Mestre Canônico para IA

Este documento consolida o núcleo funcional do `ContaOS_PRD_Mestre_v2_0_Lovable_Supabase.docx` do pacote mestre 4.1 e deve ser lido antes de qualquer implementação.

## 1. Produto

ContaOS é uma plataforma para auditoria, gestão de diligências, prevenção financeira, inteligência histórica e compliance financeiro de contratos públicos. Ele **não substitui** ERP, contabilidade, folha, banco, compras, protocolo oficial nem sistema do contratante. Atua como camada de controle, evidência, análise e governança.

## 2. Evolução por versão

### ContaOS 1.0 — Auditor da prestação de contas

Objetivo: estruturar contrato, fontes normativas, proposta/orçamento, histórico do contratante, competência mensal, documentos, checklist, análise, apontamentos, correções, parecer interno e pacote de apresentação.

Capacidades obrigatórias:
- cadastro de organização, contratante e contrato como entidades distintas;
- contrato/aditivos/versionamento e vigência;
- base normativa e fontes formais versionadas;
- proposta orçamentária, linhas/rubricas e limites;
- listas de verificação/regras versionadas e temporalmente aplicáveis;
- carga de histórico anterior do contratante desde a versão 1.0;
- documentos da competência com versões imutáveis e hash;
- OCR/classificação/extração assistida;
- auditoria determinística e semântica separadas;
- evidência por requisito/apontamento;
- reanálise sem apagar análise anterior;
- parecer interno;
- portão de 100%;
- pacote imutável de apresentação/protocolo.

Fluxo mensal:
1. abrir competência;
2. materializar/snapshot dos requisitos aplicáveis;
3. anexar documentos e processá-los;
4. executar análise;
5. corrigir não conformidades;
6. reanalisar itens afetados;
7. obter 100,00% dos requisitos impeditivos aplicáveis;
8. aprovar parecer interno;
9. confirmar hash/contexto atual;
10. liberar `PODE APRESENTAR AO CONTRATANTE`;
11. gerar pacote imutável e registrar apresentação/protocolo.

### ContaOS 2.0 — Auditor + gestão de diligências

Herda integralmente 1.0 e acrescenta:
- ingestão de parecer/diligência/ofício/relatório do contratante;
- extração dos apontamentos individualmente;
- valores envolvidos e prazos externos;
- análise assistida de procedência;
- confrontação com evidências da competência, normas e precedentes;
- planos de ação, tarefas, responsáveis, prazos, prioridades e dependências;
- validação da solução, não bastando marcar tarefa como concluída;
- contestação com minuta assistida e mapa de evidências;
- múltiplas rodadas de diligência preservadas;
- resultado da contestação alimentando histórico;
- reapresentação somente com 100% dos apontamentos da rodada tratados;
- validação final somente após parecer final favorável.

### ContaOS 3.0 — Auditor preventivo financeiro

Herda 1.0 e 2.0 e acrescenta prevenção antes do fechamento/pagamento:
- fontes e importações financeiras;
- livro financeiro canônico/transações;
- fornecedores e contratos de fornecedores;
- orçamento vivo e consumo de rubrica;
- conciliações;
- validação de rubrica/saldo/remanejamento;
- fornecedor/objeto;
- duplicidade;
- conta bancária correta quando aplicável;
- precedentes financeiros;
- documentação futura necessária;
- central de exceções, responsáveis, tratamento e histórico;
- alertas com limiar/agrupamento para evitar ruído.

Alertas preventivos não alteram silenciosamente portões de conformidade. Um alerta só se torna impeditivo quando existir regra formal/aplicável conforme governança.

### ContaOS 4.0 — Inteligência histórica de contratos

Evolui a memória do produto:
- mapa de exigências recorrentes;
- tempo histórico de análise e ciclos;
- mudanças de interpretação;
- separação entre regra formal e padrão observado;
- precedentes com ranking de similaridade e força;
- precedentes contraditórios visíveis;
- inteligência transversal entre contratos do mesmo contratante, dentro da mesma organização;
- alertas históricos transversais explicitamente não impeditivos;
- perfil de entendimento do contratante;
- risco histórico/preditivo;
- grafo/mapa de conhecimento;
- copiloto do contrato com fontes, temporalidade e limite de certeza.

Regra central: ocorrência em contrato B/C pode alertar contrato A, mas **não entra no numerador/denominador do portão de A**. Para virar regra impeditiva no contrato A deve existir fonte formal independente aplicável ao A e aprovação humana.

### ContaOS 5.0 — Compliance financeiro para contratos públicos

Acrescenta camada corporativa:
- catálogo/versionamento/aplicabilidade de controles;
- execução contínua de controles;
- exceções;
- não conformidades como casos;
- planos de remediação e evidências;
- segregação de funções;
- mudanças normativas e avaliação de impacto;
- publicação temporal de novas regras;
- riscos corporativos e entidades organizacionais;
- clientes API e escopos;
- webhooks e eventos de integração;
- portal/pacote de evidências com acesso temporário auditado;
- exportações rastreáveis;
- painel executivo.

## 3. Portões oficiais

### Apresentação
`PODE APRESENTAR AO CONTRATANTE` somente quando:
- todos os requisitos obrigatórios e aplicáveis estiverem concluídos;
- 100,00% dos impeditivos estiverem conformes;
- `não aplicável` possuir fundamento quando exigido;
- parecer interno estiver aprovado;
- não houver mudança material posterior à análise;
- hash/contexto da análise ainda coincidir com o estado atual;
- controles adicionais aplicáveis não bloquearem a competência.

100% não é média ponderada. Um único requisito impeditivo pendente, não conforme ou inconclusivo bloqueia.

### Reapresentação
`PODE REAPRESENTAR AO CONTRATANTE` somente quando 100% dos apontamentos da rodada estiverem tratados, as soluções tiverem sido validadas e o contexto/reanálise estiver atual.

### Validação
`VALIDADA` somente após parecer final favorável do contratante.

## 4. Histórico, memória e temporalidade

- Histórico nunca é apagado.
- Documento substituído continua existindo como versão anterior.
- Análise anterior permanece rastreável.
- Alteração de regra/norma deve preservar vigências.
- Competência passada deve continuar reconstruível com regras daquele período.
- Precedente registra origem, contrato, competência, relatório, item, solução e desfecho.
- Mudança de entendimento deve ser representada como mudança, não sobrescrita do passado.

## 5. IA

IA pode:
- OCR/visão;
- classificar documento;
- extrair metadados e cláusulas;
- sugerir vínculo com checklist;
- comparar evidências;
- sugerir procedência/contestação;
- gerar minuta;
- recuperar precedentes;
- responder no copiloto;
- sugerir regras candidatas.

IA não pode:
- criar obrigação sem fonte identificável;
- transformar alerta transversal em requisito;
- dispensar requisito impeditivo;
- liberar apresentação/reapresentação;
- validar definitivamente competência;
- ativar silenciosamente regra material;
- inventar fonte, página, trecho ou certeza.

## 6. Segurança e governança

- multi-organização desde o núcleo;
- autorização no backend, não apenas na UI;
- trilha de auditoria para ações relevantes;
- segregação de funções quando aplicável;
- evidências e hashes preservados;
- snapshots de pacotes enviados;
- logs distinguem pessoa, automação, integração e IA;
- LGPD/minimização devem ser consideradas em dados pessoais.

## 7. Localização brasileira

- idioma de produto: PT-BR;
- datas de interface: `DD/MM/AAAA`;
- competência: `MM/AAAA`;
- horas: padrão brasileiro;
- moeda: BRL/R$;
- CPF/CNPJ conforme necessidade;
- mensagens e erros ao usuário em PT-BR;
- timestamps internos devem preservar timezone/UTC adequadamente e ser apresentados no fuso oficial do produto.

## 8. Critério geral de pronto

Uma capacidade só está pronta quando existem, conforme aplicável:
- modelo de dados;
- segurança/RLS/grants;
- regra de negócio no backend;
- UI/fluxo;
- auditoria;
- tratamento de erro;
- idempotência/concorrência;
- filas para processo pesado;
- evidências/fontes;
- testes positivos e negativos;
- rastreabilidade até requisito PRD.
