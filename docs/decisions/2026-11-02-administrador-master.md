# Decisão canônica — Administrador Master global

Data: 02/11/2026
Status: APROVADA pelo responsável do produto
Autoridade: decisão funcional mais recente, com precedência conforme `00_AI_LEIA_ANTES_DE_ALTERAR.md`.

## Regra

O ContaOS deve possuir um perfil **Administrador Master** global, distinto do perfil `administrador` de organização.

### Administrador Master

- acesso global a todas as organizações do ambiente;
- acesso global aos contratos, contratantes, usuários, vínculos, configurações, auditorias e módulos do ambiente;
- pode criar e administrar organizações;
- pode criar/convidar e administrar usuários;
- pode criar, alterar e revogar vínculos e perfis;
- pode selecionar qualquer organização para operar no contexto daquela organização;
- não depende de `vinculos_usuarios` para obter visibilidade global;
- ações relevantes e críticas devem ser auditadas;
- ações críticas continuam protegidas por RPC/Database Function/Edge Function autorizada;
- não expõe `service_role`, secrets ou privilégios de banco ao navegador;
- não autoriza remoção de RLS nem bypass genérico de segurança no frontend.

### Administrador de organização

O perfil existente `administrador` permanece limitado à organização vinculada e continua sujeito às regras normais de multi-organização, RLS, escopo e vínculo.

## Segurança

O Master deve ser reconhecido no backend por mecanismo global próprio, separado de `vinculos_usuarios`. A implementação deve preservar RLS e centralizar o reconhecimento do Master em helper backend único, evitando exceções ad hoc espalhadas por policies.

Toda operação realizada como Master deve preservar ator, data/hora, origem e contexto de organização quando houver, na trilha de auditoria.

## Implementação

Antes da implementação, auditar e ajustar de forma centralizada os helpers de autorização que hoje dependem exclusivamente de vínculo organizacional, em especial:

- `privado.usuario_tem_acesso_organizacao`;
- `privado.usuario_tem_acesso_contrato`;
- `privado.usuario_possui_perfil`;
- operações administrativas ADM-01 e demais RPCs/Edge Functions protegidas.

HML primeiro. PROD permanece intocado até promoção formal.