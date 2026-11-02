# Evidência — Usuário de teste Auth HML — SYS-01

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable project: `b113dd59-6caf-4c92-8302-457a037a0c6f`

## Usuário de teste

- E-mail: `edivanpablo99@gmail.com`
- Auth user id: `5d1ce797-297b-40bc-a87b-0ac6ade8431f`
- Nome no perfil público: `Teste Login HML`
- Situação do perfil público: `ativo`
- Finalidade: testes funcionais do PROMPT 16 / SYS-01
- `email_confirmed_at`: confirmado
- `confirmed_at`: confirmado

## Credencial

A senha de teste foi gerada de forma criptograficamente aleatória no sandbox do Lovable e armazenada somente em arquivo temporário fora do repositório, com permissão restrita.

A senha, access token e refresh token NÃO foram registrados no GitHub, NÃO foram exibidos em respostas e NÃO fazem parte desta evidência. Isso é uma exceção deliberada à regra de documentação integral por se tratar de segredo de autenticação.

## Cenário 1 — usuário autenticado sem vínculo

Antes de criar qualquer vínculo, o login foi executado em navegador real com Playwright.

Resultado: PASS.

Evidências funcionais:
- Auth respondeu com sucesso;
- consulta de vínculos ativos retornou lista vazia;
- UI permaneceu em `/login`;
- mensagem exibida: `Seu usuário não possui acesso ativo a nenhuma organização. Procure o administrador.`;
- não houve navegação para `/` nem `/selecionar-organizacao`;
- signOut concluído com HTTP 204;
- sessão removida do navegador;
- console sem erro da aplicação e sem dado sensível.

## Bootstrap oficial da organização de teste

Não foi realizado INSERT direto em `vinculos_usuarios`.

Foi utilizada a RPC oficial `public.criar_organizacao(...)`, autenticada com a sessão real do usuário. Essa RPC cria a organização e o primeiro vínculo administrador na mesma transação.

Organização criada:
- id: `c5da25b4-0e90-4b18-a871-cf2005e55000`
- razão social: `ContaOS HML - Teste Login SYS01`
- nome fantasia: `HML SYS01`
- timezone: `America/Sao_Paulo`

Vínculo resultante confirmado diretamente no HML:
- vínculo id: `fcf5bc6b-6fa1-4805-89fe-28c4a4ca129c`
- user id: `5d1ce797-297b-40bc-a87b-0ac6ade8431f`
- perfil: `administrador`
- `escopo_todos_contratos`: `true`
- `ativo`: `true`

## Cenário 2 — usuário autorizado com um vínculo

O login foi repetido em navegador real com Playwright após o bootstrap oficial.

Resultado: PASS.

Evidências funcionais:
- Auth respondeu com sucesso;
- backend retornou vínculo ativo;
- o usuário possui exatamente um vínculo ativo;
- frontend navegou de `/login` para `/` conforme FE 4.1;
- não houve navegação para `/selecionar-organizacao`;
- `Acesso não disponível` não foi exibido;
- SYS-05 ainda não implementado foi tratado apenas como dependência futura e não como falha do SYS-01;
- signOut concluído com HTTP 204;
- sessão removida do navegador;
- console sem erro da aplicação e sem dado sensível.

## Observação sobre organização auxiliar

Durante a preparação inicial foi criada a organização `ContaOS HML - Testes Funcionais` diretamente no HML para isolamento de dados. Ela não foi usada para o vínculo oficial do SYS-01. O vínculo funcional final utiliza exclusivamente a organização criada pela RPC oficial `criar_organizacao` acima.

## Governança

- nenhuma mudança em schema, migration, RLS, Edge Function ou Auth config foi realizada;
- nenhum secret foi versionado;
- nenhum vínculo foi inserido diretamente;
- o vínculo final permanece ativo para testes futuros do HML;
- todos os testes foram executados somente no HML.