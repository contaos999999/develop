# Administrador Master Global — Design

## Intenção
Criar um Administrador Master global no ContaOS com acesso e controle transversal a todas as organizações, contratos, usuários, configurações, auditorias e módulos, sem depender de `vinculos_usuarios` e sem expor `service_role` ao navegador.

## Regras funcionais
- `administrador_master` é identidade global, distinta de `administrador` de organização.
- O Master pode operar qualquer organização e qualquer contrato autorizado pelo próprio papel global.
- O Master pode usar o ADM-01 em qualquer organização selecionada.
- O Master deve conseguir entrar no sistema mesmo sem vínculo organizacional e selecionar qualquer organização.
- Usuários comuns continuam limitados pelos vínculos e escopos atuais.
- Toda ação material continua auditável; o papel Master não remove RLS nem contorna RPCs críticas.
- Dados estritamente pessoais/autoriais continuam respeitando policies próprias baseadas em `id_usuario` quando não forem necessários para administração global.

## Arquitetura escolhida
1. Criar `privado.administradores_master`, fora da Data API pública, referenciando `auth.users`.
2. Criar helper `privado.usuario_e_administrador_master()` com sessão ativa + vigência/ativo.
3. Alterar somente os helpers centrais `usuario_tem_acesso_organizacao`, `usuario_tem_acesso_contrato`, `usuario_possui_perfil` e `usuario_possui_vinculo_ativo` para reconhecer Master.
4. Não reescrever policies individualmente quando elas já usam esses helpers.
5. Criar wrapper público de leitura `public.listar_organizacoes_disponiveis()` para SYS-01/SYS-04. Usuário comum recebe organizações de seus vínculos; Master recebe todas as organizações. RLS permanece autoridade.
6. ADM-01 continua por organização selecionada e passa a aceitar Master através dos helpers existentes.
7. Bootstrap do primeiro Master é ação administrativa de backend/HML, nunca chamada diretamente pelo browser.

## Segurança
- `privado.administradores_master` sem grants para `anon`/`authenticated`.
- `usuario_e_administrador_master()` SECURITY DEFINER, `search_path=''`, sem parâmetros controláveis.
- Nenhuma chave privilegiada no frontend.
- Master inativo ou fora de vigência perde privilégio imediatamente.
- Nenhuma mudança em PROD nesta etapa.

## Frontend
- Login deixa de contar diretamente `vinculos_usuarios` e usa a fonte oficial de organizações disponíveis.
- SYS-04 deixa de depender de linhas físicas em `vinculos_usuarios` para renderizar opções.
- O perfil exibido para Master será `Administrador Master`.
- Troca de organização continua limpando cache/dados da organização anterior.

## Não objetivos
- Não criar painel separado de administração global nesta entrega.
- Não permitir que o browser promova/revogue Masters.
- Não remover segregação de funções nem portões críticos do domínio.
- Não transformar `administrador` organizacional em papel global.

## Abordagens consideradas
- **Adicionar `administrador_master` em `vinculos_usuarios`: rejeitada**, porque exigiria um vínculo por organização e contradiz o requisito global.
- **Usar `service_role` no frontend: rejeitada**, por quebrar RLS e segurança.
- **Tabela privada + helper global central: escolhida**, por preservar a arquitetura atual e exigir o menor delta seguro.
