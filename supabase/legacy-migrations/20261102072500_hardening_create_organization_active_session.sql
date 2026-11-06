begin;

create or replace function privado.criar_organizacao(
  p_razao_social text,
  p_nome_fantasia text default null,
  p_cnpj varchar default null,
  p_timezone text default 'America/Sao_Paulo'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_org uuid;
  v_timezone text := 'America/Sao_Paulo';
begin
  if v_usuario is null or not privado.sessao_usuario_ativa() then
    raise exception 'Sua sessão não está mais ativa. Entre novamente para criar uma organização.';
  end if;

  insert into public.organizacoes(razao_social,nome_fantasia,cnpj,timezone)
  values(p_razao_social,p_nome_fantasia,p_cnpj,v_timezone)
  returning id into v_org;

  insert into public.vinculos_usuarios(id_organizacao,id_usuario,perfil,escopo_todos_contratos)
  values(v_org,v_usuario,'administrador',true);

  insert into public.recursos_organizacao(id_organizacao,recurso,habilitado)
  values(v_org,'contaos_1',true);

  perform privado.registrar_evento_auditoria(
    v_org,'OrganizacaoCriada','organizacoes',v_org,null,
    jsonb_build_object('razao_social',p_razao_social,'timezone',v_timezone)
  );
  return v_org;
end;
$$;

commit;
