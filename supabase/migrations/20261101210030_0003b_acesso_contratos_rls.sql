begin;
create or replace function privado.usuario_tem_acesso_contrato(p_id_contrato uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.contratos c join public.vinculos_usuarios v on v.id_organizacao=c.id_organizacao
  where c.id=p_id_contrato and v.id_usuario=auth.uid() and v.ativo=true and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now())
    and (v.escopo_todos_contratos=true or exists(select 1 from public.vinculos_usuario_contratos vc where vc.id_vinculo_usuario=v.id and vc.id_contrato=c.id and vc.ativo=true))
 );
$$;
revoke all on function privado.usuario_tem_acesso_contrato(uuid) from public,anon,authenticated;
grant execute on function privado.usuario_tem_acesso_contrato(uuid) to authenticated;

create or replace function public.definir_vinculo_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_perfil text,p_escopo_todos_contratos boolean default false,p_ativo boolean default true)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not exists(select 1 from public.perfis_usuarios where codigo=p_perfil) then raise exception 'Perfil inválido.'; end if;
 insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
 values(p_id_organizacao,p_id_usuario,p_perfil,p_escopo_todos_contratos,p_ativo)
 on conflict(id_usuario,id_organizacao) do update set perfil=excluded.perfil,escopo_todos_contratos=excluded.escopo_todos_contratos,ativo=excluded.ativo,atualizado_em=now()
 returning id into v_id;
 perform privado.registrar_evento_auditoria(p_id_organizacao,'VinculoUsuarioDefinido','vinculos_usuarios',v_id,null,jsonb_build_object('id_usuario',p_id_usuario,'perfil',p_perfil));
 return v_id;
end;$$;
revoke all on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) from public;
grant execute on function public.definir_vinculo_usuario(uuid,uuid,text,boolean,boolean) to authenticated;

create or replace function public.definir_acesso_contrato_usuario(p_id_organizacao uuid,p_id_usuario uuid,p_id_contrato uuid,p_conceder boolean default true)
returns void language plpgsql security definer set search_path='' as $$
declare v_vinculo uuid;
begin
 if auth.uid() is null or not privado.usuario_possui_perfil(p_id_organizacao,array['administrador']::text[]) then raise exception 'Acesso negado.'; end if;
 if not exists(select 1 from public.contratos where id=p_id_contrato and id_organizacao=p_id_organizacao) then raise exception 'Contrato inválido.'; end if;
 select id into v_vinculo from public.vinculos_usuarios where id_organizacao=p_id_organizacao and id_usuario=p_id_usuario;
 if v_vinculo is null then raise exception 'Usuário sem vínculo.'; end if;
 insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo,revogado_em)
 values(p_id_organizacao,v_vinculo,p_id_contrato,p_conceder,case when p_conceder then null else now() end)
 on conflict(id_vinculo_usuario,id_contrato) do update set ativo=excluded.ativo,revogado_em=excluded.revogado_em;
 perform privado.registrar_evento_auditoria(p_id_organizacao,case when p_conceder then 'AcessoContratoConcedido' else 'AcessoContratoRevogado' end,'vinculos_usuario_contratos',p_id_contrato,null,jsonb_build_object('id_usuario',p_id_usuario));
end;$$;
revoke all on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) from public;
grant execute on function public.definir_acesso_contrato_usuario(uuid,uuid,uuid,boolean) to authenticated;

create policy contratantes_select on public.contratantes for select to authenticated using(privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy contratantes_insert on public.contratantes for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratantes_update on public.contratantes for update to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratos_select on public.contratos for select to authenticated using(privado.usuario_tem_acesso_contrato(id));
create policy contratos_insert on public.contratos for insert to authenticated with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy contratos_update on public.contratos for update to authenticated using(privado.usuario_tem_acesso_contrato(id) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[])) with check(privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
create policy versoes_contrato_select on public.versoes_contrato for select to authenticated using(privado.usuario_tem_acesso_contrato(id_contrato));
create policy versoes_contrato_insert on public.versoes_contrato for insert to authenticated with check(privado.usuario_tem_acesso_contrato(id_contrato) and privado.usuario_possui_perfil(id_organizacao,array['administrador','gestor_contrato']::text[]));
commit;
