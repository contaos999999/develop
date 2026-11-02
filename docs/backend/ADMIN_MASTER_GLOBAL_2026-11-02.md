# Certificação HML — Administrador Master Global

Data: 02/11/2026  
Ambiente: Supabase HML `gklhhhyosgasnyoxlrui`  
PROD: não alterado

## Decisão canônica
Existe uma identidade **Administrador Master** global, distinta do `administrador` de organização. O Master não depende de `vinculos_usuarios` para acessar organizações/contratos. RLS, sessão ativa, auditoria e operações críticas protegidas permanecem obrigatórias. O Master equivale a `administrador` para autorização administrativa, mas não recebe automaticamente papéis humanos especializados como `direcao_aprovador`.

## Implementação
- `privado.administradores_master`: tabela privada, sem DML para `anon`/`authenticated`.
- `privado.usuario_e_administrador_master()`: sessão ativa + concessão ativa/vigente.
- Helpers centrais atualizados:
  - `privado.usuario_tem_acesso_organizacao(uuid)`
  - `privado.usuario_tem_acesso_contrato(uuid)`
  - `privado.usuario_possui_perfil(uuid,text[])`
  - `privado.usuario_possui_vinculo_ativo()`
- `public.listar_organizacoes_disponiveis()`: `SECURITY INVOKER`; Master recebe todas as organizações; demais usuários somente vínculos ativos/vigentes.
- Eventos de auditoria:
  - `AdministradorMasterConcedido`
  - `AdministradorMasterAtualizado`
  - `AdministradorMasterRevogado`
- ADM-01 herda autorização Master pelos helpers centrais.
- Edge `admin-invite-user` já chama `validar_administrador_organizacao`; nenhum delta no Edge foi necessário.

## Migrations HML
- `20261102183500_admin_master_global.sql`
- `20261102184200_admin_master_rpc_security_invoker.sql`

## TDD e evidências
RED observado antes da implementação: ausência de `privado.administradores_master`.

GREEN principal, dados sintéticos + `ROLLBACK`: **20/20 PASS**.
Cobriu tabela privada/grants, reconhecimento Master, acesso A+B, contratos A+B, RLS, RPC de organizações, ADM-01, escrita via RLS, administrador comum isolado, usuário sem vínculo negado, Master inativo e Master expirado.

Prova adicional ADM-01, sintética + `ROLLBACK`: **PASS**.
- Master sem vínculo próprio na organização executou `salvar_vinculo_usuario_adm`;
- vínculo de usuário alvo foi criado;
- evento `VinculoUsuarioAdministrativoSalvo` foi registrado.

Após Security Advisor apontar `SECURITY DEFINER` exposto na RPC de organizações, foi criada migration corretiva tornando-a `SECURITY INVOKER`.

Regressão pós-hardening, dados sintéticos + `ROLLBACK`: **6/6 PASS**.
- RPC é `SECURITY INVOKER`;
- `anon` sem EXECUTE;
- Master vê A+B e perfil `administrador_master`;
- administrador comum vê somente A;
- administrador comum não é Master.

## Security Advisor pós-DDL
Nenhum finding novo do recurso Master. Restou somente o warning global pré-existente `auth_leaked_password_protection`.

Referência de remediação do warning global: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Edge ADM-01
`admin-invite-user` valida o chamador com `caller.rpc('validar_administrador_organizacao', ...)`. Como o wrapper herda `usuario_possui_perfil`, o Master é aceito como administrador global sem expor `service_role` ao browser. `service_role` permanece exclusivamente dentro da Edge Function.

## Conclusão backend
**PASS** para backend HML do Administrador Master global. Próximo passo: adaptar SYS-01 login e SYS-04 seleção de organização para consumir `listar_organizacoes_disponiveis`, seguido de regressão completa e Teste C separado.
