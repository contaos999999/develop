# ContaOS Frontend — Manifesto de Snapshot Lovable

Data de referência: 02/11/2026
Ambiente: HML
Branch canônica: `design/frontend-master-plan`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Supabase HML: `gklhhhyosgasnyoxlrui`

## Autoridade

O GitHub `contaos9999/develop` é o repositório canônico do HML. O Lovable não está sincronizado automaticamente com esse repositório existente. Por isso, toda alteração aprovada no Lovable deve ser auditada e espelhada no GitHub com evidência própria.

## Snapshot funcional atual

Commit Lovable do BUILD inicial do SYS-01: `3d46cbd87d45e64922f6fb4a3bea630a6d05fb3b`.
Commit Lovable da correção visual/a11y: `10ebeba38bcb423d39898ba73f77d77b236b697d`.

Arquivos específicos do SYS-01 já espelhados no GitHub, com conteúdo correspondente ao estado final aprovado do Lovable:

- `frontend/src/routes/login.tsx`
- `frontend/src/components/auth/LoginForm.tsx`
- `frontend/src/lib/auth/resolverDestinoPosLogin.ts`
- `frontend/src/test/login.test.tsx`
- `frontend/src/test/resolverDestinoPosLogin.test.ts`

Documentação/evidências canônicas permanecem em `docs/frontend/lovable/**`.

## Arquivos deliberadamente NÃO espelhados como parte do PROMPT 16

- `.env`: proibido versionar variáveis de ambiente locais, mesmo contendo apenas valores públicos.
- `.lovable/**`: metadados internos e planos temporários da plataforma, preservados por evidência documental no GitHub em vez de copiados como runtime.
- `AGENTS.md` do Lovable: a alteração indevida feita no BUILD inicial foi revertida; o `AGENTS.md` canônico da raiz do GitHub é superior e continua autoridade.
- `supabase/**` gerado no projeto Lovable: backend é externo, certificado e proibido nesta tarefa. O frontend não deve duplicar migrations/configuração de backend.
- artefatos binários e boilerplate shadcn não usados pelo SYS-01: não pertencem ao escopo funcional deste prompt.

## Dependências compartilhadas ainda não importadas para `frontend/`

Os arquivos específicos do SYS-01 importam o scaffold React/TanStack/Tailwind/shadcn/Supabase do projeto Lovable. O baseline compartilhado inclui, entre outros, `package.json`, roteador, estilos, utilitários UI, cliente Supabase público e tipos gerados.

Esses arquivos ainda NÃO foram declarados como snapshot integral no GitHub nesta etapa, para evitar copiar boilerplate não auditado ou arquivos fora do escopo do PROMPT 16. Portanto, `frontend/` neste commit é um **snapshot versionado da feature SYS-01**, não ainda um clone autônomo do scaffold Lovable.

A importação integral do baseline deve ocorrer em uma tarefa explícita de `Frontend Scaffold Baseline`, dentro de `frontend/**`, com:

1. inventário completo de arquivos;
2. exclusão formal de secrets e `.env`;
3. scan de secrets;
4. ajuste de textos genéricos do boilerplate para PT-BR em tarefa autorizada;
5. typecheck/lint/test/build no GitHub;
6. geração controlada dos tipos Supabase a partir do HML sem alterar schema;
7. commit/PR próprio;
8. Zero-Drift verde.

## Estado do PROMPT 16

O SYS-01 está implementado e os testes locais/Playwright aplicáveis passaram, mas o gate oficial ainda não está fechado porque faltam credenciais HML de teste para validar:

- login autorizado real;
- usuário autenticado sem vínculo/permissão;
- estado real pós-login sem acesso.

Não é permitido criar usuário, alterar Auth ou RLS dentro da tarefa atual (`auth_changes_allowed=false`).

## Regra de continuidade

Nenhum novo prompt funcional deve reutilizar arquivos do Lovable sem que o respectivo código/diff aprovado e as evidências sejam registrados no GitHub. O PROMPT 17 não deve iniciar enquanto o gate do PROMPT 16 permanecer oficialmente aberto, salvo decisão formal de governança que mova os cenários bloqueados para uma tarefa de testes HML separada.
