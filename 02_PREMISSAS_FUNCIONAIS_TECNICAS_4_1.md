# ContaOS 4.1 — Premissas Funcionais e Técnicas Canônicas

Consolidação normativa de `ContaOS_Premissas_Funcionais_Tecnicas_1_a_5_v2_0_Lovable_Supabase.docx`.

## 1. Hierarquia de autoridade do produto

1. decisão funcional mais recente e expressamente aprovada;
2. PRD Mestre vigente;
3. Premissas Funcionais e Técnicas;
4. Arquitetura técnica oficial;
5. schema, migrations, segurança, APIs e código existente certificado.

Nenhuma arquitetura, framework, biblioteca, gerador, low-code ou IA pode alterar premissa funcional para facilitar implementação.

## 2. Premissas globais

- ContaOS é camada de auditoria/conformidade/prevenção/inteligência/governança, não ERP.
- Produto inteiro em PT-BR.
- `PODE APRESENTAR AO CONTRATANTE` apenas com 100,00% dos requisitos obrigatórios/aplicáveis conformes.
- 100,00% não é média ponderada.
- Aprovação humana confirma a conclusão objetiva, mas não dispensa requisito.
- `PODE REAPRESENTAR AO CONTRATANTE` apenas com 100% dos apontamentos da rodada tratados.
- `VALIDADA` apenas após parecer final favorável do contratante.
- Expressões “Apta para apresentação” e “Apta para reapresentação” são proibidas no domínio.
- Histórico não é apagado.
- Toda conclusão relevante é rastreável.
- IA não cria obrigação sem fonte nem ativa regra material silenciosamente.
- Regra preventiva material permanece proposta até revisão/aprovação humana.
- Precedente não supera fonte formal incompatível/posterior.
- Temporalidade é obrigatória.
- Produto é multi-organização e multi-contrato desde o início.

## 3. Hierarquia das fontes de conformidade

| Prioridade | Fonte | Efeito |
|---|---|---|
| 1 | legislação e atos normativos aplicáveis | fonte formal superior |
| 2 | contrato e aditivos vigentes | obrigações, limites, escopo e vigência específicos |
| 3 | proposta/plano de trabalho/instrumento aprovado | rubricas, limites, destinação e parâmetros econômicos |
| 4 | manuais, listas, regulamentos e orientações formais do contratante | operacionalização da comprovação quando aplicável |
| 5 | comunicações formais e decisões específicas do contrato | entendimento complementar identificável/vigente |
| 6 | precedentes do próprio contrato | podem originar regra preventiva após governança |
| 7 | histórico de outros contratos do mesmo contratante | inteligência transversal, não impeditiva por si só |
| 8 | padrões estatísticos/inferências | priorização e prevenção, não obrigação formal |

## 4. Bloqueio versus sinalização

| Situação | Participa dos 100% | Pode bloquear |
|---|---:|---:|
| requisito obrigatório do contrato não atendido | sim | sim |
| documento obrigatório ausente | sim | sim |
| regra preventiva impeditiva do próprio contrato | sim | sim |
| conciliação obrigatória divergente | sim | sim |
| precedente próprio formalizado como regra impeditiva | sim | sim |
| apontamento apenas em outro contrato do mesmo contratante | não | não |
| padrão estatístico | não | não |
| previsão de possível questionamento por IA | não | não |
| norma nova ainda sem aplicabilidade formalizada | não | não automaticamente |
| regra formal nova, aprovada e aplicável | sim | sim |

## 5. Premissas por versão

### 1.0
O sistema precisa aprender com relatórios anteriores já no primeiro ciclo. Histórico é parte do núcleo, não funcionalidade opcional futura. Checklist é versionado e condicionado. Análise registra evidência, versão e método. Liberação ocorre só com 100% + parecer humano + contexto atual.

### 2.0
Parecer do contratante vira ciclo de diligência. Apontamento não é “resolvido” por simples conclusão de tarefa: a solução precisa ser validada. Contestação sempre é assistida e revisada. Reapresentação só ocorre com tratamento integral da rodada. `VALIDADA` depende do contratante.

### 3.0
Prevenção financeira deve atuar antes do fechamento quando houver dados. Alertas são rastreáveis, configuráveis e preservados mesmo depois de tratados. Não devem criar regra bloqueante fora da hierarquia formal.

### 4.0
Dois níveis de memória: próprio contrato e transversal do mesmo contratante. O segundo é informativo. Divergências entre contratos devem ser mostradas. Fonte/origem precisa ficar visível. Promoção de alerta transversal exige fonte formal independente aplicável ao contrato atual + revisão humana.

### 5.0
Controles corporativos são versionados/aplicáveis temporalmente. Falhas relevantes geram não conformidade e remediação. Segregação de funções pode impedir autoaprovação. Mudança normativa exige análise de impacto e aprovação antes de produzir efeito.

## 6. Premissas técnicas independentes da implementação

- separar organização, contratante e contrato;
- precedentes com origem completa;
- busca histórica com escopo explícito;
- portão usa somente requisitos impeditivos aplicáveis ao contrato atual;
- alerta transversal em estrutura/atributo inequívoco de não bloqueio;
- frontend não promove alerta transversal diretamente;
- snapshots de apresentação/reapresentação preservam versões e hashes;
- operações críticas de status centralizadas em RPC/caso de uso protegido;
- IA desacoplada do domínio;
- auditoria distingue ator humano, automação, job, integração e IA;
- upload/download preferencialmente direto navegador↔Storage com autorização temporária;
- processos pesados são assíncronos;
- jobs idempotentes, com retry/backoff/timeout/DLQ quando aplicável;
- paginação/índices obrigatórios em grandes coleções;
- operações críticas usam transação/locks; edições comuns usam versão otimista;
- integrações externas falham isoladamente;
- observabilidade, backup, recuperação, health check e carga são parte do produto.

## 7. Regra pós-liberação

Qualquer alteração material de documento, requisito, proposta, dado financeiro ou outro contexto que participou da análise depois de uma liberação deve:
1. invalidar o portão anterior;
2. remover/invalidar marca temporal de liberação quando aplicável;
3. marcar competência para reanálise;
4. impedir uso de hash/snapshot antigo;
5. exigir nova análise antes de nova aprovação/protocolo.

Essa regra foi implementada no HML nas migrations 0047–0049 e faz parte da premissa, não de uma otimização opcional.
