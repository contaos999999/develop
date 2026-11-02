-- ContaOS HML 4.1 — PROMPT 21 / ADM-01
-- Backend oficial para usuários e vínculos, com concorrência, idempotência,
-- paginação e auditoria. PROD não é alterado por esta migration.

create or replace function privado.validar_administrador_organizacao(p_id_organizacao uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_id_organizacao is null then
    raise sqlstate 'PT400' using
      message = 'Organização inválida.',
      detail = 'Informe a organização selecionada antes de continuar.',
      hint = 'Selecione novamente a organização e repita a ação.';
  end if;

  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise sqlstate '42501' using
      message = 'Você não tem permissão para administrar usuários desta organização.',
      detail = 'A operação exige vínculo ativo com perfil administrador.',
      hint = 'Selecione uma organização em que você seja administrador ou procure um administrador autorizado.';
  end if;
end;
$$;

revoke all on function privado.validar_administrador_organizacao(uuid) from public, anon;
grant execute on function privado.validar_administrador_organizacao(uuid) to authenticated;

create or replace function public.validar_administrador_organizacao(p_id_organizacao uuid)
returns boolean
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform privado.validar_administrador_organizacao(p_id_organizacao);
  return true;
end;
$$;

revoke all on function public.validar_administrador_organizacao(uuid) from public, anon;
grant execute on function public.validar_administrador_organizacao(uuid) to authenticated;

create or replace function privado.listar_usuarios_adm(
  p_id_organizacao uuid,
  p_pagina integer default 1,
  p_tamanho_pagina integer default 25,
  p_busca text default null,
  p_situacao text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(100, greatest(coalesce(p_tamanho_pagina, 25), 1));
  v_busca text := nullif(btrim(coalesce(p_busca, '')), '');
  v_situacao text := nullif(lower(btrim(coalesce(p_situacao, ''))), '');
  v_total bigint := 0;
  v_itens jsonb := '[]'::jsonb;
  v_perfis jsonb := '[]'::jsonb;
  v_contratos jsonb := '[]'::jsonb;
begin
  perform privado.validar_administrador_organizacao(p_id_organizacao);

  if v_situacao is not null and v_situacao not in ('ativo', 'inativo') then
    raise sqlstate 'PT422' using
      message = 'Filtro de situação inválido.',
      detail = 'Use ativo, inativo ou deixe o filtro vazio.',
      hint = 'Revise o filtro e tente novamente.';
  end if;

  select count(*) into v_total
  from public.vinculos_usuarios v
  join public.usuarios u on u.id_usuario = v.id_usuario
  where v.id_organizacao = p_id_organizacao
    and (v_situacao is null or (v_situacao = 'ativo' and v.ativo) or (v_situacao = 'inativo' and not v.ativo))
    and (v_busca is null or lower(coalesce(u.nome, '') || ' ' || coalesce(u.email, '') || ' ' || coalesce(v.perfil, '')) like '%' || lower(v_busca) || '%');

  select coalesce(jsonb_agg(q.item order by q.ord_nome, q.ord_email, q.ord_id), '[]'::jsonb) into v_itens
  from (
    select lower(coalesce(u.nome, u.email, '')) ord_nome,
           lower(coalesce(u.email, '')) ord_email,
           u.id_usuario ord_id,
           jsonb_build_object(
             'id_usuario',u.id_usuario,'nome',u.nome,'email',u.email,'telefone',u.telefone,
             'situacao_usuario',u.situacao,'versao_usuario',u.versao_registro,'atualizado_em',u.atualizado_em,
             'vinculo',jsonb_build_object('id',v.id,'perfil',v.perfil,'perfil_nome',p.nome,'escopo_todos_contratos',v.escopo_todos_contratos,'ativo',v.ativo,'inicio_em',v.inicio_em,'fim_em',v.fim_em,'versao_registro',v.versao_registro,'atualizado_em',v.atualizado_em),
             'contratos_vinculados',coalesce((
               select jsonb_agg(jsonb_build_object('id_contrato',c.id,'numero',c.numero,'objeto',c.objeto,'situacao',c.situacao) order by c.numero,c.id)
               from public.vinculos_usuario_contratos vc
               join public.contratos c on c.id=vc.id_contrato and c.id_organizacao=vc.id_organizacao
               where vc.id_vinculo_usuario=v.id and vc.id_organizacao=p_id_organizacao and vc.ativo=true and privado.usuario_tem_acesso_contrato(c.id)
             ),'[]'::jsonb)
           ) item
    from public.vinculos_usuarios v
    join public.usuarios u on u.id_usuario=v.id_usuario
    join public.perfis_usuarios p on p.codigo=v.perfil
    where v.id_organizacao=p_id_organizacao
      and (v_situacao is null or (v_situacao='ativo' and v.ativo) or (v_situacao='inativo' and not v.ativo))
      and (v_busca is null or lower(coalesce(u.nome,'')||' '||coalesce(u.email,'')||' '||coalesce(v.perfil,'')) like '%'||lower(v_busca)||'%')
    order by lower(coalesce(u.nome,u.email,'')),lower(coalesce(u.email,'')),u.id_usuario
    limit v_tamanho offset ((v_pagina-1)*v_tamanho)
  ) q;

  select coalesce(jsonb_agg(jsonb_build_object('codigo',p.codigo,'nome',p.nome,'descricao',p.descricao) order by p.nome,p.codigo),'[]'::jsonb) into v_perfis from public.perfis_usuarios p;
  select coalesce(jsonb_agg(jsonb_build_object('id_contrato',c.id,'numero',c.numero,'objeto',c.objeto,'situacao',c.situacao) order by c.numero,c.id),'[]'::jsonb) into v_contratos
  from public.contratos c where c.id_organizacao=p_id_organizacao and privado.usuario_tem_acesso_contrato(c.id);

  return jsonb_build_object('schema_versao','adm01-v1','pagina',v_pagina,'tamanho_pagina',v_tamanho,'total',v_total,'total_paginas',case when v_total=0 then 0 else ceil(v_total::numeric/v_tamanho::numeric)::integer end,'itens',v_itens,'perfis_disponiveis',v_perfis,'contratos_disponiveis',v_contratos,'gerado_em',now());
end;
$$;
revoke all on function privado.listar_usuarios_adm(uuid,integer,integer,text,text) from public, anon;
grant execute on function privado.listar_usuarios_adm(uuid,integer,integer,text,text) to authenticated;

create or replace function public.listar_usuarios_adm(p_id_organizacao uuid,p_pagina integer default 1,p_tamanho_pagina integer default 25,p_busca text default null,p_situacao text default null)
returns jsonb language sql stable security invoker set search_path=''
as $$ select privado.listar_usuarios_adm($1,$2,$3,$4,$5) $$;
revoke all on function public.listar_usuarios_adm(uuid,integer,integer,text,text) from public, anon;
grant execute on function public.listar_usuarios_adm(uuid,integer,integer,text,text) to authenticated;

create or replace function privado.listar_auditoria_usuario_adm(p_id_organizacao uuid,p_id_usuario uuid,p_limite integer default 50)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_limite integer:=least(100,greatest(coalesce(p_limite,50),1)); v_eventos jsonb:='[]'::jsonb;
begin
  perform privado.validar_administrador_organizacao(p_id_organizacao);
  if not exists(select 1 from public.vinculos_usuarios v where v.id_organizacao=p_id_organizacao and v.id_usuario=p_id_usuario) then
    raise sqlstate 'PT404' using message='Vínculo de usuário não encontrado.',detail='O usuário informado não possui vínculo com esta organização.',hint='Atualize a lista e tente novamente.';
  end if;
  select coalesce(jsonb_agg(q.item order by q.criado_em desc,q.id desc),'[]'::jsonb) into v_eventos
  from (
    select e.id,e.criado_em,jsonb_build_object('id',e.id,'evento',e.evento,'entidade',e.entidade,'antes',e.antes,'depois',e.depois,'metadados',e.metadados,'correlation_id',e.correlation_id,'criado_em',e.criado_em,'ator',jsonb_build_object('id_usuario',e.id_usuario,'nome',au.nome,'email',au.email)) item
    from public.eventos_auditoria e left join public.usuarios au on au.id_usuario=e.id_usuario
    where e.id_organizacao=p_id_organizacao and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos') and e.metadados->>'id_usuario'=p_id_usuario::text
      and (e.entidade<>'vinculos_usuario_contratos' or privado.uuid_seguro(e.metadados->>'id_contrato') is null or privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato')))
    order by e.criado_em desc,e.id desc limit v_limite
  ) q;
  return jsonb_build_object('schema_versao','adm01-v1','id_usuario',p_id_usuario,'eventos',v_eventos);
end;
$$;
revoke all on function privado.listar_auditoria_usuario_adm(uuid,uuid,integer) from public, anon;
grant execute on function privado.listar_auditoria_usuario_adm(uuid,uuid,integer) to authenticated;
create or replace function public.listar_auditoria_usuario_adm(p_id_organizacao uuid,p_id_usuario uuid,p_limite integer default 50)
returns jsonb language sql stable security invoker set search_path='' as $$ select privado.listar_auditoria_usuario_adm($1,$2,$3) $$;
revoke all on function public.listar_auditoria_usuario_adm(uuid,uuid,integer) from public, anon;
grant execute on function public.listar_auditoria_usuario_adm(uuid,uuid,integer) to authenticated;

create or replace function privado.definir_vinculo_usuario_v2(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true,p_versao_esperada bigint default null,p_chave_idempotencia text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_chave text:=nullif(btrim(coalesce(p_chave_idempotencia,'')),''); v_payload jsonb; v_hash text; v_comando_id uuid; v_comando_hash text; v_comando_status text; v_comando_resposta jsonb; v_atual public.vinculos_usuarios%rowtype; v_depois public.vinculos_usuarios%rowtype; v_antes jsonb:=null; v_resposta jsonb; v_existia boolean:=false; v_alterou boolean:=false;
begin
 perform privado.validar_administrador_organizacao(p_id_organizacao);
 if p_id_usuario is null then raise sqlstate 'PT422' using message='Usuário inválido.',hint='Selecione um usuário válido.'; end if;
 if v_chave is null or length(v_chave)>200 then raise sqlstate 'PT422' using message='Chave de idempotência inválida.',detail='Informe uma chave não vazia com até 200 caracteres.',hint='Gere uma nova identificação para esta operação.'; end if;
 if not exists(select 1 from public.usuarios u where u.id_usuario=p_id_usuario) then raise sqlstate 'PT422' using message='Usuário não encontrado.',detail='O usuário precisa existir no Supabase Auth antes de receber vínculo.',hint='Use o fluxo de convite/vínculo e tente novamente.'; end if;
 if not exists(select 1 from public.perfis_usuarios p where p.codigo=p_perfil) then raise sqlstate 'PT422' using message='Perfil inválido.',detail='O perfil informado não existe no catálogo oficial.',hint='Selecione um dos perfis retornados pelo backend.'; end if;
 v_payload:=jsonb_build_object('id_usuario',p_id_usuario,'perfil',p_perfil,'escopo_todos_contratos',coalesce(p_escopo_todos_contratos,false),'ativo',coalesce(p_ativo,true),'versao_esperada',p_versao_esperada); v_hash:=md5(v_payload::text);
 insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,expira_em) values(p_id_organizacao,'adm01_definir_vinculo',v_chave,v_hash,'iniciado',now()+interval '24 hours') on conflict(id_organizacao,comando,chave) do nothing returning id into v_comando_id;
 if v_comando_id is null then
  select c.id,c.hash_payload,c.status,c.resposta into v_comando_id,v_comando_hash,v_comando_status,v_comando_resposta from public.comandos_idempotentes c where c.id_organizacao=p_id_organizacao and c.comando='adm01_definir_vinculo' and c.chave=v_chave for update;
  if v_comando_hash is distinct from v_hash then raise sqlstate 'PT409' using message='Esta ação já foi enviada com dados diferentes.',detail='A mesma chave de idempotência não pode representar duas alterações distintas.',hint='Atualize a tela e envie a nova alteração com outra chave.'; end if;
  if v_comando_status='concluido' and v_comando_resposta is not null then return v_comando_resposta; end if;
 end if;
 select v.* into v_atual from public.vinculos_usuarios v where v.id_organizacao=p_id_organizacao and v.id_usuario=p_id_usuario for update; v_existia:=found;
 if v_existia then
  if p_versao_esperada is null or p_versao_esperada<>v_atual.versao_registro then raise sqlstate 'PT409' using message='Este vínculo foi atualizado por outra pessoa.',detail=format('Versão esperada: %s. Versão atual: %s.',coalesce(p_versao_esperada::text,'não informada'),v_atual.versao_registro),hint='Recarregue os dados, revise a versão mais recente e tente novamente.'; end if;
  v_antes:=to_jsonb(v_atual); v_alterou:=v_atual.perfil is distinct from p_perfil or v_atual.escopo_todos_contratos is distinct from coalesce(p_escopo_todos_contratos,false) or v_atual.ativo is distinct from coalesce(p_ativo,true);
  if v_alterou then update public.vinculos_usuarios set perfil=p_perfil,escopo_todos_contratos=coalesce(p_escopo_todos_contratos,false),ativo=coalesce(p_ativo,true),fim_em=case when coalesce(p_ativo,true) then null else coalesce(v_atual.fim_em,now()) end where id=v_atual.id; end if;
 else
  if p_versao_esperada is not null and p_versao_esperada<>0 then raise sqlstate 'PT409' using message='A lista de usuários está desatualizada.',detail='O vínculo ainda não existe, mas foi informada uma versão diferente de zero.',hint='Recarregue os dados antes de criar o vínculo.'; end if;
  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo,fim_em) values(p_id_organizacao,p_id_usuario,p_perfil,coalesce(p_escopo_todos_contratos,false),coalesce(p_ativo,true),case when coalesce(p_ativo,true) then null else now() end); v_alterou:=true;
 end if;
 select v.* into v_depois from public.vinculos_usuarios v where v.id_organizacao=p_id_organizacao and v.id_usuario=p_id_usuario;
 if v_alterou then perform privado.registrar_evento_auditoria(p_id_organizacao,case when v_existia then 'VinculoUsuarioAtualizado' else 'VinculoUsuarioCriado' end,'vinculos_usuarios',v_depois.id,v_antes,to_jsonb(v_depois),jsonb_build_object('id_usuario',p_id_usuario,'chave_idempotencia',v_chave)); end if;
 v_resposta:=jsonb_build_object('schema_versao','adm01-v1','alterado',v_alterou,'vinculo',jsonb_build_object('id',v_depois.id,'id_usuario',v_depois.id_usuario,'id_organizacao',v_depois.id_organizacao,'perfil',v_depois.perfil,'escopo_todos_contratos',v_depois.escopo_todos_contratos,'ativo',v_depois.ativo,'inicio_em',v_depois.inicio_em,'fim_em',v_depois.fim_em,'versao_registro',v_depois.versao_registro,'atualizado_em',v_depois.atualizado_em));
 update public.comandos_idempotentes set status='concluido',resposta=v_resposta where id=v_comando_id; return v_resposta;
end;
$$;
revoke all on function privado.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text) from public, anon;
grant execute on function privado.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text) to authenticated;
create or replace function public.definir_vinculo_usuario_v2(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true,p_versao_esperada bigint default null,p_chave_idempotencia text default null)
returns jsonb language sql security invoker set search_path='' as $$ select privado.definir_vinculo_usuario_v2($1,$2,$3,$4,$5,$6,$7) $$;
revoke all on function public.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text) from public, anon;
grant execute on function public.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text) to authenticated;

create or replace function privado.definir_acesso_contrato_usuario_v2(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true,p_versao_vinculo_esperada bigint default null,p_chave_idempotencia text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_chave text:=nullif(btrim(coalesce(p_chave_idempotencia,'')),''); v_payload jsonb; v_hash text; v_comando_id uuid; v_comando_hash text; v_comando_status text; v_comando_resposta jsonb; v_vinculo public.vinculos_usuarios%rowtype; v_vinculo_depois public.vinculos_usuarios%rowtype; v_acesso_id uuid; v_acesso_ativo boolean; v_acesso_revogado_em timestamptz; v_acesso_existia boolean:=false; v_alterou boolean:=false; v_antes jsonb:=null; v_depois jsonb:=null; v_resposta jsonb;
begin
 perform privado.validar_administrador_organizacao(p_id_organizacao);
 if v_chave is null or length(v_chave)>200 then raise sqlstate 'PT422' using message='Chave de idempotência inválida.',detail='Informe uma chave não vazia com até 200 caracteres.',hint='Gere uma nova identificação para esta operação.'; end if;
 if not exists(select 1 from public.contratos c where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao) then raise sqlstate 'PT422' using message='Contrato inválido.',detail='O contrato informado não pertence à organização selecionada.',hint='Selecione um contrato retornado pelo backend.'; end if;
 if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise sqlstate '42501' using message='Você não tem permissão para administrar este contrato.',detail='O contrato está fora do seu escopo autorizado.',hint='Selecione um contrato ao qual seu usuário tenha acesso.'; end if;
 v_payload:=jsonb_build_object('id_usuario',p_id_usuario,'id_contrato',p_id_contrato,'conceder',coalesce(p_conceder,true),'versao_vinculo_esperada',p_versao_vinculo_esperada); v_hash:=md5(v_payload::text);
 insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,expira_em) values(p_id_organizacao,'adm01_definir_acesso_contrato',v_chave,v_hash,'iniciado',now()+interval '24 hours') on conflict(id_organizacao,comando,chave) do nothing returning id into v_comando_id;
 if v_comando_id is null then
  select c.id,c.hash_payload,c.status,c.resposta into v_comando_id,v_comando_hash,v_comando_status,v_comando_resposta from public.comandos_idempotentes c where c.id_organizacao=p_id_organizacao and c.comando='adm01_definir_acesso_contrato' and c.chave=v_chave for update;
  if v_comando_hash is distinct from v_hash then raise sqlstate 'PT409' using message='Esta ação já foi enviada com dados diferentes.',detail='A mesma chave de idempotência não pode representar duas alterações distintas.',hint='Atualize a tela e envie a nova alteração com outra chave.'; end if;
  if v_comando_status='concluido' and v_comando_resposta is not null then return v_comando_resposta; end if;
 end if;
 select v.* into v_vinculo from public.vinculos_usuarios v where v.id_organizacao=p_id_organizacao and v.id_usuario=p_id_usuario for update;
 if not found then raise sqlstate 'PT422' using message='Usuário sem vínculo com a organização.',detail='Crie o vínculo antes de definir contratos específicos.',hint='Salve primeiro o perfil e o vínculo do usuário.'; end if;
 if p_versao_vinculo_esperada is null or p_versao_vinculo_esperada<>v_vinculo.versao_registro then raise sqlstate 'PT409' using message='O escopo deste usuário foi atualizado por outra pessoa.',detail=format('Versão esperada: %s. Versão atual: %s.',coalesce(p_versao_vinculo_esperada::text,'não informada'),v_vinculo.versao_registro),hint='Recarregue os dados, revise os contratos atuais e tente novamente.'; end if;
 select vc.id,vc.ativo,vc.revogado_em into v_acesso_id,v_acesso_ativo,v_acesso_revogado_em from public.vinculos_usuario_contratos vc where vc.id_vinculo_usuario=v_vinculo.id and vc.id_contrato=p_id_contrato for update; v_acesso_existia:=found;
 if v_acesso_existia then v_antes:=jsonb_build_object('id',v_acesso_id,'id_contrato',p_id_contrato,'ativo',v_acesso_ativo,'revogado_em',v_acesso_revogado_em); end if;
 v_alterou:=(not v_acesso_existia) or v_acesso_ativo is distinct from coalesce(p_conceder,true);
 if v_alterou then
  insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo,revogado_em) values(p_id_organizacao,v_vinculo.id,p_id_contrato,coalesce(p_conceder,true),case when coalesce(p_conceder,true) then null else now() end)
  on conflict(id_vinculo_usuario,id_contrato) do update set ativo=excluded.ativo,revogado_em=excluded.revogado_em returning id,ativo,revogado_em into v_acesso_id,v_acesso_ativo,v_acesso_revogado_em;
  update public.vinculos_usuarios set atualizado_em=now() where id=v_vinculo.id;
 end if;
 select v.* into v_vinculo_depois from public.vinculos_usuarios v where v.id=v_vinculo.id;
 v_depois:=jsonb_build_object('id',v_acesso_id,'id_contrato',p_id_contrato,'ativo',coalesce(v_acesso_ativo,coalesce(p_conceder,true)),'revogado_em',v_acesso_revogado_em);
 if v_alterou then perform privado.registrar_evento_auditoria(p_id_organizacao,case when coalesce(p_conceder,true) then 'AcessoContratoConcedido' else 'AcessoContratoRevogado' end,'vinculos_usuario_contratos',v_acesso_id,v_antes,v_depois,jsonb_build_object('id_usuario',p_id_usuario,'id_contrato',p_id_contrato,'chave_idempotencia',v_chave)); end if;
 v_resposta:=jsonb_build_object('schema_versao','adm01-v1','alterado',v_alterou,'versao_vinculo',v_vinculo_depois.versao_registro,'acesso',v_depois);
 update public.comandos_idempotentes set status='concluido',resposta=v_resposta where id=v_comando_id; return v_resposta;
end;
$$;
revoke all on function privado.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text) from public, anon;
grant execute on function privado.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text) to authenticated;
create or replace function public.definir_acesso_contrato_usuario_v2(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true,p_versao_vinculo_esperada bigint default null,p_chave_idempotencia text default null)
returns jsonb language sql security invoker set search_path='' as $$ select privado.definir_acesso_contrato_usuario_v2($1,$2,$3,$4,$5,$6) $$;
revoke all on function public.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text) from public, anon;
grant execute on function public.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text) to authenticated;

comment on function public.listar_usuarios_adm(uuid,integer,integer,text,text) is 'ADM-01: lista paginada de vínculos de usuários para administradores; contrato adm01-v1.';
comment on function public.definir_vinculo_usuario_v2(uuid,uuid,text,boolean,boolean,bigint,text) is 'ADM-01: cria/edita perfil, situação do vínculo e escopo global com concorrência e idempotência.';
comment on function public.definir_acesso_contrato_usuario_v2(uuid,uuid,uuid,boolean,bigint,text) is 'ADM-01: concede/revoga contrato específico com concorrência do vínculo e idempotência.';
comment on function public.listar_auditoria_usuario_adm(uuid,uuid,integer) is 'ADM-01: histórico auditável de alterações de vínculo e contratos de um usuário.';
