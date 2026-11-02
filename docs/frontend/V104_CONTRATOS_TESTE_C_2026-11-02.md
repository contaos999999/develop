# V1-04 — Contratos — Teste Oficial C

Data: 02/11/2026  
Pacote canônico: ContaOS 4.1  
Frontend: `contaos9999/contaos-hml-control`  
HEAD certificado: `8a809e2e8600ec8616e5d5fe0c1f299b07469548`

## Resultado

**PROMPT 25 / V1-04 — TESTE OFICIAL C: PASS 18/18.**

- Teste focado V1-04: **26/26 PASS**.
- Suíte completa: **13 arquivos, 264/264 PASS**.
- `tsgo --noEmit`: exit 0.
- `vite build` fresco com saída temporária: exit 0.
- Security Scan: **0 novo Critical**; somente aviso global pré-existente `auth_leaked_password_protection`.
- Git: HEAD inicial/final idêntico e working tree limpo.
- Zero-Drift: diff limitado a `.lovable/plan` arquivado, `ListaContratos.tsx`, `contratosDados.ts`, `contratos.tsx`, `contratos.test.tsx` e `routeTree.gen.ts`.

## Comportamento certificado

- `/contratos`, `Contratos — ContaOS`, `robots=noindex`, um único H1.
- Data API read-only + RLS; nenhuma RPC, Edge ou escrita de negócio.
- Q1 de contexto em `organizacoes`; Q2 paginada em `contratos`, 25 itens por página.
- Estados loading, empty, denied, error e success distintos.
- Multi-organização **A → B → A**: troca limpa os dados anteriores, reinicia página 1 e não reutiliza placeholder.
- Resposta tardia da organização anterior não substitui a organização atual.
- Query key inclui usuário, organização e página.
- Responsividade controlada em 1440, 1280, 768 e 390 px, sem overflow horizontal relevante.
- Acessibilidade, teclado, foco, alvos principais e semântica de tabela/cards aprovados.
- Evidência de browser foi CONTROLADA por interceptação; a prova real de RLS permaneceu a certificação externa do HML com rollback.

## Backend associado

`public.contratos` com RLS ativa e policy `contratos_select` baseada em `privado.usuario_tem_acesso_contrato(id)`. Teste sintético real no HML confirmou escopo restrito, escopo total e isolamento entre organizações. Nenhuma alteração de backend foi necessária para V1-04.

PROD permaneceu intocado.
