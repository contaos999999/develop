# PLAN de correção do contraste BRAND-01 em dark mode

**Data:** 03/11/2026 (Brasília). **Status:** PLAN PREPARATÓRIO, SEM BUILD.  
**Motivo:** auditoria `docs/prompts/AUDITORIA_IDENTIDADE_VISUAL_22_TELAS_2026-11-03.md`.  
**Base técnica:** `contaos9999/contaos-hml-control` com logotipo oficial branco no `ContaOSMarca`, superfícies `bg-primary` em 22 telas e `.dark --primary` claro.

## Fonte da verdade e escopo

- Arquitetura 4.1, Manual de Identidade Visual ContaOS v1.0, PROMPT 000/BRAND-01, Zero-Drift §11 e PRD.
- Assets escuros já instalados: `public/brand/ContaOS_Logo_Horizontal_Mono_Branco.svg`, `public/brand/ContaOS_Simbolo_Branco.svg`.
- Assets oficiais para fundo claro (originais extraídos sem edição do pacote `12_IDENTIDADE_VISUAL_OFICIAL/ContaOS_Marca_Oficial_v1.0/01_SVG`):
  - `ContaOS_Logo_Horizontal_Mono_Navy.svg`, SHA256 `bd924993afbb620647d1053614688efea1f157523cbf41b3c36a368b0d0c976c`;
  - `ContaOS_Simbolo_Navy.svg`, SHA256 `5773eb79ade28369b1efd457bf3b69b70f79a9ede87a05aa5e622f44d56e3252`.
- **Escopo máximo de BUILD:** `src/components/brand/ContaOSMarca.tsx` (mínimo hunk para selecionar logo/símbolo por tema), dois novos SVGs oficiais byte-idênticos, `src/test/brand.test.tsx` (novos testes) e documentação de prova. Nenhuma refatoração dos 22 componentes, de estilo global ou tokens.
- **Proibidos:** `src/styles.css`, `supabase/**`, `types.ts`, `client.ts`, `src/components/ui/**`, outros assets, package/lock, RLS/Auth/Storage/PROD.

## Implementação planejada

1. TDD **RED**: exigir que `ContaOSMarca` apresente um par de versões por breakpoint e tema; conferir ALT acessível, decorativo só no símbolo, tamanhos mínimos oficiais, cor/contraste e inexistência de troca por JS/DOM imperativo.
2. Adicionar assets SVG navy oficiais **sem nenhuma alteração de bytes**; o teste deve validar SHA256 contra os hashes originais acima.
3. Alterar somente `ContaOSMarca` para usar os SVGs white em light theme (bg-primary navy) e navy em dark theme (bg-primary claro), utilizando a classe `.dark` nativa do Tailwind e sem novo token ou estado React. Evitar exibir dois logos simultâneos para leitores de tela.
4. TDD **GREEN**; repetir testes BRAND-01 para todas as 22 telas, TS, build, ESLint do delta, segurança, scan de secret e teste de regressão completo.
5. **Teste C em turno separado e somente leitura** do SHA exato. Capturar screenshots de logo/símbolo efetivo e contraste em 1440, 1280, 768 e 390 px nos temas claro/escuro, em autenticação e páginas internas, estados vazio/sucesso/erro. Sem sessão real, registrar limitação expressa. Bloquear `100% PASS` se falta evidência.
6. Registrar commit dos dois assets + componente + teste, SHA oficial da marca, teste em dark mode e documentos com conclusão.

## Gate de qualidade visual

- Um único `ContaOSMarca` semanticamente acessível; duas variantes CSS não podem causar leitura dupla da marca.
- Fundo escuro só recebe branco e fundo claro só recebe navy; sem contraste inadequado; logo horizontal `>=120px`.
- Nenhuma nova paleta, fonte, pacote ou layout. `REUTILIZAR > ESTENDER > CRIAR`.
- Preservar todos os fluxos/estados das telas certificadas e não tocar backend HML ou PROD.

## Economia Lovable

Preparar evidências/arquivos/hashes pelo GitHub e biblioteca, não consumir créditos de descoberta no Lovable. Fazer um PLAN específico, um BUILD mínimo após aprovação humana específica e Teste C isolado. Não duplicar mensagens/execuções enquanto houver turno pending. Não suprimir testes por economia.

## Aprovação

Plano pronto para revisão; **não está aprovado pelo gate específico do Lovable**. O PLAN anterior A/B de idioma e cobertura de marca está em `plan--show` aguardando decisão humana; não ampliar aquele escopo silenciosamente. Este reparo dark é uma etapa separada após concluí-lo.
