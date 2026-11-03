# ContaOS 4.1 — Teste C transversal visual, PROMPTs 16–38
Data de consolidação: 03/11/2026.

## Escopo e imutabilidade
- **Fonte primária:** resposta final do agente Lovable à auditoria em lote; ferramenta de consulta ao projeto confirmou `response.status=completed` e seu relato. O auditor trabalhou com `git archive` isolado do commit `c36c9c817ec97948885acbf8330181d6a7e325e9`, evitando alterações da plataforma no workspace.
- **CI remoto verificado independentemente no GitHub:** https://github.com/contaos9999/contaos-hml-control/actions/runs/41720206213 — SUCCESS no SHA auditado. A suíte `812/812` foi certificada anteriormente, não rerodada por esta auditoria.
- **Types protegido:** `8ea7750b75fd9d76b29c36ce7613392e3ab65e19` no SHA auditado. Posteriormente, a plataforma editou esse arquivo em `0751d11`; workflow Auto-Lock restaurou de verdade no commit `174512a2d2cc978f9c04da54bd8096ad2e47408d`. https://github.com/contaos9999/contaos-hml-control/actions/runs/41725182728
- **Capturas reportadas pelo Lovable:** 254 imagens locais, das quais 184 são 23 telas × 4 larguras (1440/1280/768/390) × 2 temas; 70 são estados e diagnósticos adicionais. Local original do ambiente Lovable: `/tmp/browser/tcx/shots/`, manifesto `/tmp/browser/tcx/SHA256SUMS` com digest divulgado parcialmente `98e3c5d3…6b19`.
- **Limitação probatória importante:** imagens e manifesto ficam em `/tmp` do agente, **não foram publicados em storage durável nem inspecionados integralmente por um segundo auditor**. Não existe, neste repositório, pacote verificável das 254 imagens. A evidência aqui é o relato técnico do agente e a prova do CI/código. O hash truncado informado não permite revalidar o manifesto.
- **Escopo de browser:** visual sem sessão real; todas as telas internas e os estados negado/carregando usam **MOCK**. Não equivale a acesso autorizado real ou RLS em HML. Não houve DML nem upload, e-mail ou login de verdade.

## Inventário das 23 telas

| PROMPT | Funcionalidade | Rota/superfície auditada | Larguras × temas | Estado | Limites |
|---|---|---|---|---|---|
| 16 | SYS-01 — Login | `/login` | 8/8 reportadas | PASS **visual no escopo MOCK** | Página pública; autenticação/e-mail reais não executados |
| 17 | SYS-02 — Esqueci senha | `/esqueci-senha` | 8/8 reportadas | PASS **visual no escopo MOCK** | Página pública; autenticação/e-mail reais não executados |
| 18 | SYS-03 — Redefinir senha | `/redefinir-senha` | 8/8 reportadas | PASS **visual no escopo MOCK** | Página pública; autenticação/e-mail reais não executados |
| 19 | SYS-04 — Selecionar organização | `/selecionar-organizacao` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 20 | SYS-05 — Dashboard | `/` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 21 | ADM-01 — Usuários | `/administracao/usuarios` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 22 | V1-01 — Contratantes | `/contratantes` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 23 | V1-02 — Novo contratante | `/contratantes/novo` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 24 | V1-03 — Editar contratante | `/contratantes/:id/editar` | 8/8 reportadas | PASS **visual no escopo MOCK** | Acesso simulado; parâmetro inválido consulta somente o perfil; conferir requisitos |
| 25 | V1-04 — Contratos | `/contratos` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 26 | V1-05 — Novo contrato | `/contratos/novo` | 8/8 reportadas | PASS **visual no escopo MOCK** | Acesso simulado; foco do calendário nativo a conferir em browser PT-BR |
| 27 | V1-06 — Visão geral | `/contratos/:id` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 28 | V1-07 — Base normativa | `/contratos/:id/base-normativa` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 29 | V1-08 — Orçamento | `/contratos/:id/orcamento` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 30 | V1-09 — Regras | `/contratos/:id/regras` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 31 | V1-10 — Documentos | `/contratos/:id/documentos` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 32 | V1-11 — Detalhe documento | `/contratos/:id/documentos/:id` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 33 | V1-12 — Competências | `/contratos/:id/competencias` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 34 | V1-13 — Nova competência | `/contratos/:id/competencias/nova` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 35 | V1-14 — Visão competência | `/competencias/:id` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 36 | V1-15 — Documentos competência | `/competencias/:id/documentos` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 37 | V1-16 — Análise | `/competencias/:id/analise` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |
| 38 | V1-17 — Painel do requisito | `/competencias/:id/analise + drawer` | 8/8 reportadas | PASS **visual no escopo MOCK** | Estados protegidos MOCK, sem autorização/RLS real |

## Verificações reportadas no navegador pelo agente
- Nenhum erro JavaScript detectado nas verificações e nenhuma rolagem lateral.
- `html[lang=pt-BR]`, H1 único, campos/botões com rótulos, marca oficial em ambos os temas.
- Busca negativa dos termos ingleses especificados e de padrões de segredo no DOM. **Isso não atesta ausência de todos os segredos em rede/storage/server**.
- Foco visível em 12 deslocamentos de Tab em 1440 e 390 px no modo claro. **Não implica prova exaustiva de todos os controles em 768/1280 ou dark**.
- V1-17: drawer aberto em 8/8 condições com botão acessível `Fechar` único; correção histórica da issue #8 permanece confirmada.
- Estados negado, carregando e sem sessão simulados para a maior parte das telas; IDs inválidos nas superfícies declaradas.
- Nenhuma falha funcional reproduzida **no escopo visual e MOCK testado**.

## Três observações a tratar corretamente
1. **PROMPT 26/V1-05:** nos controles nativos `type=date` de `NovoContrato.tsx`, o foco de teclado é visível no ícone de calendário, mas não necessariamente na borda externa do campo. Não é FAIL confirmado; a sugestão de `focus-within` é melhoria futura localizada e exige teste em navegador PT-BR, sem refatoração ampla.
2. **PROMPT 24/V1-03:** URL inválida `/contratantes/abc/editar` não consultou o contratante; realizou consulta ao vínculo de perfil. O critério original exige bloqueio pela RLS e ausência de acesso indevido, não exige ausência de toda requisição de verificação de sessão. **Sem FAIL demonstrado**.
3. **Medição de contraste:** o agente obteve valores `1,09` e `2,57` contra fundos que considerou incorretos. A estimativa anterior `17,8:1` não substitui medição independente de foreground/background corretos no SHA desta auditoria. **Contraste matemático permanece NÃO VERIFICADO**; legibilidade aparente não prova conformidade WCAG.

## Gates e pendências
- **Identidade visual:** PASS no recorte visual da auditoria, conforme relato; digest e screenshots originais ainda não arquivados de forma durável.
- **Economia Lovable:** CONFORME, testes existentes reaproveitados, auditoria read-only.
- **Zero-Drift:** PASS no SHA imutável; na alteração transitória Lovable, FAIL de types.ts, depois **reparado automaticamente** e hash Git oficial revalidado.
- **TDD:** N/A, pois nenhuma funcionalidade foi alterada nesta auditoria.
- **NÃO VERIFICADO:** RLS A/B com titulares/contratos reais, login real, envio e consumo de e-mail de recuperação SYS-03, escrita, upload, execução de RPCs em contexto de permissão real e contraste WCAG independente.
- **Ausência de pré-condições de teste A/B:** HML contém quatro organizações, nenhum contrato e um usuário com vínculo ativo, conforme `docs/prompts/HML_PRECONDICOES_AUTORIZACAO_AB_2026-11-03.md`.
- Os critérios oficiais do GitHub não foram lidos pelo agente Lovable, mas **foram lidos diretamente nesta auditoria de consolidação**: `docs/prompts/CRITERIOS_ORIGINAIS_39_PROMPTS_2026-11-03.json` e `docs/prompts/MATRIZ_416_CRITERIOS_STATUS_E_PROVAS_2026-11-03.json`. Nenhuma verificação não efetuada é retroativamente dada como PASS.

**Conclusão:** 23/23 funcionalidades sem falha visual reportada nas 8 combinações sob MOCK (184 combinações), 70 capturas adicionais reportadas. **Não equivale a 23 funcionalidades homologadas integralmente nem 39/39 ou 49/49**. Produção intocada.
