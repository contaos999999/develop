# Evidência — PROMPT 16 SYS-01 Login — Teste oficial

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`
Commit Lovable da correção visual: `10ebeba38bcb423d39898ba73f77d77b236b697d`

## Resultado final

| # | Critério oficial | Resultado | Evidência resumida |
|---|---|---|---|
| 1 | rota abre | PASS | `/login` respondeu 200 nos breakpoints testados |
| 2 | perfil autorizado funciona | PASS | Login real com usuário HML autorizado; exatamente um vínculo ativo; destino final `/` |
| 3 | perfil não autorizado/sem vínculo bloqueado pelo backend/RLS | PASS | Cenário real autenticado sem vínculo permaneceu em `/login` com mensagem de acesso não disponível; sem sessão, leitura de vínculos também foi negada pelo backend |
| 4 | loading/empty/error funcionam | PASS | Botão bloqueado durante envio; validação de campos vazios; credencial inválida com mensagem neutra; estado real `sem acesso` validado em sessão real |
| 5 | nenhuma request usa secret key | PASS | Zero requests com `service_role`/`sb_secret`; frontend usa somente publishable key |
| 6 | nenhuma ação crítica é update direto | PASS | SYS-01 não executa update crítico; nenhuma mutação direta de negócio no fluxo do Login |
| 7 | desktop 1440 e 1280 | PASS | Sem overflow horizontal; campos e ações críticas visíveis |
| 8 | tablet 768 | PASS | Sem overflow horizontal; formulário e informações essenciais preservados |
| 9 | mobile 390 preserva dados críticos | PASS | Sem overflow horizontal; e-mail, senha, botão e contexto essenciais visíveis |
| 10 | teclado/foco/labels/tooltips | PASS | Primeiro Tab direciona ao e-mail; campos com labels; controle de senha com `aria-label`; tooltip aparece por foco |
| 11 | console sem erro e sem log sensível | PASS | Nenhum erro de aplicação ou dado sensível; única resposta negativa observada decorreu do teste deliberado de credencial inválida |
| 12 | Security scan sem novo Critical | PASS | Scan forçado não encontrou novo Critical relacionado ao SYS-01 |

## Usuário HML utilizado

- E-mail: `edivanpablo99@gmail.com`
- Auth user id: `5d1ce797-297b-40bc-a87b-0ac6ade8431f`
- Perfil público: `Teste Login HML`

Segredos de autenticação não são versionados. Senha e tokens não foram registrados no GitHub nem exibidos em respostas.

## Organização e vínculo oficial

O vínculo autorizado foi criado pelo bootstrap oficial do backend via `public.criar_organizacao(...)`, e não por INSERT direto em `vinculos_usuarios`.

- Organização: `c5da25b4-0e90-4b18-a871-cf2005e55000`
- Razão social: `ContaOS HML - Teste Login SYS01`
- Vínculo: `fcf5bc6b-6fa1-4805-89fe-28c4a4ca129c`
- Perfil: `administrador`
- Escopo todos os contratos: `true`
- Ativo: `true`

## Evidências dos cenários reais

### Cenário sem vínculo
- login Auth: PASS;
- consulta de vínculos: vazia;
- destino permaneceu `/login`;
- mensagem `Seu usuário não possui acesso ativo a nenhuma organização. Procure o administrador.` exibida;
- não houve navegação para `/` nem `/selecionar-organizacao`;
- signOut HTTP 204;
- sessão removida.

### Cenário autorizado com um vínculo
- login Auth: PASS;
- exatamente um vínculo ativo confirmado no HML;
- destino `/` conforme FE 4.1;
- não houve navegação para `/selecionar-organizacao`;
- não houve bloqueio indevido;
- signOut HTTP 204;
- sessão removida.

## Situação do gate

`PROMPT 16`: **PASS — 12/12 critérios oficiais aprovados**.

O SYS-01 está autorizado a avançar para a próxima etapa prevista pelo Manual Mestre, preservadas as regras de Plan → Build → Test → Audit e Zero-Drift.

## Governança

- nenhuma alteração de schema, migration, RLS, Edge Function ou Auth config foi feita para fechar o teste;
- nenhum secret foi solicitado ou registrado no GitHub;
- `AGENTS.md` alterado indevidamente no BUILD inicial foi revertido no Lovable e não foi espelhado como alteração canônica;
- o usuário e o vínculo de teste permanecem ativos exclusivamente no HML para testes futuros;
- evidência detalhada adicional em `docs/frontend/lovable/EVIDENCIA_USUARIO_TESTE_AUTH_HML_2026-11-02.md`.