# Auditoria de identidade visual retrospectiva — ContaOS 4.1 / 22 telas

**Data:** 03/11/2026. **Alvo:** `contaos9999/contaos-hml-control`. **Norma:** `19_IDENTIDADE_VISUAL_OFICIAL_BRAND_1_0.md`, `20_PROMPT_000_BRAND_01.md` e `07_ZERO_DRIFT_GOVERNANCA_4_1.md` §11. **Tipo:** inspeção estática do código, tokens e SVGs do pacote mestre; não confundir com inspeção do DOM renderizado autenticado.

## Resultado

- **22/22** telas existentes utilizam o componente `ContaOSMarca` e a superfície `bg-primary text-primary-foreground` em seus cabeçalhos/áreas de marca.
- **0 cores hexadecimais hardcoded** identificadas diretamente nas 22 telas examinadas; os estilos reutilizam tokens Tailwind/Design System. Não é verificação universal de todos os componentes aninhados ou bibliotecas.
- Os SVGs oficiais são utilizados; os assets originais não foram alterados.
- **13/22** telas constam do `ARQUIVOS_MARCA` em `src/test/brand.test.tsx`. Faltam 9 telas V1-08 a V1-16; **semântica e estilo renderizados nessas telas NÃO VERIFICADOS**.
- **22/22 com potencial desvio de contraste no tema escuro** por fundo claro `bg-primary` com logotipo para fundo navy; confirmado pela leitura do código e dos tokens, ainda não por medição de pixels/contraste no browser.
- O `src/routes/__root.tsx` declara `<html lang="en">`, além de rótulos globais 404/erro em inglês. Correção funcional global mínima planejada.

## Desvio concreto de marca: superfície clara no tema escuro

No `src/styles.css`, `:root --primary: oklch(0.208 0.042 265.755)` é navy, enquanto `.dark --primary: oklch(0.929 0.013 255.508)` é claro. As 22 áreas de marca usam `bg-primary` nos dois temas.

Entretanto, `src/components/brand/ContaOSMarca.tsx` exibe **sempre**:
- desktop, `ContaOS_Logo_Horizontal_Mono_Branco.svg`, asset com retângulo opaco navy `#0F172A` e wordmark branco;
- mobile, `ContaOS_Simbolo_Branco.svg`, símbolo branco transparente.

Por isso, em dark mode, o logo desktop pode aparecer como retângulo navy abrupto sobre header claro; o símbolo mobile branco perde contraste contra header claro. Isso contradiz o objetivo BRAND-01 de legibilidade e escolha da versão adequada ao fundo. **Não há evidência ainda de screenshot/contraste real**, portanto o status é **RISCO VISUAL MATERIAL COMPROVADO NO CÓDIGO**, sem afirmar avaliação de pixels.

### Solução preferencial sem redesenho e com delta mínimo

**Não modificar os 22 componentes, nem `styles.css` e `--primary`.** Usar no próprio `ContaOSMarca` versões *oficiais preexistentes* conforme tema:
- fundos escuros: logo `ContaOS_Logo_Horizontal_Mono_Branco.svg` + símbolo `ContaOS_Simbolo_Branco.svg`, como atualmente.
- fundos claros no tema dark: SVG oficial `ContaOS_Logo_Horizontal_Mono_Navy.svg` (SHA-256 `bd924993afbb620647d1053614688efea1f157523cbf41b3c36a368b0d0c976c`) e `ContaOS_Simbolo_Navy.svg` (SHA-256 `5773eb79ade28369b1efd457bf3b69b70f79a9ede87a05aa5e622f44d56e3252`), ambos presentes em `12_IDENTIDADE_VISUAL_OFICIAL/ContaOS_Marca_Oficial_v1.0/01_SVG/` do pacote mestre 4.1.

Exigir no PLAN revisão do Manual quanto às variantes oficiais, `prefers-color-scheme` e classe `.dark`; no BUILD colocar assets oficiais **byte a byte** em `public/brand` e selecionar variante com classes responsivas `dark:`, mantendo tamanhos, alt e sem JS de tema. Antes de concluir, Teste C deve conferir screenshots e contraste de logo em temas claro/escuro nos quatro breakpoints e em telas autenticadas/erro pertinentes. Não modificar o ativo apenas por suposição sem revisar a renderização real.

## Matriz de 22 telas

| # | Arquivo | Reúso da marca | Prova test BRAND-01 | Contraste no tema escuro | Browser autenticado claro/escuro |
|---|---|---|---|---|---|
| 01 | `src/routes/login.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 02 | `src/routes/esqueci-senha.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 03 | `src/routes/redefinir-senha.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 04 | `src/routes/selecionar-organizacao.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 05 | `src/components/dashboard/Dashboard.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 06 | `src/components/contratantes/ListaContratantes.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 07 | `src/components/contratantes/NovoContratante.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 08 | `src/components/contratantes/EditarContratante.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 09 | `src/components/contratos/ListaContratos.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 10 | `src/components/contratos/NovoContrato.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 11 | `src/components/contratos/VisaoGeralContrato.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 12 | `src/components/contratos/BaseNormativaContrato.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 13 | `src/components/administracao/usuarios/AdminUsuarios.tsx` | PASS (código) | PASS (teste atual) | RISCO (tema escuro) | NÃO VERIFICADO |
| 14 | `src/components/contratos/OrcamentoContrato.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 15 | `src/components/contratos/RegrasContrato.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 16 | `src/components/contratos/DocumentosContrato.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 17 | `src/components/contratos/DocumentoDetalhe.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 18 | `src/components/contratos/CompetenciasContrato.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 19 | `src/components/contratos/NovaCompetencia.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 20 | `src/components/competencias/CompetenciaVisaoGeral.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 21 | `src/components/competencias/CompetenciaDocumentos.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |
| 22 | `src/components/competencias/CompetenciaAnalise.tsx` | PASS (código) | FAIL (sem teste de marca) | RISCO (tema escuro) | NÃO VERIFICADO |

## Gates obrigatórios para fechar a auditoria

1. Estender `brand.test.tsx` para 22/22 e verificar todos os SVGs oficiais por hash, com casos claro/escuro; manter testes anteriores.
2. Corrigir `lang` e mensagens de 404/erro no root sem redesign.
3. Implementar seleção da versão do logo oficial conforme superfície do tema e testar 4 tamanhos x 2 temas x estados aplicáveis.
4. Verificar cores/tokens, legibilidade, contraste mínimo WCAG, 44px para alvos, foco, H1, overflow, status não comunicado só por cor e mensagens PT-BR.
5. Executar regression full, lint de arquivos alterados, typecheck/build, Security Scan e CI Zero-Drift frontend. Teste C separado read-only no SHA imutável; registrar links das screenshots/artefatos verificáveis.
6. **Sem screenshots reais ou prova de contraste, NÃO declarar identidade visual 100% PASS**. Os testes de hashes e código estático, por si só, não bastam.

## Estado de execução

- Fix de `types.ts` já aplicado em commit frontend `bc120e3b6cdb2069ce225d52d23d6eec2d3fa6e5`.
- Workflow frontend novo `.github/workflows/contaos-frontend-zero-drift.yml`, commit `bc00a9a970a00462b925ce38e65a33c3f6cd1530`; primeira execução apontou precisamente idiomas root + 9 telas não cobertas, não passou esses gates.
- Lovable PLAN retrospectivo A (PT-BR) / B (testes BRAND) em gate específico `plan--show`, ainda pendente de aprovação. Reparação adicional do contraste deve ser submetida a PLAN autorizado separado para não ampliar o plano em aprovação.
- PROD, backend e Auth não foram modificados nesta auditoria estática.

**Decisão:** **BRAND-01 do produto: NÃO CERTIFICADA INTEGRALMENTE**. Cobertura estática de marca positiva, com lacunas de teste e risco material de contraste a reparar.
