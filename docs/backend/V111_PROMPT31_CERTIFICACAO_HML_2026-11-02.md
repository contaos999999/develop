# ContaOS 4.1 — Certificação Backend HML do PROMPT 31 / V1-10

Data de referência: 02/11/2026 (horário de Brasília)  
Ambiente: HML  
Supabase project ref: `gklhhhyosgasnyoxlrui`  
PROD: intocado

## 1. Objetivo

Registrar a evidência de fechamento das lacunas de backend identificadas durante o PLAN do PROMPT 31 / V1-10 — Central de Documentos do Contrato, especificamente para V1-CON-001, V1-CON-002 e V1-CON-005, sem alteração de RLS, Auth, Edge Functions ou ambiente de produção.

## 2. Correções certificadas

### V1-CON-001 — Documento-base completo

O backend HML passa a suportar criação de documento-base com:

- categoria;
- início de vigência;
- fim de vigência opcional;
- observações;
- versionamento inicial;
- processamento documental já existente;
- auditoria;
- idempotência.

RPC pública certificada: `public.criar_documento_contrato_completo(...)`.

### V1-CON-002 — Vigência da sugestão/regra extraída

O backend HML passa a permitir definição explícita e auditada de vigência da sugestão de extração antes da revisão humana.

RPC pública certificada: `public.definir_vigencia_sugestao_extracao(uuid,date,date)`.

A regra assistida criada a partir da sugestão herda `vigencia_inicio` e `vigencia_fim` do registro revisado.

### V1-CON-005 — Fonte obrigatória

O fluxo real `public.revisar_sugestao_extracao(...)` cria regra em `regras_conformidade` com `origem='sugestao_extracao'` e `id_sugestao`.

O trigger `v111_validar_fonte_vigencia_regra_assistida` bloqueia a criação/atualização da regra assistida quando:

- a sugestão de origem não existe;
- não há página;
- não há trecho da fonte;
- não há início de vigência.

Quando válida, a regra recebe do backend a página, o trecho e a vigência da sugestão, sem depender do React como autoridade.

## 3. Migrations canônicas no GitHub

- `20261103014500_v110_v111_vigencia_schema.sql`
- `20261103014511_v111_documento_completo_funcao.sql`
- `20261103014512_v111_documento_completo_publica.sql`
- `20261103014521_v111_definir_vigencia_sugestao.sql`
- `20261103014522_v111_validar_regra_assistida_funcao.sql`
- `20261103014523_v111_validar_regra_assistida_trigger.sql`

Os arquivos agregadores já existentes no histórico do repositório permanecem imutáveis. Nenhuma migration anterior aplicada foi reescrita.

## 4. Versões registradas no HML

O Supabase registrou as aplicações no HML com os timestamps reais de execução:

- `20261103020039` — `v110_v111_vigencia_schema`
- `20261103021333` — `v111_documento_completo_funcao`
- `20261103021338` — `v111_documento_completo_publica`
- `20261103021346` — `v111_definir_vigencia_sugestao`
- `20261103021353` — `v111_validar_regra_assistida_funcao`
- `20261103021357` — `v111_validar_regra_assistida_trigger`

A diferença entre os timestamps de aplicação do HML e os nomes pré-versionados dos arquivos GitHub é apenas operacional. O SQL aplicado corresponde ao conteúdo canônico versionado. Os arquivos históricos não foram renomeados nem reescritos após aplicação.

## 5. Funções, grants e trigger

Validação pós-deploy no HML:

- 5 funções V1-11 esperadas encontradas;
- funções privadas `SECURITY DEFINER`, sem `EXECUTE` para `public`, `anon` ou `authenticated`;
- wrappers públicos `SECURITY INVOKER`;
- wrappers públicos com `EXECUTE` para `authenticated` e sem `EXECUTE` para `anon`/`public`;
- 1 trigger `v111_validar_fonte_vigencia_regra_assistida` ativo em `public.regras_conformidade`;
- trigger executado `BEFORE INSERT OR UPDATE FOR EACH ROW`.

## 6. Teste transacional real no HML

Foi executado teste com usuário, sessão, organização, vínculo, contratante, contrato, arquivo, documento e sugestões sintéticas, seguindo o padrão de claims usado nos testes oficiais do projeto.

Todos os dados do teste foram revertidos ao final. Resultado:

| Verificação | Resultado |
|---|---|
| Documento-base completo | PASS |
| Vigência/observações persistidas | PASS |
| Versão inicial | PASS |
| Idempotência, repetição gera o mesmo documento | PASS |
| Vigência da sugestão | PASS |
| Auditoria `VigenciaSugestaoExtracaoDefinida` | PASS |
| Revisão humana válida gera regra em rascunho | PASS |
| Regra herda página/trecho/vigência | PASS |
| Sem página/trecho | Bloqueado com `PT400` |
| Sem início de vigência | Bloqueado com `PT400` |
| Fim de vigência anterior ao início | Bloqueado com `PT400` |
| Rollback dos dados sintéticos | PASS |

Mensagens validadas:

- `PT400: A regra assistida exige página e trecho da fonte.`
- `PT400: A regra assistida exige início de vigência antes da aprovação.`
- `PT400: O fim da vigência não pode ser anterior ao início.`

## 7. Segurança

Advisor de segurança após o DDL:

- Critical: 0;
- High: 0;
- permanece somente o WARN preexistente `auth_leaked_password_protection`, fora do escopo funcional desta tarefa.

Nenhuma policy RLS foi afrouxada. Nenhuma mudança de Auth, Edge Function ou segredo foi realizada.

## 8. CI e Zero-Drift

No SHA `3e44565a136c900836f570d8d4658b7f878cbf84`:

- ContaOS Zero-Drift: PASS, run `41564293576`;
- ContaOS Restore Isolado: PASS, run `41564293470`.

O Restore Isolado recompôs o PostgreSQL do zero a partir do histórico versionado e passou todos os gates existentes, incluindo aceitação HML, BOPLA, BOLA, autorização, SQL Injection, reanálise, backend V1-07 e concorrência.

## 9. Conclusão

**BACKEND HML PROMPT 31 / V1-10: CERTIFICADO para os bloqueadores V1-CON-001, V1-CON-002 e V1-CON-005.**

O frontend pode reabrir o PLAN do PROMPT 31 consumindo exclusivamente as RPCs e estruturas certificadas do Supabase HML. O frontend não deve recriar regra material, fonte, vigência, auditoria ou idempotência localmente.
