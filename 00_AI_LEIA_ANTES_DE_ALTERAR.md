# CONTAOS 4.1 — LEITURA OBRIGATÓRIA ANTES DE QUALQUER ALTERAÇÃO

> **REGRA DE BLOQUEIO:** nenhum agente de IA, pessoa, IDE assistida, Lovable, Codex, Claude, Gemini, Copilot, Cursor ou automação pode alterar código, banco, migration, RLS, RPC, Edge Function, Storage, Queue, Cron, Auth, frontend, workflow, regra de negócio, status, prompt ou documentação operacional sem concluir a leitura integral dos documentos canônicos `00` a `20` desta raiz.

Este repositório é o ambiente oficial de homologação do ContaOS. O objetivo desta camada é impedir que uma alteração tecnicamente “boa” quebre regra funcional, segurança, rastreabilidade, temporalidade, multi-organização ou uma premissa já certificada.

## 1. Ordem obrigatória de leitura

Leia **nesta ordem, sem pular**:

1. `00_AI_LEIA_ANTES_DE_ALTERAR.md`
2. `01_PRD_MESTRE_4_1.md`
3. `02_PREMISSAS_FUNCIONAIS_TECNICAS_4_1.md`
4. `03_ARQUITETURA_OFICIAL_4_1.md`
5. `04_MANUAL_AMBIENTE_E_PROMOCAO_4_1.md`
6. `05_BACKEND_SUPABASE_CERTIFICADO_4_1.md`
7. `06_FRONTEND_LOVABLE_ESPECIFICACAO_4_1.md`
8. `07_ZERO_DRIFT_GOVERNANCA_4_1.md`
9. `08_REQUISITOS_96_E_CRITERIOS_ACEITE_4_1.md`
10. `08A_REQUISITOS_001_024_4_1.md`
11. `08B_REQUISITOS_025_048_4_1.md`
12. `08C_REQUISITOS_049_072_4_1.md`
13. `08D_REQUISITOS_073_096_4_1.md`
14. `09_RASTREABILIDADE_FONTES_AUDITORIA_4_1.md`
15. `10_IA_OCR_RAG_E_PRECEDENTES_4_1.md`
16. `11_RNF_PERFORMANCE_CONCORRENCIA_RESILIENCIA_4_1.md`
17. `12_PROMPTS_PROTOCOLO_IMPLEMENTACAO_4_1.md`
18. `13_MAPA_DOCUMENTOS_PACOTE_4_1.md`
19. `14_CHECKLIST_PRE_ALTERACAO.md`
20. `15_ESTADO_CERTIFICADO_HML_4_1.md`
21. `16_CUSTOS_E_PLANOS_REFERENCIA_4_1.md`
22. `17_FONTES_TECNICAS_E_QA_4_1.md`
23. `18_SCHEMA_RLS_EDGE_QUEUES_CRON_4_1.md`
24. `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`
25. `20_PROMPT_000_BRAND_01.md`

Depois leia também o escopo ativo em `docs/tasks/active-task.json`, o certificado em `docs/CERTIFICACAO_BACKEND_HML_4_1.md`, as migrations afetadas e os testes relacionados.

## 2. Declaração obrigatória antes de editar

Antes da primeira alteração, o agente deve registrar no manifesto da tarefa:

- `context_pack_version = 4.1`;
- `context_read_acknowledged = true`;
- lista completa dos documentos obrigatórios lidos;
- hash/fingerprint do contexto vigente;
- objetivo exato da tarefa;
- arquivos permitidos e proibidos;
- se banco, RLS, Edge Function ou Auth podem ser alterados;
- testes que provarão que a mudança não criou drift.

Sem essa declaração, a tarefa deve ser tratada como **NO-GO**.

## 3. Hierarquia de autoridade

Em caso de conflito, aplicar esta ordem:

1. decisão funcional mais recente e expressamente aprovada pelo responsável do produto;
2. PRD Mestre 4.1;
3. Premissas Funcionais e Técnicas 4.1;
4. Arquitetura Oficial Lovable + Supabase;
5. regras Zero-Drift;
6. matriz oficial de 96 requisitos e critérios de aceite;
7. schema, migrations, RLS, RPCs, Edge Functions e testes versionados já certificados;
8. documentação auxiliar e prompts.

**Nenhuma IA pode mudar uma premissa funcional para facilitar implementação.** Se código existente e PRD divergirem, o agente deve parar, apontar a divergência e pedir decisão. Não deve “harmonizar” silenciosamente.

## 4. Regras que nunca podem ser quebradas

- Frontend oficial: Lovable/React/TypeScript.
- Backend oficial: Supabase próprio.
- Não criar backend paralelo.
- HML e PROD são ambientes separados. Desenvolvimento ocorre no HML; PROD não pode ser alterado durante homologação.
- Toda tabela de negócio exposta deve ter RLS e grants mínimos.
- `service_role`, senha de banco, chave OpenAI, token interno e qualquer secret ficam somente no backend/Secrets/Vault.
- O navegador recebe somente credenciais públicas previstas por desenho.
- Ações críticas usam RPC/Database Function/Edge Function autorizada; nunca `update` genérico de status pelo React.
- `PODE APRESENTAR AO CONTRATANTE` exige 100,00% dos requisitos obrigatórios e aplicáveis conformes, parecer interno aprovado e contexto/hash atual.
- `PODE REAPRESENTAR AO CONTRATANTE` exige 100% dos apontamentos da rodada tratados e reanálise/contexto atual.
- `VALIDADA` somente depois de parecer final favorável do contratante.
- Não usar “Apta para apresentação” ou “Apta para reapresentação”.
- Histórico não é apagado. Correção gera nova versão/evento/desfecho.
- Alteração material de documento ou dado após liberação invalida o portão e exige nova análise.
- Precedente de outro contrato do mesmo contratante é informativo e não bloqueia o contrato atual por si só.
- Fonte formal do contrato atual tem primazia sobre precedente histórico.
- IA sugere, extrai, classifica, compara e fundamenta; decisão material continua humana.
- Toda conclusão relevante deve apontar fonte/evidência/versão/competência/execução.
- Mensagens ao usuário em PT-BR, amigáveis e sem stack trace.
- Datas/horas exibidas no padrão brasileiro e fuso oficial definido para o produto; persistência em `timestamptz` quando aplicável.
- **Administrador Master global é regra canônica:** existe uma identidade global distinta do `administrador` organizacional, com acesso administrativo transversal a todas as organizações, contratos, usuários, vínculos, configurações, auditorias e módulos. O Master não depende de `vinculos_usuarios`, mas continua sujeito a sessão ativa, RLS, auditoria e operações críticas protegidas. O papel Master equivale a `administrador` para autorização administrativa e **não** concede automaticamente papéis humanos especializados como `direcao_aprovador`, preservando segregação de funções. `service_role` nunca é usado para representar o Master no navegador.
- **Economia de créditos do Lovable é regra canônica:** entre alternativas igualmente conformes ao pacote 4.1, usar sempre a que consome menos créditos do Lovable.
- Economia de créditos nunca pode reduzir ou contornar PRD, segurança, TDD, Teste C, Zero-Drift, rastreabilidade, cobertura, acessibilidade, responsividade, evidência ou critério de aceite.

## 5. Condições obrigatórias para modificar o backend certificado

O backend HML foi certificado. Portanto uma IA **não começa “melhorando” o backend**. Antes de tocar nele deve provar:

1. qual requisito exige a alteração;
2. por que o comportamento atual não atende;
3. qual migration nova será criada, sem reescrever migration aplicada;
4. impacto em RLS, grants, RPCs, triggers, hashes, auditoria, filas e frontend;
5. rollback ou estratégia de reversão;
6. testes positivos e negativos;
7. manutenção dos 96/96 requisitos;
8. restore limpo a partir das migrations;
9. Zero-Drift e Architecture Guard verdes.

## 6. Proibição de “refatoração por conveniência”

Não alterar nomes de tabelas, colunas, enums, status, funções, rotas, estruturas de Storage, filas, payloads ou contratos de API apenas para deixar o código “mais bonito”. Mudanças estruturais só podem ocorrer quando houver necessidade funcional/técnica expressamente autorizada e migração compatível.

## 7. Regra de parada

Se houver qualquer dúvida sobre conflito, escopo, segurança, fonte normativa, status, portão, tenant, migration ou efeito em produção: **não editar**. Produzir diagnóstico e plano mínimo primeiro.

## 8. Regra canônica de eficiência de créditos Lovable

A execução deve minimizar o consumo de créditos do Lovable sem reduzir qualidade ou prova. Para isso:

1. usar GitHub diretamente para documentação, diff, rastreabilidade, commits e inspeção de arquivos quando o editor Lovable não for necessário;
2. usar Supabase diretamente para inspeção, evidências de backend, RLS, RPC, Edge, logs e testes de banco quando não houver dependência do frontend;
3. reservar Lovable para alteração de frontend, preview/runtime, integração visual e validações que realmente dependam do ambiente Lovable;
4. agrupar instruções compatíveis em um único turno Lovable e evitar mensagens fragmentadas;
5. inspecionar antes de enviar BUILD para reduzir retrabalho;
6. não reenviar prompt enquanto um turno estiver processando; recuperar o estado antes de qualquer retry;
7. evitar repetir planos, scans, builds ou testes já válidos quando não houve mudança que os invalide;
8. executar correções por delta mínimo em vez de reconstruir módulos inteiros;
9. reutilizar contratos, componentes, helpers e evidências certificados quando aplicável;
10. se duas estratégias forem tecnicamente equivalentes e ambas 100% conformes, a de menor custo de créditos Lovable tem precedência obrigatória.

A otimização de crédito é **subordinada à conformidade**. Uma solução mais barata que reduza segurança, testes, rastreabilidade ou fidelidade ao pacote 4.1 deve ser rejeitada.

## 9. Complemento canônico — ContaOS Brand v1.0 / PROMPT 000

A partir de 02/11/2026, a identidade visual oficial passa a integrar o contexto obrigatório do projeto como **camada complementar**. Ela não substitui qualquer regra acima.

Documentos canônicos:
- `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`;
- `20_PROMPT_000_BRAND_01.md`.

A faixa de prompts atômicos passa a ser **000–096**:
- `000`: BRAND-01, transversal e exclusivamente visual;
- `001–096`: os 96 prompts PRD/NFR já existentes, sem renumeração.

A cobertura funcional permanece **96/96**. BRAND-01 não é um 97º requisito do PRD.

Antes de qualquer alteração de logo, símbolo, cores, tipografia, favicon, PWA, sidebar, login, header, tokens, manifest, metadata ou outra aplicação visual no frontend, a IA deve:
1. ler integralmente os documentos 19 e 20;
2. registrar no manifesto `brand_context = ContaOS Brand v1.0` e `prompt_000_brand_01_read = true`;
3. executar o PLAN do PROMPT 000 antes de editar;
4. preservar o Design System e os assets oficiais;
5. manter backend, arquitetura, comportamento e conteúdo funcional fora do escopo;
6. parar e reportar LACUNA ou CONFLITO se a implantação visual exigir alteração fora desse limite.

Em caso de conflito estético com comportamento, arquitetura, segurança, UX estrutural ou Design System, **o pacote 4.1 prevalece**.
