begin;
-- Global role matrix is an additional restriction. Existing tenant/contract,
-- specialized approval and workflow checks remain mandatory.
create table privado.rbac_catalogo_acoes (
 recurso text not null, acao text not null,
 primary key(recurso,acao),
 check(recurso ~ '^[a-z][a-z0-9_]{1,63}$'),
 check(acao in ('consultar','criar','editar','excluir','aprovar','apresentar','administrar','processar'))
);
create table privado.rbac_permissoes_perfis (
 perfil text not null references public.perfis_usuarios(codigo),
 recurso text not null, acao text not null, permitido boolean not null default false,
 primary key(perfil,recurso,acao),
 foreign key(recurso,acao) references privado.rbac_catalogo_acoes(recurso,acao)
);
create table privado.rbac_versoes (
 id boolean primary key default true check(id), versao bigint not null check(versao>0),
 atualizado_por uuid references auth.users(id), atualizado_em timestamptz not null default now()
);
create table privado.rbac_comandos (
 request_id uuid primary key, id_usuario uuid not null references auth.users(id),
 payload jsonb not null, resposta jsonb not null, criado_em timestamptz not null default now()
);
alter table privado.rbac_catalogo_acoes enable row level security;
alter table privado.rbac_permissoes_perfis enable row level security;
alter table privado.rbac_versoes enable row level security;
alter table privado.rbac_comandos enable row level security;
revoke all on privado.rbac_catalogo_acoes,privado.rbac_permissoes_perfis,privado.rbac_versoes,privado.rbac_comandos from public,anon,authenticated;
insert into privado.rbac_versoes(id,versao) values(true,1);

create function privado.rbac_permite(p_id_organizacao uuid,p_recurso text,p_acao text,p_id_contrato uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(
 privado.sessao_usuario_ativa()
 and exists(select 1 from privado.rbac_catalogo_acoes c where c.recurso=p_recurso and c.acao=p_acao)
 and exists(select 1 from public.organizacoes o where o.id=p_id_organizacao)
 and privado.usuario_tem_acesso_organizacao(p_id_organizacao)
 and (p_id_contrato is null or exists(select 1 from public.contratos c where c.id=p_id_contrato and c.id_organizacao=p_id_organizacao and privado.usuario_tem_acesso_contrato(c.id)))
 and (privado.usuario_e_administrador_master() or exists(
   select 1 from public.vinculos_usuarios v join privado.rbac_permissoes_perfis p on p.perfil=v.perfil
   where v.id_usuario=auth.uid() and v.id_organizacao=p_id_organizacao
   and v.ativo and v.inicio_em<=now() and (v.fim_em is null or v.fim_em>now())
   and p.recurso=p_recurso and p.acao=p_acao and p.permitido
 )),false)
$$;
revoke all on function privado.rbac_permite(uuid,text,text,uuid) from public,anon;
grant execute on function privado.rbac_permite(uuid,text,text,uuid) to authenticated;

create function privado.exigir_permissao_rbac(p_id_organizacao uuid,p_recurso text,p_acao text,p_id_contrato uuid default null)
returns void language plpgsql stable security invoker set search_path='' as $$
begin
 if not privado.rbac_permite(p_id_organizacao,p_recurso,p_acao,p_id_contrato) then
  raise sqlstate '42501' using message='Você não tem permissão para realizar esta operação.';
 end if;
end $$;
revoke all on function privado.exigir_permissao_rbac(uuid,text,text,uuid) from public,anon;
grant execute on function privado.exigir_permissao_rbac(uuid,text,text,uuid) to authenticated;

create function privado.consultar_permissoes_efetivas(p_id_organizacao uuid,p_id_contrato uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_id_organizacao is null or not privado.sessao_usuario_ativa()
    or not privado.usuario_tem_acesso_organizacao(p_id_organizacao)
    or not exists(select 1 from public.organizacoes where id=p_id_organizacao)
    or (p_id_contrato is not null and not exists(select 1 from public.contratos where id=p_id_contrato and id_organizacao=p_id_organizacao and privado.usuario_tem_acesso_contrato(id))) then
  raise sqlstate '42501' using message='Você não tem acesso às permissões deste contexto.';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('recurso',c.recurso,'acao',c.acao) order by c.recurso,c.acao),'[]'::jsonb)
 into result from privado.rbac_catalogo_acoes c where privado.rbac_permite(p_id_organizacao,c.recurso,c.acao,p_id_contrato);
 return jsonb_build_object('schema_versao','rbac-v1','versao',(select versao from privado.rbac_versoes where id),'master',privado.usuario_e_administrador_master(),'permissoes',result);
end $$;

create function privado.obter_matriz_rbac_master()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not privado.usuario_e_administrador_master() then
  raise sqlstate '42501' using message='Somente o administrador Master pode consultar a matriz de permissões.';
 end if;
 return jsonb_build_object('schema_versao','rbac-v1','versao',(select versao from privado.rbac_versoes where id),
 'permissoes',(select coalesce(jsonb_agg(jsonb_build_object('perfil',p.perfil,'recurso',p.recurso,'acao',p.acao,'permitido',p.permitido) order by p.perfil,p.recurso,p.acao),'[]'::jsonb) from privado.rbac_permissoes_perfis p));
end $$;

create function privado.atualizar_matriz_rbac_master(p_versao_esperada bigint,p_request_id uuid,p_alteracoes jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_versao bigint; v_payload jsonb; v_anterior privado.rbac_comandos%rowtype;
 v_antes jsonb; v_depois jsonb; v_resposta jsonb; v_evento uuid;
begin
 if not privado.usuario_e_administrador_master() then
  raise sqlstate '42501' using message='Somente o administrador Master pode editar a matriz de permissões.';
 end if;
 if p_request_id is null or p_versao_esperada is null or p_alteracoes is null or jsonb_typeof(p_alteracoes)<>'array' then
  raise sqlstate 'PT400' using message='Informe a versão, a operação e uma lista de permissões válida.';
 end if;
 if jsonb_array_length(p_alteracoes) not between 1 and 500 then
  raise sqlstate 'PT400' using message='Altere entre uma e 500 permissões por operação.';
 end if;
 if exists(select 1 from jsonb_array_elements(p_alteracoes) x
 where jsonb_typeof(x)<>'object' or not(x ?& array['perfil','recurso','acao','permitido'])
 or jsonb_typeof(x->'perfil')<>'string' or jsonb_typeof(x->'recurso')<>'string'
 or jsonb_typeof(x->'acao')<>'string' or jsonb_typeof(x->'permitido')<>'boolean'
 or x - array['perfil','recurso','acao','permitido'] <> '{}'::jsonb) then
  raise sqlstate 'PT400' using message='Uma das permissões possui campos inválidos.';
 end if;
 if exists(select 1 from jsonb_array_elements(p_alteracoes) x group by x->>'perfil',x->>'recurso',x->>'acao' having count(*)>1)
 or exists(select 1 from jsonb_array_elements(p_alteracoes) x where not exists(
 select 1 from privado.rbac_permissoes_perfis p where p.perfil=x->>'perfil' and p.recurso=x->>'recurso' and p.acao=x->>'acao')) then
  raise sqlstate 'PT400' using message='Permissão desconhecida ou repetida na operação.';
 end if;
 -- Serialize both optimistic version check and request replay under the same row.
 select versao into v_versao from privado.rbac_versoes where id for update;
 v_payload:=jsonb_build_object('versao_esperada',p_versao_esperada,'alteracoes',p_alteracoes);
 select * into v_anterior from privado.rbac_comandos where request_id=p_request_id;
 if found then
  if v_anterior.id_usuario<>auth.uid() or v_anterior.payload<>v_payload then
   raise sqlstate 'PT409' using message='Esta operação já foi utilizada com outros dados.';
  end if;
  return v_anterior.resposta;
 end if;
 if v_versao<>p_versao_esperada then
  raise sqlstate 'PT409' using message='A matriz foi alterada. Atualize a página antes de salvar.';
 end if;
 select jsonb_agg(to_jsonb(p) order by p.perfil,p.recurso,p.acao) into v_antes
 from privado.rbac_permissoes_perfis p join jsonb_array_elements(p_alteracoes) x
 on p.perfil=x->>'perfil' and p.recurso=x->>'recurso' and p.acao=x->>'acao';
 update privado.rbac_permissoes_perfis p set permitido=(x->>'permitido')::boolean
 from jsonb_array_elements(p_alteracoes) x where p.perfil=x->>'perfil' and p.recurso=x->>'recurso' and p.acao=x->>'acao';
 update privado.rbac_versoes set versao=versao+1,atualizado_por=auth.uid(),atualizado_em=clock_timestamp() where id;
 select jsonb_agg(to_jsonb(p) order by p.perfil,p.recurso,p.acao) into v_depois
 from privado.rbac_permissoes_perfis p join jsonb_array_elements(p_alteracoes) x
 on p.perfil=x->>'perfil' and p.recurso=x->>'recurso' and p.acao=x->>'acao';
 v_evento:=privado.registrar_evento_auditoria(null,'MatrizRbacAtualizada','rbac_permissoes_perfis',p_request_id,v_antes,v_depois,jsonb_build_object('versao_anterior',v_versao,'versao',v_versao+1));
 v_resposta:=jsonb_build_object('schema_versao','rbac-v1','versao',v_versao+1,'request_id',p_request_id,'evento_id',v_evento);
 insert into privado.rbac_comandos(request_id,id_usuario,payload,resposta) values(p_request_id,auth.uid(),v_payload,v_resposta);
 return v_resposta;
end $$;

create function public.consultar_permissoes_efetivas(p_id_organizacao uuid,p_id_contrato uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$select privado.consultar_permissoes_efetivas($1,$2)$$;
create function public.obter_matriz_rbac_master()
returns jsonb language sql stable security invoker set search_path='' as $$select privado.obter_matriz_rbac_master()$$;
create function public.atualizar_matriz_rbac_master(p_versao_esperada bigint,p_request_id uuid,p_alteracoes jsonb)
returns jsonb language sql security invoker set search_path='' as $$select privado.atualizar_matriz_rbac_master($1,$2,$3)$$;
revoke all on function privado.consultar_permissoes_efetivas(uuid,uuid),privado.obter_matriz_rbac_master(),privado.atualizar_matriz_rbac_master(bigint,uuid,jsonb),public.consultar_permissoes_efetivas(uuid,uuid),public.obter_matriz_rbac_master(),public.atualizar_matriz_rbac_master(bigint,uuid,jsonb) from public,anon;
grant execute on function privado.consultar_permissoes_efetivas(uuid,uuid),privado.obter_matriz_rbac_master(),privado.atualizar_matriz_rbac_master(bigint,uuid,jsonb),public.consultar_permissoes_efetivas(uuid,uuid),public.obter_matriz_rbac_master(),public.atualizar_matriz_rbac_master(bigint,uuid,jsonb) to authenticated;

-- Closed V1 catalog and initial permissions. Existing policy/RPC checks remain an upper bound.
insert into privado.rbac_catalogo_acoes values('organizacoes','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','organizacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','organizacoes','consultar',true);
insert into privado.rbac_catalogo_acoes values('organizacoes','administrar');
insert into privado.rbac_permissoes_perfis values('administrador','organizacoes','administrar',true);
insert into privado.rbac_permissoes_perfis values('auditor','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('leitor','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','organizacoes','administrar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','organizacoes','administrar',false);
insert into privado.rbac_catalogo_acoes values('usuarios','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','usuarios','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('leitor','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','usuarios','consultar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','usuarios','consultar',false);
insert into privado.rbac_catalogo_acoes values('usuarios','administrar');
insert into privado.rbac_permissoes_perfis values('administrador','usuarios','administrar',true);
insert into privado.rbac_permissoes_perfis values('auditor','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('leitor','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','usuarios','administrar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','usuarios','administrar',false);
insert into privado.rbac_catalogo_acoes values('auditoria','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','auditoria','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','auditoria','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','auditoria','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','auditoria','consultar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','auditoria','consultar',false);
insert into privado.rbac_catalogo_acoes values('contratantes','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratantes','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratantes','consultar',true);
insert into privado.rbac_catalogo_acoes values('contratantes','criar');
insert into privado.rbac_permissoes_perfis values('administrador','contratantes','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratantes','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('leitor','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratantes','criar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratantes','criar',false);
insert into privado.rbac_catalogo_acoes values('contratantes','editar');
insert into privado.rbac_permissoes_perfis values('administrador','contratantes','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratantes','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('leitor','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratantes','editar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratantes','editar',false);
insert into privado.rbac_catalogo_acoes values('contratos','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratos','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratos','consultar',true);
insert into privado.rbac_catalogo_acoes values('contratos','criar');
insert into privado.rbac_permissoes_perfis values('administrador','contratos','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratos','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('leitor','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratos','criar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratos','criar',false);
insert into privado.rbac_catalogo_acoes values('contratos','editar');
insert into privado.rbac_permissoes_perfis values('administrador','contratos','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','contratos','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('leitor','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','contratos','editar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','contratos','editar',false);
insert into privado.rbac_catalogo_acoes values('orcamentos','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','orcamentos','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','orcamentos','consultar',true);
insert into privado.rbac_catalogo_acoes values('orcamentos','criar');
insert into privado.rbac_permissoes_perfis values('administrador','orcamentos','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','orcamentos','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','orcamentos','criar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','orcamentos','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','orcamentos','criar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','orcamentos','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','orcamentos','criar',false);
insert into privado.rbac_permissoes_perfis values('leitor','orcamentos','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','orcamentos','criar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','orcamentos','criar',false);
insert into privado.rbac_catalogo_acoes values('orcamentos','editar');
insert into privado.rbac_permissoes_perfis values('administrador','orcamentos','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','orcamentos','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','orcamentos','editar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','orcamentos','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','orcamentos','editar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','orcamentos','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','orcamentos','editar',false);
insert into privado.rbac_permissoes_perfis values('leitor','orcamentos','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','orcamentos','editar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','orcamentos','editar',false);
insert into privado.rbac_catalogo_acoes values('orcamentos','aprovar');
insert into privado.rbac_permissoes_perfis values('administrador','orcamentos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('auditor','orcamentos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','orcamentos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','orcamentos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','orcamentos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','orcamentos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','orcamentos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('leitor','orcamentos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','orcamentos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','orcamentos','aprovar',false);
insert into privado.rbac_catalogo_acoes values('normativos','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','normativos','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','normativos','consultar',true);
insert into privado.rbac_catalogo_acoes values('normativos','criar');
insert into privado.rbac_permissoes_perfis values('administrador','normativos','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','normativos','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','normativos','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','normativos','criar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','normativos','criar',false);
insert into privado.rbac_catalogo_acoes values('normativos','editar');
insert into privado.rbac_permissoes_perfis values('administrador','normativos','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','normativos','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','normativos','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','normativos','editar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','normativos','editar',false);
insert into privado.rbac_catalogo_acoes values('normativos','aprovar');
insert into privado.rbac_permissoes_perfis values('administrador','normativos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('auditor','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','normativos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','normativos','aprovar',true);
insert into privado.rbac_permissoes_perfis values('leitor','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','normativos','aprovar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','normativos','aprovar',false);
insert into privado.rbac_catalogo_acoes values('listas','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','listas','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','listas','consultar',true);
insert into privado.rbac_catalogo_acoes values('listas','criar');
insert into privado.rbac_permissoes_perfis values('administrador','listas','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','listas','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','listas','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','listas','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','listas','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','listas','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','listas','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','listas','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','listas','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','listas','criar',false);
insert into privado.rbac_catalogo_acoes values('listas','editar');
insert into privado.rbac_permissoes_perfis values('administrador','listas','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','listas','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','listas','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','listas','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','listas','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','listas','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','listas','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','listas','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','listas','editar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','listas','editar',false);
insert into privado.rbac_catalogo_acoes values('documentos_contrato','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_contrato','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_contrato','consultar',true);
insert into privado.rbac_catalogo_acoes values('documentos_contrato','criar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_contrato','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_contrato','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_contrato','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_contrato','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_contrato','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_contrato','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_contrato','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_contrato','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_contrato','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_contrato','criar',false);
insert into privado.rbac_catalogo_acoes values('documentos_contrato','editar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_contrato','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_contrato','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_contrato','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_contrato','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_contrato','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_contrato','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_contrato','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_contrato','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_contrato','editar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_contrato','editar',false);
insert into privado.rbac_catalogo_acoes values('documentos_competencia','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_competencia','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_competencia','consultar',true);
insert into privado.rbac_catalogo_acoes values('documentos_competencia','criar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_competencia','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_competencia','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_competencia','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_competencia','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_competencia','criar',true);
insert into privado.rbac_catalogo_acoes values('documentos_competencia','editar');
insert into privado.rbac_permissoes_perfis values('administrador','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','documentos_competencia','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','documentos_competencia','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','documentos_competencia','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','documentos_competencia','editar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','documentos_competencia','editar',true);
insert into privado.rbac_catalogo_acoes values('competencias','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','competencias','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','competencias','consultar',true);
insert into privado.rbac_catalogo_acoes values('competencias','criar');
insert into privado.rbac_permissoes_perfis values('administrador','competencias','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','competencias','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('leitor','competencias','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','competencias','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','competencias','criar',false);
insert into privado.rbac_catalogo_acoes values('analises','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','analises','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','analises','consultar',true);
insert into privado.rbac_catalogo_acoes values('analises','criar');
insert into privado.rbac_permissoes_perfis values('administrador','analises','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','analises','criar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','analises','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','analises','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','analises','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','analises','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','analises','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','analises','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','analises','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','analises','criar',false);
insert into privado.rbac_catalogo_acoes values('analises','processar');
insert into privado.rbac_permissoes_perfis values('administrador','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('auditor','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','analises','processar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('leitor','analises','processar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','analises','processar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','analises','processar',true);
insert into privado.rbac_catalogo_acoes values('analises','editar');
insert into privado.rbac_permissoes_perfis values('administrador','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','analises','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','analises','editar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','analises','editar',true);
insert into privado.rbac_catalogo_acoes values('pareceres','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','pareceres','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','pareceres','consultar',true);
insert into privado.rbac_catalogo_acoes values('pareceres','criar');
insert into privado.rbac_permissoes_perfis values('administrador','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','pareceres','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','pareceres','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','pareceres','criar',true);
insert into privado.rbac_catalogo_acoes values('pareceres','aprovar');
insert into privado.rbac_permissoes_perfis values('administrador','pareceres','aprovar',true);
insert into privado.rbac_permissoes_perfis values('auditor','pareceres','aprovar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','pareceres','aprovar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','pareceres','aprovar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','pareceres','aprovar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','pareceres','aprovar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','pareceres','aprovar',true);
insert into privado.rbac_permissoes_perfis values('leitor','pareceres','aprovar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','pareceres','aprovar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','pareceres','aprovar',false);
insert into privado.rbac_catalogo_acoes values('apresentacoes','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','apresentacoes','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','apresentacoes','consultar',true);
insert into privado.rbac_catalogo_acoes values('apresentacoes','aprovar');
insert into privado.rbac_permissoes_perfis values('administrador','apresentacoes','aprovar',true);
insert into privado.rbac_permissoes_perfis values('auditor','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','apresentacoes','aprovar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','apresentacoes','aprovar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('leitor','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','apresentacoes','aprovar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','apresentacoes','aprovar',false);
insert into privado.rbac_catalogo_acoes values('apresentacoes','apresentar');
insert into privado.rbac_permissoes_perfis values('administrador','apresentacoes','apresentar',true);
insert into privado.rbac_permissoes_perfis values('auditor','apresentacoes','apresentar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','apresentacoes','apresentar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','apresentacoes','apresentar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','apresentacoes','apresentar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','apresentacoes','apresentar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','apresentacoes','apresentar',false);
insert into privado.rbac_permissoes_perfis values('leitor','apresentacoes','apresentar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','apresentacoes','apresentar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','apresentacoes','apresentar',false);
insert into privado.rbac_catalogo_acoes values('historico','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','historico','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','historico','consultar',true);
insert into privado.rbac_catalogo_acoes values('historico','criar');
insert into privado.rbac_permissoes_perfis values('administrador','historico','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','historico','criar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','historico','criar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','historico','criar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','historico','criar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','historico','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','historico','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','historico','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','historico','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','historico','criar',false);
insert into privado.rbac_catalogo_acoes values('historico','editar');
insert into privado.rbac_permissoes_perfis values('administrador','historico','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','historico','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('leitor','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','historico','editar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','historico','editar',false);
insert into privado.rbac_catalogo_acoes values('historico','processar');
insert into privado.rbac_permissoes_perfis values('administrador','historico','processar',true);
insert into privado.rbac_permissoes_perfis values('auditor','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('contabilidade','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('financeiro','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','historico','processar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('leitor','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','historico','processar',false);
insert into privado.rbac_permissoes_perfis values('rh_dp','historico','processar',false);
insert into privado.rbac_catalogo_acoes values('arquivos','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','arquivos','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','arquivos','consultar',true);
insert into privado.rbac_catalogo_acoes values('arquivos','criar');
insert into privado.rbac_permissoes_perfis values('administrador','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('auditor','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('leitor','arquivos','criar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','arquivos','criar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','arquivos','criar',true);
insert into privado.rbac_catalogo_acoes values('arquivos','editar');
insert into privado.rbac_permissoes_perfis values('administrador','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('auditor','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('leitor','arquivos','editar',false);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','arquivos','editar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','arquivos','editar',true);
insert into privado.rbac_catalogo_acoes values('dashboard','consultar');
insert into privado.rbac_permissoes_perfis values('administrador','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('auditor','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('contabilidade','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('direcao_aprovador','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('financeiro','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('gestor_contrato','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('juridico_conformidade','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('leitor','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('prestacao_contas','dashboard','consultar',true);
insert into privado.rbac_permissoes_perfis values('rh_dp','dashboard','consultar',true);
create policy rbac_v1_select on public.organizacoes as restrictive for SELECT to authenticated using (privado.rbac_permite(id,'organizacoes','consultar',null::uuid));
create policy rbac_v1_insert on public.recursos_organizacao as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'organizacoes','administrar',null::uuid));
create policy rbac_v1_select on public.recursos_organizacao as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'organizacoes','consultar',null::uuid));
create policy rbac_v1_update on public.recursos_organizacao as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'organizacoes','administrar',null::uuid)) with check (privado.rbac_permite(id_organizacao,'organizacoes','administrar',null::uuid));
create policy rbac_v1_select on public.eventos_auditoria as restrictive for SELECT to authenticated using (((id_organizacao is null and privado.usuario_e_administrador_master()) or (privado.rbac_permite(id_organizacao,'auditoria','consultar',null::uuid))));
create policy rbac_v1_insert on public.contratantes as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'contratantes','criar',null::uuid));
create policy rbac_v1_select on public.contratantes as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'contratantes','consultar',null::uuid));
create policy rbac_v1_update on public.contratantes as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'contratantes','editar',null::uuid)) with check (privado.rbac_permite(id_organizacao,'contratantes','editar',null::uuid));
create policy rbac_v1_insert on public.contratos as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'contratos','criar',null::uuid));
create policy rbac_v1_select on public.contratos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'contratos','consultar',id));
create policy rbac_v1_update on public.contratos as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'contratos','editar',id)) with check (privado.rbac_permite(id_organizacao,'contratos','editar',id));
create policy rbac_v1_insert on public.versoes_contrato as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'contratos','criar',id_contrato));
create policy rbac_v1_select on public.versoes_contrato as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'contratos','consultar',id_contrato));
create policy rbac_v1_insert on public.propostas_orcamentarias as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'orcamentos','criar',id_contrato));
create policy rbac_v1_select on public.propostas_orcamentarias as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'orcamentos','consultar',id_contrato));
create policy rbac_v1_update on public.propostas_orcamentarias as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'orcamentos','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'orcamentos','editar',id_contrato));
create policy rbac_v1_select on public.versoes_proposta as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'orcamentos','consultar',id_contrato));
create policy rbac_v1_insert on public.linhas_orcamentarias as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'orcamentos','criar',id_contrato));
create policy rbac_v1_select on public.linhas_orcamentarias as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'orcamentos','consultar',id_contrato));
create policy rbac_v1_update on public.linhas_orcamentarias as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'orcamentos','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'orcamentos','editar',id_contrato));
create policy rbac_v1_insert on public.fontes_normativas as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'normativos','criar',id_contrato));
create policy rbac_v1_select on public.fontes_normativas as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'normativos','consultar',id_contrato));
create policy rbac_v1_update on public.fontes_normativas as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'normativos','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'normativos','editar',id_contrato));
create policy rbac_v1_insert on public.versoes_fontes_normativas as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'normativos','criar',id_contrato));
create policy rbac_v1_select on public.versoes_fontes_normativas as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'normativos','consultar',id_contrato));
create policy rbac_v1_select on public.aplicabilidades_fonte as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'normativos','consultar',id_contrato));
create policy rbac_v1_insert on public.listas_verificacao as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'listas','criar',id_contrato));
create policy rbac_v1_select on public.listas_verificacao as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'listas','consultar',id_contrato));
create policy rbac_v1_update on public.listas_verificacao as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato));
create policy rbac_v1_select on public.versoes_lista as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'listas','consultar',id_contrato));
create policy rbac_v1_insert on public.itens_lista as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'listas','criar',id_contrato));
create policy rbac_v1_select on public.itens_lista as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'listas','consultar',id_contrato));
create policy rbac_v1_update on public.itens_lista as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato));
create policy rbac_v1_insert on public.regras_conformidade as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'listas','criar',id_contrato));
create policy rbac_v1_select on public.regras_conformidade as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'listas','consultar',id_contrato));
create policy rbac_v1_update on public.regras_conformidade as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'listas','editar',id_contrato));
create policy rbac_v1_insert on public.documentos_contrato as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'documentos_contrato','criar',id_contrato));
create policy rbac_v1_select on public.documentos_contrato as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'documentos_contrato','consultar',id_contrato));
create policy rbac_v1_update on public.documentos_contrato as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'documentos_contrato','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'documentos_contrato','editar',id_contrato));
create policy rbac_v1_select on public.documentos_competencia as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'documentos_competencia','consultar',id_contrato));
create policy rbac_v1_update on public.documentos_competencia as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'documentos_competencia','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'documentos_competencia','editar',id_contrato));
create policy rbac_v1_select on public.competencias as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'competencias','consultar',id_contrato));
create policy rbac_v1_select on public.requisitos_competencia as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_select on public.execucoes_analise as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_select on public.resultados_requisitos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_select on public.evidencias_resultado as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_insert on public.apontamentos_internos as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'analises','criar',id_contrato));
create policy rbac_v1_select on public.apontamentos_internos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_update on public.apontamentos_internos as restrictive for UPDATE to authenticated using (privado.rbac_permite(id_organizacao,'analises','editar',id_contrato)) with check (privado.rbac_permite(id_organizacao,'analises','editar',id_contrato));
create policy rbac_v1_insert on public.analises_apontamentos as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'analises','criar',id_contrato));
create policy rbac_v1_select on public.analises_apontamentos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'analises','consultar',id_contrato));
create policy rbac_v1_insert on public.pareceres_internos as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'pareceres','criar',id_contrato));
create policy rbac_v1_select on public.pareceres_internos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'pareceres','consultar',id_contrato));
create policy rbac_v1_select on public.aprovacoes as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'apresentacoes','consultar',id_contrato));
create policy rbac_v1_select on public.apresentacoes_contratante as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'apresentacoes','consultar',id_contrato));
create policy rbac_v1_select on public.pacotes_competencia as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'apresentacoes','consultar',id_contrato));
create policy rbac_v1_select on public.itens_pacote_competencia as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'apresentacoes','consultar',id_contrato));
create policy rbac_v1_insert on public.relatorios_historicos_contratante as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'historico','criar',id_contrato));
create policy rbac_v1_select on public.relatorios_historicos_contratante as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'historico','consultar',id_contrato));
create policy rbac_v1_select on public.apontamentos_historicos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'historico','consultar',id_contrato));
create policy rbac_v1_select on public.respostas_historicas as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'historico','consultar',id_contrato));
create policy rbac_v1_select on public.desfechos_historicos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'historico','consultar',id_contrato));
create policy rbac_v1_insert on public.arquivos as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'arquivos','criar',id_contrato));
create policy rbac_v1_select on public.arquivos as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));
create policy rbac_v1_insert on public.versoes_documento as restrictive for INSERT to authenticated with check (privado.rbac_permite(id_organizacao,'arquivos','criar',id_contrato));
create policy rbac_v1_select on public.versoes_documento as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));
create policy rbac_v1_select on public.paginas_documento as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));
create policy rbac_v1_select on public.fragmentos_documento as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));
create policy rbac_v1_select on public.processamentos_documento as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));
create policy rbac_v1_select on public.sugestoes_extracao_documento as restrictive for SELECT to authenticated using (privado.rbac_permite(id_organizacao,'arquivos','consultar',id_contrato));

create policy rbac_v1_storage_select on storage.objects as restrictive for select to authenticated
using(bucket_id='contaos-documentos' and exists(select 1 from public.arquivos a where a.bucket=objects.bucket_id and a.path=objects.name and privado.rbac_permite(a.id_organizacao,'arquivos','consultar',a.id_contrato)));

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.listar_usuarios_vinculos_adm(p_id_organizacao uuid, p_pagina integer DEFAULT 1, p_tamanho_pagina integer DEFAULT 25, p_busca text DEFAULT NULL::text, p_ativo boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(greatest(coalesce(p_tamanho_pagina, 25), 1), 100);
  v_offset integer;
  v_busca text := nullif(lower(pg_catalog.btrim(coalesce(p_busca, ''))), '');
  v_total bigint;
  v_itens jsonb;
  v_perfis jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'usuarios','consultar',null::uuid);

  perform privado.validar_administrador_organizacao(p_id_organizacao);
  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
  from public.vinculos_usuarios vu
  join public.usuarios u on u.id_usuario = vu.id_usuario
  where vu.id_organizacao = p_id_organizacao
    and (p_ativo is null or vu.ativo = p_ativo)
    and (
      v_busca is null
      or lower(coalesce(u.nome, '') || ' ' || coalesce(u.email, '') || ' ' || coalesce(vu.perfil, '')) like '%' || v_busca || '%'
    );

  select coalesce(jsonb_agg(x.item order by x.ordem_nome, x.ordem_email, x.id_usuario), '[]'::jsonb)
    into v_itens
  from (
    select
      lower(coalesce(u.nome, u.email, '')) as ordem_nome,
      lower(coalesce(u.email, '')) as ordem_email,
      u.id_usuario,
      jsonb_build_object(
        'id_usuario', u.id_usuario,
        'nome', u.nome,
        'email', u.email,
        'telefone', u.telefone,
        'situacao_usuario', u.situacao,
        'vinculo', jsonb_build_object(
          'id', vu.id,
          'perfil', vu.perfil,
          'escopo_todos_contratos', vu.escopo_todos_contratos,
          'ativo', vu.ativo,
          'inicio_em', vu.inicio_em,
          'fim_em', vu.fim_em,
          'versao_registro', vu.versao_registro,
          'atualizado_em', vu.atualizado_em
        )
      ) as item
    from public.vinculos_usuarios vu
    join public.usuarios u on u.id_usuario = vu.id_usuario
    where vu.id_organizacao = p_id_organizacao
      and (p_ativo is null or vu.ativo = p_ativo)
      and (
        v_busca is null
        or lower(coalesce(u.nome, '') || ' ' || coalesce(u.email, '') || ' ' || coalesce(vu.perfil, '')) like '%' || v_busca || '%'
      )
    order by lower(coalesce(u.nome, u.email, '')), lower(coalesce(u.email, '')), u.id_usuario
    limit v_tamanho offset v_offset
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('codigo', p.codigo, 'nome', p.nome, 'descricao', p.descricao) order by p.nome, p.codigo), '[]'::jsonb)
    into v_perfis
  from public.perfis_usuarios p;

  return jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens,
    'perfis_disponiveis', v_perfis
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.listar_escopo_contratos_usuario_adm(p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer DEFAULT 1, p_tamanho_pagina integer DEFAULT 25, p_busca text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(greatest(coalesce(p_tamanho_pagina, 25), 1), 100);
  v_offset integer;
  v_busca text := nullif(pg_catalog.btrim(coalesce(p_busca, '')), '');
  v_total bigint;
  v_vinculo uuid;
  v_todos boolean := false;
  v_itens jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'usuarios','consultar',null::uuid);

  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar o escopo contratual.';
  end if;

  if p_id_usuario is not null then
    select vu.id, vu.escopo_todos_contratos
      into v_vinculo, v_todos
      from public.vinculos_usuarios vu
     where vu.id_organizacao = p_id_organizacao
       and vu.id_usuario = p_id_usuario;

    if v_vinculo is null then
      raise exception using errcode = 'PT404', message = 'Vínculo de usuário não encontrado nesta organização.';
    end if;
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
    from public.contratos c
   where c.id_organizacao = p_id_organizacao
     and privado.usuario_tem_acesso_contrato(c.id)
     and (
       v_busca is null
       or c.numero ilike '%' || v_busca || '%'
       or c.objeto ilike '%' || v_busca || '%'
     );

  select coalesce(jsonb_agg(x.item order by x.numero, x.id), '[]'::jsonb)
    into v_itens
    from (
      select c.numero, c.id,
             jsonb_build_object(
               'id', c.id,
               'numero', c.numero,
               'objeto', c.objeto,
               'situacao', c.situacao,
               'criticidade', c.criticidade,
               'selecionado', coalesce(vc.ativo, false),
               'acesso_efetivo', coalesce(v_todos, false) or coalesce(vc.ativo, false)
             ) as item
        from public.contratos c
        left join public.vinculos_usuario_contratos vc
          on v_vinculo is not null
         and vc.id_vinculo_usuario = v_vinculo
         and vc.id_contrato = c.id
       where c.id_organizacao = p_id_organizacao
         and privado.usuario_tem_acesso_contrato(c.id)
         and (
           v_busca is null
           or c.numero ilike '%' || v_busca || '%'
           or c.objeto ilike '%' || v_busca || '%'
         )
       order by c.numero, c.id
       limit v_tamanho offset v_offset
    ) x;

  return jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'id_usuario', p_id_usuario,
    'escopo_todos_contratos', coalesce(v_todos, false),
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.listar_auditoria_vinculo_usuario_adm(p_id_organizacao uuid, p_id_usuario uuid, p_pagina integer DEFAULT 1, p_tamanho_pagina integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_pagina integer := greatest(coalesce(p_pagina, 1), 1);
  v_tamanho integer := least(greatest(coalesce(p_tamanho_pagina, 20), 1), 50);
  v_offset integer;
  v_total bigint;
  v_itens jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'usuarios','consultar',null::uuid);

  perform privado.validar_administrador_organizacao(p_id_organizacao);

  if not exists (
    select 1
    from public.vinculos_usuarios vu
    where vu.id_organizacao = p_id_organizacao
      and vu.id_usuario = p_id_usuario
  ) then
    raise sqlstate 'PT404' using
      message = 'Vínculo de usuário não encontrado nesta organização.',
      hint = 'Atualize a lista e tente novamente.';
  end if;

  v_offset := (v_pagina - 1) * v_tamanho;

  select count(*) into v_total
  from public.eventos_auditoria e
  where e.id_organizacao = p_id_organizacao
    and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
    and e.metadados->>'id_usuario' = p_id_usuario::text
    and (
      e.entidade <> 'vinculos_usuario_contratos'
      or privado.uuid_seguro(e.metadados->>'id_contrato') is null
      or privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato'))
    );

  select coalesce(jsonb_agg(x.item order by x.criado_em desc, x.id desc), '[]'::jsonb)
    into v_itens
  from (
    select e.criado_em, e.id,
      jsonb_build_object(
        'id', e.id,
        'correlation_id', e.correlation_id,
        'evento', e.evento,
        'entidade', e.entidade,
        'id_entidade', e.id_entidade,
        'id_usuario_ator', e.id_usuario,
        'ator_nome', ua.nome,
        'ator_email', ua.email,
        'antes',
          case
            when jsonb_typeof(e.antes->'escopo_contratos') = 'array' then
              jsonb_set(
                e.antes,
                '{escopo_contratos}',
                coalesce((
                  select jsonb_agg(j.elem order by j.elem->>'id_contrato')
                  from jsonb_array_elements(e.antes->'escopo_contratos') as j(elem)
                  where privado.uuid_seguro(j.elem->>'id_contrato') is not null
                    and privado.usuario_tem_acesso_contrato(privado.uuid_seguro(j.elem->>'id_contrato'))
                ), '[]'::jsonb),
                true
              )
            else e.antes
          end,
        'depois',
          case
            when jsonb_typeof(e.depois->'escopo_contratos') = 'array' then
              jsonb_set(
                e.depois,
                '{escopo_contratos}',
                coalesce((
                  select jsonb_agg(j.elem order by j.elem->>'id_contrato')
                  from jsonb_array_elements(e.depois->'escopo_contratos') as j(elem)
                  where privado.uuid_seguro(j.elem->>'id_contrato') is not null
                    and privado.usuario_tem_acesso_contrato(privado.uuid_seguro(j.elem->>'id_contrato'))
                ), '[]'::jsonb),
                true
              )
            else e.depois
          end,
        'metadados', privado.redigir_metadados_auditoria_adm(e.metadados),
        'criado_em', e.criado_em
      ) as item
    from public.eventos_auditoria e
    left join public.usuarios ua on ua.id_usuario = e.id_usuario
    where e.id_organizacao = p_id_organizacao
      and e.entidade in ('vinculos_usuarios','vinculos_usuario_contratos')
      and e.metadados->>'id_usuario' = p_id_usuario::text
      and (
        e.entidade <> 'vinculos_usuario_contratos'
        or privado.uuid_seguro(e.metadados->>'id_contrato') is null
        or privado.usuario_tem_acesso_contrato(privado.uuid_seguro(e.metadados->>'id_contrato'))
      )
    order by e.criado_em desc, e.id desc
    limit v_tamanho offset v_offset
  ) x;

  return jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'id_usuario', p_id_usuario,
    'pagina', v_pagina,
    'tamanho_pagina', v_tamanho,
    'total', v_total,
    'total_paginas', case when v_total = 0 then 0 else pg_catalog.ceil(v_total::numeric / v_tamanho)::integer end,
    'itens', v_itens
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.validar_administrador_organizacao(p_id_organizacao uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'usuarios','consultar',null::uuid);

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
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.salvar_vinculo_usuario_adm(p_id_organizacao uuid, p_id_usuario uuid, p_email text, p_perfil text, p_escopo_todos_contratos boolean, p_ativo boolean, p_ids_contratos_ativar uuid[], p_ids_contratos_revogar uuid[], p_versao_esperada bigint, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id_usuario uuid := p_id_usuario;
  v_email text := nullif(lower(pg_catalog.btrim(coalesce(p_email, ''))), '');
  v_perfil text := nullif(pg_catalog.btrim(coalesce(p_perfil, '')), '');
  v_todos boolean := coalesce(p_escopo_todos_contratos, false);
  v_ativo boolean := coalesce(p_ativo, true);
  v_ids_ativar uuid[];
  v_ids_revogar uuid[];
  v_ids_validar uuid[];
  v_chave text := nullif(pg_catalog.btrim(coalesce(p_chave_idempotencia, '')), '');
  v_hash text;
  v_comando_id uuid;
  v_comando_status text;
  v_comando_hash text;
  v_comando_resposta jsonb;
  v_vinculo_id uuid;
  v_versao_atual bigint;
  v_antes jsonb;
  v_depois jsonb;
  v_escopo_antes jsonb;
  v_escopo_depois jsonb;
  v_evento_id uuid;
  v_correlation_id uuid;
  v_resposta jsonb;
  v_qtd_contratos integer;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'usuarios','administrar',null::uuid);

  if not privado.usuario_possui_perfil(p_id_organizacao, array['administrador']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para administrar usuários desta organização.';
  end if;

  if v_id_usuario is null then
    if v_email is null then
      raise exception using errcode = 'PT400', message = 'Informe um usuário ou e-mail válido.';
    end if;
    select u.id_usuario
      into v_id_usuario
      from public.usuarios u
     where lower(u.email) = v_email
     order by u.id_usuario
     limit 1;
  else
    if not exists (select 1 from public.usuarios u where u.id_usuario = v_id_usuario) then
      v_id_usuario := null;
    elsif v_email is not null and not exists (
      select 1 from public.usuarios u where u.id_usuario = v_id_usuario and lower(u.email) = v_email
    ) then
      raise exception using errcode = 'PT400', message = 'O e-mail informado não corresponde ao usuário selecionado.';
    end if;
  end if;

  if v_id_usuario is null then
    raise exception using
      errcode = 'PT404',
      message = 'Usuário ContaOS não encontrado.',
      hint = 'Vincule uma conta já existente no ContaOS.';
  end if;

  if v_perfil is null or not exists (select 1 from public.perfis_usuarios p where p.codigo = v_perfil) then
    raise exception using errcode = 'PT400', message = 'Perfil de acesso inválido.';
  end if;

  if v_chave is null or pg_catalog.length(v_chave) > 200 then
    raise exception using errcode = 'PT400', message = 'Chave de idempotência inválida.';
  end if;

  select coalesce(array_agg(x order by x), array[]::uuid[])
    into v_ids_ativar
    from (select distinct unnest(coalesce(p_ids_contratos_ativar, array[]::uuid[])) x) d;

  select coalesce(array_agg(x order by x), array[]::uuid[])
    into v_ids_revogar
    from (select distinct unnest(coalesce(p_ids_contratos_revogar, array[]::uuid[])) x) d;

  if exists (
    select 1
      from unnest(v_ids_ativar) a(id)
      join unnest(v_ids_revogar) r(id) using(id)
  ) then
    raise exception using errcode = 'PT400', message = 'O mesmo contrato não pode ser ativado e revogado na mesma operação.';
  end if;

  if v_todos or not v_ativo then
    v_ids_ativar := array[]::uuid[];
    v_ids_revogar := array[]::uuid[];
  end if;

  select coalesce(array_agg(x order by x), array[]::uuid[])
    into v_ids_validar
    from (
      select unnest(v_ids_ativar) x
      union
      select unnest(v_ids_revogar) x
    ) u;

  select count(*) into v_qtd_contratos
    from public.contratos c
   where c.id_organizacao = p_id_organizacao
     and c.id = any(v_ids_validar)
     and privado.usuario_tem_acesso_contrato(c.id);

  if v_qtd_contratos <> cardinality(v_ids_validar) then
    raise exception using errcode = 'PT400', message = 'Um ou mais contratos informados não pertencem ao seu escopo nesta organização.';
  end if;

  v_hash := pg_catalog.md5(jsonb_build_object(
    'id_usuario', v_id_usuario,
    'perfil', v_perfil,
    'escopo_todos_contratos', v_todos,
    'ativo', v_ativo,
    'ids_contratos_ativar', to_jsonb(v_ids_ativar),
    'ids_contratos_revogar', to_jsonb(v_ids_revogar),
    'versao_esperada', p_versao_esperada
  )::text);

  insert into public.comandos_idempotentes(id_organizacao, comando, chave, hash_payload, status, expira_em)
  values(p_id_organizacao, 'adm01.salvar_vinculo_usuario.v2', v_chave, v_hash, 'iniciado', now() + interval '24 hours')
  on conflict(id_organizacao, comando, chave) do nothing
  returning id into v_comando_id;

  if v_comando_id is null then
    select c.id, c.status, c.hash_payload, c.resposta
      into v_comando_id, v_comando_status, v_comando_hash, v_comando_resposta
      from public.comandos_idempotentes c
     where c.id_organizacao = p_id_organizacao
       and c.comando = 'adm01.salvar_vinculo_usuario.v2'
       and c.chave = v_chave
     for update;

    if v_comando_hash is distinct from v_hash then
      raise exception using errcode = 'PT409', message = 'Esta chave de operação já foi usada com dados diferentes.';
    end if;

    if v_comando_status = 'concluido' and v_comando_resposta is not null then
      return v_comando_resposta;
    end if;

    if v_comando_status = 'iniciado' then
      raise exception using errcode = 'PT409', message = 'Esta operação já está em processamento. Atualize a tela antes de tentar novamente.';
    end if;

    update public.comandos_idempotentes
       set status = 'iniciado', resposta = null
     where id = v_comando_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_id_organizacao::text || ':' || v_id_usuario::text, 0)
  );

  select vu.id, vu.versao_registro, to_jsonb(vu)
    into v_vinculo_id, v_versao_atual, v_antes
    from public.vinculos_usuarios vu
   where vu.id_organizacao = p_id_organizacao
     and vu.id_usuario = v_id_usuario
   for update;

  if v_vinculo_id is null then
    if p_versao_esperada is not null then
      raise exception using errcode = 'PT409', message = 'O vínculo mudou desde a última leitura. Atualize a tela e tente novamente.';
    end if;
  else
    if p_versao_esperada is null or p_versao_esperada <> v_versao_atual then
      raise exception using errcode = 'PT409', message = 'Este vínculo foi atualizado por outra pessoa. Atualize a tela, confira a versão mais recente e tente novamente.';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id_contrato', vc.id_contrato, 'ativo', vc.ativo) order by vc.id_contrato), '[]'::jsonb)
    into v_escopo_antes
    from public.vinculos_usuario_contratos vc
   where vc.id_vinculo_usuario = v_vinculo_id;

  if v_vinculo_id is null then
    insert into public.vinculos_usuarios(
      id_organizacao, id_usuario, perfil, escopo_todos_contratos, ativo, fim_em
    )
    values(
      p_id_organizacao, v_id_usuario, v_perfil, v_todos, v_ativo,
      case when v_ativo then null else pg_catalog.clock_timestamp() end
    )
    returning id into v_vinculo_id;
  else
    update public.vinculos_usuarios
       set perfil = v_perfil,
           escopo_todos_contratos = v_todos,
           ativo = v_ativo,
           fim_em = case
             when v_ativo then null
             else coalesce(fim_em, pg_catalog.clock_timestamp())
           end
     where id = v_vinculo_id;
  end if;

  if v_todos or not v_ativo then
    update public.vinculos_usuario_contratos
       set ativo = false,
           revogado_em = coalesce(revogado_em, pg_catalog.clock_timestamp())
     where id_vinculo_usuario = v_vinculo_id
       and ativo = true;
  else
    insert into public.vinculos_usuario_contratos(
      id_organizacao, id_vinculo_usuario, id_contrato, ativo, revogado_em
    )
    select p_id_organizacao, v_vinculo_id, x, true, null
      from unnest(v_ids_ativar) x
    on conflict(id_vinculo_usuario, id_contrato)
    do update set ativo = true, revogado_em = null;

    update public.vinculos_usuario_contratos
       set ativo = false,
           revogado_em = coalesce(revogado_em, pg_catalog.clock_timestamp())
     where id_vinculo_usuario = v_vinculo_id
       and id_contrato = any(v_ids_revogar)
       and ativo = true;
  end if;

  select to_jsonb(vu)
    into v_depois
    from public.vinculos_usuarios vu
   where vu.id = v_vinculo_id;

  select coalesce(jsonb_agg(jsonb_build_object('id_contrato', vc.id_contrato, 'ativo', vc.ativo) order by vc.id_contrato), '[]'::jsonb)
    into v_escopo_depois
    from public.vinculos_usuario_contratos vc
   where vc.id_vinculo_usuario = v_vinculo_id;

  v_evento_id := privado.registrar_evento_auditoria(
    p_id_organizacao,
    'VinculoUsuarioAdministrativoSalvo',
    'vinculos_usuarios',
    v_vinculo_id,
    jsonb_build_object('vinculo', v_antes, 'escopo_contratos', v_escopo_antes),
    jsonb_build_object('vinculo', v_depois, 'escopo_contratos', v_escopo_depois),
    jsonb_build_object(
      'id_usuario', v_id_usuario,
      'chave_idempotencia', v_chave,
      'ids_contratos_ativar', to_jsonb(v_ids_ativar),
      'ids_contratos_revogar', to_jsonb(v_ids_revogar)
    )
  );

  select e.correlation_id into v_correlation_id
    from public.eventos_auditoria e
   where e.id = v_evento_id;

  v_resposta := jsonb_build_object(
    'schema_versao', 'adm01-v2',
    'correlation_id', v_correlation_id,
    'id_usuario', v_id_usuario,
    'vinculo', v_depois
  );

  update public.comandos_idempotentes
     set status = 'concluido', resposta = v_resposta
   where id = v_comando_id;

  return v_resposta;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.atualizar_contratante(p_id_organizacao uuid, p_id_contratante uuid, p_versao_esperada bigint, p_tipo_pessoa text, p_documento text, p_razao_social text, p_nome_fantasia text, p_contato jsonb, p_situacao text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_antes public.contratantes%rowtype;
  v_depois public.contratantes%rowtype;
  v_campos text[] := array[]::text[];
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'contratantes','editar',null::uuid);

  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Sua sessão não é válida para editar este contratante.';
  end if;
  if not privado.usuario_possui_perfil(p_id_organizacao,array['administrador','gestor_contrato']::text[]) then
    raise exception using errcode = '42501', message = 'Você não tem permissão para editar contratantes nesta organização.';
  end if;
  if p_versao_esperada is null or p_versao_esperada < 1 then
    raise exception using errcode = 'PT422', message = 'A versão informada para edição é inválida.';
  end if;
  if nullif(trim(coalesce(p_razao_social,'')), '') is null then
    raise exception using errcode = 'PT422', message = 'Informe a razão social do contratante.';
  end if;
  select * into v_antes from public.contratantes where id=p_id_contratante and id_organizacao=p_id_organizacao for update;
  if not found then
    raise exception using errcode = 'PT404', message = 'Contratante não encontrado nesta organização.';
  end if;
  if v_antes.versao_registro <> p_versao_esperada then
    raise exception using errcode = 'PT409', message = 'Este contratante foi atualizado por outra pessoa. Recarregue os dados e revise suas alterações.';
  end if;
  update public.contratantes
     set tipo_pessoa=p_tipo_pessoa,
         documento=nullif(trim(coalesce(p_documento,'')), ''),
         razao_social=trim(p_razao_social),
         nome_fantasia=nullif(trim(coalesce(p_nome_fantasia,'')), ''),
         contato=coalesce(p_contato,'{}'::jsonb),
         situacao=p_situacao
   where id=p_id_contratante and id_organizacao=p_id_organizacao
  returning * into v_depois;
  if v_antes.tipo_pessoa is distinct from v_depois.tipo_pessoa then v_campos:=array_append(v_campos,'tipo_pessoa'); end if;
  if v_antes.documento is distinct from v_depois.documento then v_campos:=array_append(v_campos,'documento'); end if;
  if v_antes.razao_social is distinct from v_depois.razao_social then v_campos:=array_append(v_campos,'razao_social'); end if;
  if v_antes.nome_fantasia is distinct from v_depois.nome_fantasia then v_campos:=array_append(v_campos,'nome_fantasia'); end if;
  if v_antes.contato is distinct from v_depois.contato then v_campos:=array_append(v_campos,'contato'); end if;
  if v_antes.situacao is distinct from v_depois.situacao then v_campos:=array_append(v_campos,'situacao'); end if;
  perform privado.registrar_evento_auditoria(
    p_id_organizacao,'ContratanteAtualizado','contratantes',p_id_contratante,
    jsonb_build_object('tipo_pessoa',v_antes.tipo_pessoa,'razao_social',v_antes.razao_social,'nome_fantasia',v_antes.nome_fantasia,'situacao',v_antes.situacao,'versao_registro',v_antes.versao_registro),
    jsonb_build_object('tipo_pessoa',v_depois.tipo_pessoa,'razao_social',v_depois.razao_social,'nome_fantasia',v_depois.nome_fantasia,'situacao',v_depois.situacao,'versao_registro',v_depois.versao_registro),
    jsonb_build_object('versao_anterior',v_antes.versao_registro,'versao_nova',v_depois.versao_registro,'campos_alterados',to_jsonb(v_campos))
  );
  return jsonb_build_object('schema_versao','v103-v1','contratante',jsonb_build_object(
    'id',v_depois.id,'id_organizacao',v_depois.id_organizacao,'tipo_pessoa',v_depois.tipo_pessoa,'documento',v_depois.documento,
    'razao_social',v_depois.razao_social,'nome_fantasia',v_depois.nome_fantasia,'contato',v_depois.contato,'situacao',v_depois.situacao,
    'versao_registro',v_depois.versao_registro,'atualizado_em',v_depois.atualizado_em));
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.obter_resumo_dashboard(p_id_organizacao uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_organizacao jsonb;
  v_resumo jsonb;
  v_contratos_por_situacao jsonb;
  v_competencias_por_situacao jsonb;
  v_proximos_prazos jsonb;
  v_atencoes_prioritarias jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'dashboard','consultar',null::uuid);

  if auth.uid() is null
     or not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then
    raise exception using
      errcode = '42501',
      message = 'Acesso negado ao resumo desta organização.';
  end if;

  select jsonb_build_object(
           'id', o.id,
           'razao_social', o.razao_social,
           'nome_fantasia', o.nome_fantasia,
           'situacao', o.situacao
         )
    into v_organizacao
    from public.organizacoes o
   where o.id = p_id_organizacao;

  if v_organizacao is null then
    raise exception using
      errcode = '42501',
      message = 'Acesso negado ao resumo desta organização.';
  end if;

  select jsonb_build_object(
    'contratos_visiveis', (select count(*) from public.contratos c where c.id_organizacao = p_id_organizacao),
    'contratos_ativos', (select count(*) from public.contratos c where c.id_organizacao = p_id_organizacao and c.situacao = 'ativo'),
    'competencias_em_fluxo', (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.situacao not in ('validada','encerrada','cancelada')),
    'competencias_exigem_atencao', (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.situacao in ('pendente_correcao','com_apontamentos')),
    'itens_com_prazo_vencido',
      (select count(*) from public.competencias c where c.id_organizacao = p_id_organizacao and c.data_limite is not null and c.data_limite < (now() at time zone 'America/Sao_Paulo')::date and c.situacao not in ('validada','encerrada','cancelada'))
      + (select count(*) from public.tarefas_diligencia t where t.id_organizacao = p_id_organizacao and t.prazo is not null and t.prazo < (now() at time zone 'America/Sao_Paulo')::date and t.status in ('pendente','em_execucao'))
      + (select count(*) from public.nao_conformidades n where n.id_organizacao = p_id_organizacao and n.prazo is not null and n.prazo < (now() at time zone 'America/Sao_Paulo')::date and n.status in ('aberta','em_analise','em_remediacao')),
    'atencoes_abertas',
      (select count(*) from public.apontamentos_internos a where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_tratamento'))
      + (select count(*) from public.apontamentos_contratante a where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_analise','procedente','em_tratamento','contestado','contestado_aprovado'))
      + (select count(*) from public.nao_conformidades n where n.id_organizacao = p_id_organizacao and n.status in ('aberta','em_analise','em_remediacao'))
  ) into v_resumo;

  select coalesce(jsonb_agg(jsonb_build_object('situacao', x.situacao, 'quantidade', x.quantidade) order by x.situacao),'[]'::jsonb)
    into v_contratos_por_situacao
    from (select c.situacao, count(*)::bigint as quantidade from public.contratos c where c.id_organizacao = p_id_organizacao group by c.situacao) x;

  select coalesce(jsonb_agg(jsonb_build_object('situacao', x.situacao, 'quantidade', x.quantidade) order by x.situacao),'[]'::jsonb)
    into v_competencias_por_situacao
    from (select c.situacao, count(*)::bigint as quantidade from public.competencias c where c.id_organizacao = p_id_organizacao group by c.situacao) x;

  select coalesce(jsonb_agg(to_jsonb(x) - 'ordem_criticidade' order by x.prazo asc, x.ordem_criticidade desc, x.tipo, x.id),'[]'::jsonb)
    into v_proximos_prazos
    from (
      select * from (
        select 'competencia'::text as tipo, c.id, c.id_contrato, ct.numero as contrato_numero,
               ('Competência ' || pg_catalog.to_char(c.competencia_referencia, 'MM/YYYY'))::text as titulo,
               c.data_limite as prazo, c.situacao as status, ct.criticidade as criticidade,
               case ct.criticidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end as ordem_criticidade
          from public.competencias c join public.contratos ct on ct.id = c.id_contrato
         where c.id_organizacao = p_id_organizacao and c.data_limite is not null and c.situacao not in ('validada','encerrada','cancelada')
        union all
        select 'tarefa_diligencia'::text, t.id, t.id_contrato, ct.numero, pg_catalog.left(t.descricao, 180), t.prazo, t.status, t.prioridade,
               case t.prioridade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end
          from public.tarefas_diligencia t join public.contratos ct on ct.id = t.id_contrato
         where t.id_organizacao = p_id_organizacao and t.prazo is not null and t.status in ('pendente','em_execucao')
        union all
        select 'nao_conformidade'::text, n.id, n.id_contrato, ct.numero, pg_catalog.left(n.descricao, 180), n.prazo, n.status, n.severidade,
               case n.severidade when 'critica' then 4 when 'alta' then 3 when 'media' then 2 else 1 end
          from public.nao_conformidades n left join public.contratos ct on ct.id = n.id_contrato
         where n.id_organizacao = p_id_organizacao and n.prazo is not null and n.status in ('aberta','em_analise','em_remediacao')
      ) z order by z.prazo asc, z.ordem_criticidade desc, z.tipo, z.id limit 8
    ) x;

  select coalesce(jsonb_agg(to_jsonb(x) - 'ordem_severidade' order by x.ordem_severidade desc, x.criado_em desc, x.tipo, x.id),'[]'::jsonb)
    into v_atencoes_prioritarias
    from (
      select * from (
        select 'apontamento_interno'::text as tipo, a.id, a.id_contrato, ct.numero as contrato_numero, a.id_competencia,
               pg_catalog.left(a.descricao, 220) as descricao, a.severidade, a.status, null::date as prazo, a.criado_em,
               case a.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end as ordem_severidade
          from public.apontamentos_internos a join public.contratos ct on ct.id = a.id_contrato
         where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_tratamento')
        union all
        select 'apontamento_contratante'::text, a.id, a.id_contrato, ct.numero, a.id_competencia,
               pg_catalog.left(a.descricao, 220), a.severidade, a.status, null::date, a.criado_em,
               case a.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end
          from public.apontamentos_contratante a join public.contratos ct on ct.id = a.id_contrato
         where a.id_organizacao = p_id_organizacao and a.status in ('aberto','em_analise','procedente','em_tratamento','contestado','contestado_aprovado')
        union all
        select 'nao_conformidade'::text, n.id, n.id_contrato, ct.numero, n.id_competencia,
               pg_catalog.left(n.descricao, 220), n.severidade, n.status, n.prazo, n.criado_em,
               case n.severidade when 'critica' then 5 when 'alta' then 4 when 'media' then 3 when 'baixa' then 2 else 1 end
          from public.nao_conformidades n left join public.contratos ct on ct.id = n.id_contrato
         where n.id_organizacao = p_id_organizacao and n.status in ('aberta','em_analise','em_remediacao')
      ) z order by z.ordem_severidade desc, z.criado_em desc, z.tipo, z.id limit 8
    ) x;

  return jsonb_build_object(
    'schema_versao', 'sys05-v1',
    'gerado_em', public.formatar_data_hora_br(now()),
    'organizacao', v_organizacao,
    'resumo', v_resumo,
    'contratos_por_situacao', v_contratos_por_situacao,
    'competencias_por_situacao', v_competencias_por_situacao,
    'proximos_prazos', v_proximos_prazos,
    'atencoes_prioritarias', v_atencoes_prioritarias
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.salvar_fonte_normativa_v107(p_id_organizacao uuid, p_id_contrato uuid, p_id_fonte uuid, p_tipo text, p_titulo text, p_referencia text, p_descricao text, p_situacao text, p_versao_esperada bigint, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.fontes_normativas%rowtype; v_antes jsonb; v_cmd jsonb; v_contexto jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'normativos',case when p_id_fonte is null then 'criar' else 'editar' end,null::uuid);

  perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,false);
  if nullif(btrim(p_tipo),'') is null or nullif(btrim(p_titulo),'') is null or p_situacao is null or p_situacao not in('rascunho','ativa','inativa','revogada') then
    raise exception using errcode='PT400',message='Informe tipo, título e situação válidos.';
  end if;
  -- Autorização do registro antes de cache, inclusive em replays.
  if p_id_fonte is not null then
    select * into v from public.fontes_normativas where id=p_id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from p_id_contrato;
    if v.id is null then raise exception using errcode='PT404',message='Fonte normativa não encontrada neste escopo.'; end if;
    if p_situacao is distinct from v.situacao then perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true); end if;
  elsif p_situacao<>'rascunho' or p_versao_esperada is not null then
    raise exception using errcode='PT400',message='Uma nova fonte deve iniciar como rascunho.';
  end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.salvar_fonte',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_fonte,p_tipo,p_titulo,p_referencia,p_descricao,p_situacao,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  if p_id_fonte is null then
    insert into public.fontes_normativas(id_organizacao,id_contrato,tipo,titulo,referencia,descricao,situacao)
      values(p_id_organizacao,p_id_contrato,btrim(p_tipo),btrim(p_titulo),p_referencia,p_descricao,'rascunho') returning * into v;
  else
    select * into v from public.fontes_normativas where id=p_id_fonte for update;
    if p_versao_esperada is null or v.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='Esta fonte foi atualizada. Atualize a tela antes de salvar.'; end if;
    if p_situacao is distinct from v.situacao then perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true); end if;
    if p_situacao='ativa' and not exists(select 1 from public.versoes_fontes_normativas where id_fonte=v.id and aprovado_em is not null) then
      raise exception using errcode='PT400',message='A fonte precisa de uma versão aprovada para ser ativada.';
    end if;
    v_antes:=to_jsonb(v);
    v_contexto:=privado.v107_capturar(p_id_organizacao,p_id_contrato);
    update public.fontes_normativas set tipo=btrim(p_tipo),titulo=btrim(p_titulo),referencia=p_referencia,descricao=p_descricao,situacao=p_situacao where id=v.id returning * into v;
    perform privado.v107_invalidar(v_contexto,v.id);
  end if;
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107FonteSalva','fontes_normativas',v.id,v_antes,to_jsonb(v),jsonb_build_object('fonte',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.registrar_versao_fonte_v107(p_id_organizacao uuid, p_id_fonte uuid, p_inicio_vigencia date, p_fim_vigencia date, p_id_arquivo uuid, p_conteudo_texto text, p_metadados jsonb, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare f public.fontes_normativas%rowtype; v public.versoes_fontes_normativas%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_hash text; v_num integer;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'normativos','editar',null::uuid);

  perform privado.v107_autorizar(p_id_organizacao,null,false);
  select * into f from public.fontes_normativas where id=p_id_fonte and id_organizacao=p_id_organizacao;
  if f.id is null then raise exception using errcode='PT404',message='Fonte normativa não encontrada neste escopo.'; end if;
  perform privado.v107_autorizar(p_id_organizacao,f.id_contrato,false);
  if p_inicio_vigencia is null or p_fim_vigencia<p_inicio_vigencia or (p_id_arquivo is null and nullif(btrim(p_conteudo_texto),'') is null) or jsonb_typeof(p_metadados) is distinct from 'object' then
    raise exception using errcode='PT400',message='Informe vigência válida, metadados e um arquivo ou texto de origem.';
  end if;
  if p_id_arquivo is not null then
    select * into a from public.arquivos where id=p_id_arquivo and id_organizacao=p_id_organizacao and id_contrato is not distinct from f.id_contrato;
    if a.id is null or a.status_seguranca<>'aprovado' then raise exception using errcode='PT400',message='O arquivo não está disponível e aprovado neste escopo.'; end if;
  end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.registrar_versao',p_chave_idempotencia,jsonb_build_array(p_id_fonte,p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,p_conteudo_texto,p_metadados));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select coalesce(max(versao),0)+1 into v_num from public.versoes_fontes_normativas where id_fonte=f.id;
  v_hash:=encode(extensions.digest(jsonb_build_array(p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,a.sha256,p_conteudo_texto,p_metadados)::text,'sha256'),'hex');
  insert into public.versoes_fontes_normativas(id_organizacao,id_contrato,id_fonte,versao,inicio_vigencia,fim_vigencia,id_arquivo,conteudo_texto,metadados,hash)
    values(p_id_organizacao,f.id_contrato,f.id,v_num,p_inicio_vigencia,p_fim_vigencia,p_id_arquivo,p_conteudo_texto,p_metadados,v_hash) returning * into v;
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107VersaoRegistrada','versoes_fontes_normativas',v.id,null,jsonb_build_object('id',v.id,'hash',v.hash,'versao',v.versao),jsonb_build_object('versao',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.aprovar_versao_fonte_v107(p_id_organizacao uuid, p_id_versao uuid, p_hash_esperado text, p_fundamento text, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; v_cmd jsonb; v_antes jsonb; v_contexto jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'normativos','aprovar',null::uuid);

  perform privado.v107_autorizar(p_id_organizacao,null,true);
  select * into v from public.versoes_fontes_normativas where id=p_id_versao and id_organizacao=p_id_organizacao;
  select * into f from public.fontes_normativas where id=v.id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from v.id_contrato;
  if v.id is null or f.id is null then raise exception using errcode='PT404',message='Versão normativa não encontrada neste escopo.'; end if;
  perform privado.v107_autorizar(p_id_organizacao,f.id_contrato,true);
  if nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe o fundamento da aprovação humana.'; end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.aprovar_versao',p_chave_idempotencia,jsonb_build_array(p_id_versao,p_hash_esperado,p_fundamento));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select * into v from public.versoes_fontes_normativas where id=p_id_versao for update;
  if v.hash is distinct from p_hash_esperado then raise exception using errcode='PT409',message='O conteúdo normativo mudou. Atualize e revise a versão.'; end if;
  if v.aprovado_em is not null then raise exception using errcode='PT409',message='Esta versão já foi aprovada. Atualize a tela.'; end if;
  if v.inicio_vigencia is null or v.fim_vigencia<v.inicio_vigencia or (v.id_arquivo is null and nullif(btrim(v.conteudo_texto),'') is null) then
    raise exception using errcode='PT400',message='A versão não tem vigência e origem válidas para aprovação.';
  end if;
  if v.id_arquivo is not null and not exists(select 1 from public.arquivos where id=v.id_arquivo and id_organizacao=p_id_organizacao and id_contrato is not distinct from f.id_contrato and status_seguranca='aprovado') then
    raise exception using errcode='PT400',message='O arquivo de origem não está aprovado neste escopo.';
  end if;
  v_antes:=jsonb_build_object('id',v.id,'hash',v.hash,'aprovado_em',v.aprovado_em);
  v_contexto:=privado.v107_capturar(p_id_organizacao,f.id_contrato);
  update public.versoes_fontes_normativas set aprovado_por=auth.uid(),aprovado_em=clock_timestamp() where id=v.id returning * into v;
  perform privado.v107_invalidar(v_contexto,f.id);
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107VersaoAprovada','versoes_fontes_normativas',v.id,v_antes,jsonb_build_object('id',v.id,'hash',v.hash,'aprovado_por',v.aprovado_por,'aprovado_em',v.aprovado_em),jsonb_build_object('versao',to_jsonb(v)),p_fundamento);
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.definir_aplicabilidade_fonte_v107(p_id_organizacao uuid, p_id_contrato uuid, p_id_versao uuid, p_aplicavel boolean, p_fundamento text, p_atualizado_em_esperado timestamp with time zone, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.versoes_fontes_normativas%rowtype; f public.fontes_normativas%rowtype; a public.aplicabilidades_fonte%rowtype; v_cmd jsonb; v_antes jsonb; v_contexto jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'normativos','editar',null::uuid);

  perform privado.v107_autorizar(p_id_organizacao,p_id_contrato,true);
  if p_id_contrato is null or p_aplicavel is null or nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe contrato, aplicabilidade e fundamento.'; end if;
  select * into v from public.versoes_fontes_normativas where id=p_id_versao and id_organizacao=p_id_organizacao and (id_contrato is null or id_contrato=p_id_contrato);
  select * into f from public.fontes_normativas where id=v.id_fonte and id_organizacao=p_id_organizacao and id_contrato is not distinct from v.id_contrato;
  if v.id is null or f.id is null then raise exception using errcode='PT404',message='Versão normativa não encontrada neste escopo.'; end if;
  if v.aprovado_em is null then raise exception using errcode='PT400',message='A versão precisa de aprovação humana antes da aplicabilidade.'; end if;
  v_cmd:=privado.v107_iniciar(p_id_organizacao,'v107.definir_aplicabilidade',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_versao,p_aplicavel,p_fundamento,p_atualizado_em_esperado));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.fontes_normativas where id=f.id for update;
  select * into a from public.aplicabilidades_fonte where id_fonte_versao=p_id_versao and id_contrato=p_id_contrato for update;
  if (a.id is null and p_atualizado_em_esperado is not null) or (a.id is not null and a.atualizado_em is distinct from p_atualizado_em_esperado) then
    raise exception using errcode='PT409',message='A aplicabilidade foi atualizada. Atualize a tela e revise os dados.';
  end if;
  v_antes:=case when a.id is null then null else to_jsonb(a) end;
  v_contexto:=privado.v107_capturar(p_id_organizacao,p_id_contrato);
  if a.id is null then
    insert into public.aplicabilidades_fonte(id_organizacao,id_contrato,id_fonte_versao,aplicavel,fundamento,aprovado_por,aprovado_em)
      values(p_id_organizacao,p_id_contrato,p_id_versao,p_aplicavel,p_fundamento,auth.uid(),clock_timestamp()) returning * into a;
  else
    update public.aplicabilidades_fonte set aplicavel=p_aplicavel,fundamento=p_fundamento,aprovado_por=auth.uid(),aprovado_em=clock_timestamp(),atualizado_em=clock_timestamp() where id=a.id returning * into a;
  end if;
  perform privado.v107_invalidar(v_contexto,f.id);
  return privado.v107_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V107AplicabilidadeDefinida','aplicabilidades_fonte',a.id,v_antes,to_jsonb(a),jsonb_build_object('aplicabilidade',to_jsonb(a)),p_fundamento);
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.salvar_proposta_orcamentaria_v108(p_id_organizacao uuid, p_id_contrato uuid, p_id_proposta uuid, p_titulo text, p_versao_esperada bigint, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.propostas_orcamentarias%rowtype; v_antes jsonb; v_cmd jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'orcamentos',case when p_id_proposta is null then 'criar' else 'editar' end,null::uuid);

  perform privado.v108_autorizar(p_id_organizacao,p_id_contrato);
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o nome da proposta orçamentária.'; end if;
  if p_id_proposta is not null then
    select * into v from public.propostas_orcamentarias where id=p_id_proposta and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
    if v.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada neste contrato.'; end if;
  elsif p_versao_esperada is not null then raise exception using errcode='PT400',message='Uma nova proposta não possui versão anterior.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.salvar_proposta',p_chave_idempotencia,jsonb_build_array(p_id_contrato,p_id_proposta,p_titulo,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  if p_id_proposta is null then
    insert into public.propostas_orcamentarias(id_organizacao,id_contrato,titulo,situacao) values(p_id_organizacao,p_id_contrato,btrim(p_titulo),'rascunho') returning * into v;
  else
    select * into v from public.propostas_orcamentarias where id=p_id_proposta for update;
    if p_versao_esperada is null or v.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A proposta foi atualizada por outra pessoa. Atualize a tela antes de salvar.'; end if;
    v_antes:=to_jsonb(v);
    update public.propostas_orcamentarias set titulo=btrim(p_titulo) where id=v.id returning * into v;
  end if;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108PropostaSalva','propostas_orcamentarias',v.id,v_antes,to_jsonb(v),jsonb_build_object('proposta',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.registrar_versao_proposta_v108(p_id_organizacao uuid, p_id_proposta uuid, p_vigencia_inicio date, p_vigencia_fim date, p_id_arquivo_origem uuid, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p public.propostas_orcamentarias%rowtype; v public.versoes_proposta%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_num integer; v_ultima date;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'orcamentos','editar',null::uuid);

  select * into p from public.propostas_orcamentarias where id=p_id_proposta and id_organizacao=p_id_organizacao;
  if p.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,p.id_contrato);
  if p_vigencia_inicio is null or (p_vigencia_fim is not null and p_vigencia_fim<p_vigencia_inicio) then raise exception using errcode='PT400',message='Informe uma vigência válida para a proposta.'; end if;
  if p_id_arquivo_origem is null then raise exception using errcode='PT400',message='Anexe o documento-base da proposta orçamentária.'; end if;
  select * into a from public.arquivos where id=p_id_arquivo_origem and id_organizacao=p_id_organizacao and id_contrato=p.id_contrato;
  if a.id is null then raise exception using errcode='PT400',message='O documento-base não pertence a este contrato.'; end if;
  if a.status_seguranca not in('pendente','aprovado') then raise exception using errcode='PT400',message='O documento-base não está disponível para uso.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.registrar_versao',p_chave_idempotencia,jsonb_build_array(p_id_proposta,p_vigencia_inicio,p_vigencia_fim,p_id_arquivo_origem));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.propostas_orcamentarias where id=p.id for update;
  if exists(select 1 from public.versoes_proposta where id_proposta=p.id and situacao='rascunho') then raise exception using errcode='PT409',message='Já existe uma versão em rascunho. Conclua ou publique essa versão antes de iniciar outra.'; end if;
  select max(vigencia_inicio) into v_ultima from public.versoes_proposta where id_proposta=p.id and situacao in('publicada','substituida');
  if v_ultima is not null and p_vigencia_inicio<=v_ultima then raise exception using errcode='PT400',message='A nova versão deve iniciar após a versão publicada anterior.'; end if;
  select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_proposta where id_proposta=p.id;
  insert into public.versoes_proposta(id_organizacao,id_contrato,id_proposta,numero_versao,vigencia_inicio,vigencia_fim,id_arquivo_origem,valor_total,hash,situacao)
    values(p_id_organizacao,p.id_contrato,p.id,v_num,p_vigencia_inicio,p_vigencia_fim,p_id_arquivo_origem,0,repeat('0',64),'rascunho') returning * into v;
  update public.versoes_proposta set hash=privado.v108_hash_versao(v.id) where id=v.id returning * into v;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108VersaoRegistrada','versoes_proposta',v.id,null,to_jsonb(v),jsonb_build_object('versao',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.salvar_linha_orcamentaria_v108(p_id_organizacao uuid, p_id_versao_proposta uuid, p_id_linha uuid, p_codigo text, p_grupo text, p_rubrica text, p_subrubrica text, p_descricao text, p_valor_mensal numeric, p_valor_anual numeric, p_permite_remanejamento boolean, p_limite_remanejamento_percentual numeric, p_observacoes text, p_versao_esperada bigint, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.versoes_proposta%rowtype; l public.linhas_orcamentarias%rowtype; v_antes jsonb; v_cmd jsonb; v_codigo text; v_descricao text; v_limite numeric; v_total numeric;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'orcamentos',case when p_id_linha is null then 'criar' else 'editar' end,null::uuid);

  select * into v from public.versoes_proposta where id=p_id_versao_proposta and id_organizacao=p_id_organizacao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,v.id_contrato);
  if nullif(btrim(p_rubrica),'') is null then raise exception using errcode='PT400',message='Informe a rubrica orçamentária.'; end if;
  if p_valor_mensal is null and p_valor_anual is null then raise exception using errcode='PT400',message='Informe ao menos o valor mensal ou o valor anual previsto.'; end if;
  if coalesce(p_valor_mensal,0)<0 or coalesce(p_valor_anual,0)<0 then raise exception using errcode='PT400',message='Os valores previstos não podem ser negativos.'; end if;
  if p_limite_remanejamento_percentual is not null and (p_limite_remanejamento_percentual<0 or p_limite_remanejamento_percentual>100) then raise exception using errcode='PT400',message='O limite de remanejamento deve estar entre 0% e 100%.'; end if;
  v_limite:=case when coalesce(p_permite_remanejamento,false) then p_limite_remanejamento_percentual else null end;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.salvar_linha',p_chave_idempotencia,jsonb_build_array(p_id_versao_proposta,p_id_linha,p_codigo,p_grupo,p_rubrica,p_subrubrica,p_descricao,p_valor_mensal,p_valor_anual,p_permite_remanejamento,v_limite,p_observacoes,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v from public.versoes_proposta where id=p_id_versao_proposta for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Uma versão publicada não pode ser alterada.'; end if;
  if p_id_linha is null then
    v_codigo:=coalesce(nullif(btrim(p_codigo),''),'RUB-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)));
    if exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id and codigo=v_codigo) then raise exception using errcode='PT409',message='Já existe uma rubrica com este código nesta versão.'; end if;
    v_descricao:=coalesce(nullif(btrim(p_descricao),''),concat_ws(' / ',nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),'')));
    v_total:=coalesce(p_valor_anual,p_valor_mensal,0);
    insert into public.linhas_orcamentarias(id_organizacao,id_contrato,id_versao_proposta,codigo,grupo,rubrica,subrubrica,descricao,quantidade,valor_unitario,valor_total,valor_mensal_previsto,valor_anual_previsto,permite_remanejamento,limite_remanejamento_percentual,observacoes)
      values(p_id_organizacao,v.id_contrato,v.id,v_codigo,nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),''),v_descricao,1,v_total,v_total,p_valor_mensal,p_valor_anual,coalesce(p_permite_remanejamento,false),v_limite,nullif(btrim(p_observacoes),'')) returning * into l;
  else
    select * into l from public.linhas_orcamentarias where id=p_id_linha and id_versao_proposta=v.id and id_organizacao=p_id_organizacao for update;
    if l.id is null then raise exception using errcode='PT404',message='Rubrica orçamentária não encontrada nesta versão.'; end if;
    if p_versao_esperada is null or l.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A rubrica foi atualizada por outra pessoa. Atualize a tela antes de salvar.'; end if;
    v_codigo:=coalesce(nullif(btrim(p_codigo),''),l.codigo);
    if exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id and codigo=v_codigo and id<>l.id) then raise exception using errcode='PT409',message='Já existe uma rubrica com este código nesta versão.'; end if;
    v_descricao:=coalesce(nullif(btrim(p_descricao),''),concat_ws(' / ',nullif(btrim(p_grupo),''),btrim(p_rubrica),nullif(btrim(p_subrubrica),'')));
    v_total:=coalesce(p_valor_anual,p_valor_mensal,0); v_antes:=to_jsonb(l);
    update public.linhas_orcamentarias set codigo=v_codigo,grupo=nullif(btrim(p_grupo),''),rubrica=btrim(p_rubrica),subrubrica=nullif(btrim(p_subrubrica),''),descricao=v_descricao,quantidade=1,valor_unitario=v_total,valor_total=v_total,valor_mensal_previsto=p_valor_mensal,valor_anual_previsto=p_valor_anual,permite_remanejamento=coalesce(p_permite_remanejamento,false),limite_remanejamento_percentual=v_limite,observacoes=nullif(btrim(p_observacoes),'') where id=l.id returning * into l;
  end if;
  v:=privado.v108_recalcular_versao(v.id);
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108LinhaSalva','linhas_orcamentarias',l.id,v_antes,to_jsonb(l),jsonb_build_object('linha',to_jsonb(l),'versao',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.remover_linha_orcamentaria_v108(p_id_organizacao uuid, p_id_versao_proposta uuid, p_id_linha uuid, p_versao_esperada bigint, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare l public.linhas_orcamentarias%rowtype; v public.versoes_proposta%rowtype; v_cmd jsonb; v_antes jsonb;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'orcamentos','editar',null::uuid);

  select * into v from public.versoes_proposta where id=p_id_versao_proposta and id_organizacao=p_id_organizacao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,v.id_contrato);
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.remover_linha',p_chave_idempotencia,jsonb_build_array(p_id_versao_proposta,p_id_linha,p_versao_esperada));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v from public.versoes_proposta where id=p_id_versao_proposta for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Rubricas de uma versão publicada são imutáveis.'; end if;
  select * into l from public.linhas_orcamentarias where id=p_id_linha and id_versao_proposta=v.id and id_organizacao=p_id_organizacao for update;
  if l.id is null then raise exception using errcode='PT404',message='Rubrica orçamentária não encontrada nesta versão.'; end if;
  if p_versao_esperada is null or l.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='A rubrica foi atualizada por outra pessoa. Atualize a tela antes de remover.'; end if;
  v_antes:=to_jsonb(l);
  delete from public.linhas_orcamentarias where id=l.id;
  v:=privado.v108_recalcular_versao(v.id);
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108LinhaRemovida','linhas_orcamentarias',l.id,v_antes,null,jsonb_build_object('id_linha',l.id,'removida',true,'versao',to_jsonb(v)));
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.publicar_versao_proposta_v108(p_id_organizacao uuid, p_id_versao uuid, p_hash_esperado text, p_fundamento text, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.versoes_proposta%rowtype; p public.propostas_orcamentarias%rowtype; a public.arquivos%rowtype; v_cmd jsonb; v_hash text; v_antes jsonb; r record;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'orcamentos','aprovar',null::uuid);

  select * into v from public.versoes_proposta where id=p_id_versao and id_organizacao=p_id_organizacao;
  if v.id is null then raise exception using errcode='PT404',message='Versão da proposta orçamentária não encontrada.'; end if;
  select * into p from public.propostas_orcamentarias where id=v.id_proposta and id_organizacao=p_id_organizacao and id_contrato=v.id_contrato;
  if p.id is null then raise exception using errcode='PT404',message='Proposta orçamentária não encontrada.'; end if;
  perform privado.v108_autorizar(p_id_organizacao,v.id_contrato);
  if nullif(btrim(p_fundamento),'') is null then raise exception using errcode='PT400',message='Informe o fundamento da publicação da proposta.'; end if;
  v_cmd:=privado.v108_iniciar(p_id_organizacao,'v108.publicar_versao',p_chave_idempotencia,jsonb_build_array(p_id_versao,p_hash_esperado,p_fundamento));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  perform 1 from public.propostas_orcamentarias where id=p.id for update;
  select * into v from public.versoes_proposta where id=p_id_versao for update;
  perform 1 from public.linhas_orcamentarias where id_versao_proposta=v.id order by id for update;
  if v.situacao<>'rascunho' then raise exception using errcode='PT409',message='Esta versão já foi publicada ou substituída.'; end if;
  if v.vigencia_inicio is null or (v.vigencia_fim is not null and v.vigencia_fim<v.vigencia_inicio) then raise exception using errcode='PT400',message='A versão não possui vigência válida.'; end if;
  if not exists(select 1 from public.linhas_orcamentarias where id_versao_proposta=v.id) then raise exception using errcode='PT400',message='Inclua ao menos uma rubrica antes de publicar a proposta.'; end if;
  select * into a from public.arquivos where id=v.id_arquivo_origem and id_organizacao=p_id_organizacao and id_contrato=v.id_contrato;
  if a.id is null or a.status_seguranca<>'aprovado' then raise exception using errcode='PT400',message='O documento-base precisa estar aprovado antes da publicação.'; end if;
  v_hash:=privado.v108_hash_versao(v.id);
  if p_hash_esperado is null or v_hash is distinct from p_hash_esperado or v.hash is distinct from p_hash_esperado then raise exception using errcode='PT409',message='A proposta mudou. Atualize a tela e revise a versão antes de publicar.'; end if;
  for r in select id from public.competencias where id_contrato=v.id_contrato and v.vigencia_inicio<=periodo_fim and (v.vigencia_fim is null or v.vigencia_fim>=periodo_inicio) order by id for update loop null; end loop;
  v_antes:=jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v));
  perform set_config('contaos.v108_publicacao_interna','1',true);
  update public.versoes_proposta set situacao='substituida' where id_proposta=p.id and id<>v.id and situacao='publicada';
  update public.versoes_proposta set situacao='publicada',aprovado_por=auth.uid(),aprovado_em=clock_timestamp(),hash=v_hash where id=v.id returning * into v;
  update public.propostas_orcamentarias set situacao='ativa',versao_atual=v.numero_versao where id=p.id returning * into p;
  return privado.v108_concluir((v_cmd->>'id')::uuid,p_id_organizacao,'V108VersaoPublicada','versoes_proposta',v.id,v_antes,jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v)),jsonb_build_object('proposta',to_jsonb(p),'versao',to_jsonb(v)),p_fundamento);
end $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.criar_documento_contrato_v110(p_id_contrato uuid, p_tipo text, p_titulo text, p_categoria text, p_id_arquivo uuid, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_contrato public.contratos%rowtype; v_arquivo public.arquivos%rowtype; v_doc uuid; v_ver uuid; v_job uuid; v_cmd jsonb; v_resultado jsonb;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.contratos where id=p_id_contrato),'documentos_contrato','criar',p_id_contrato);

  select * into v_contrato from public.contratos where id=p_id_contrato;
  if v_contrato.id is null then raise exception using errcode='PT404',message='Contrato não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v_contrato.id) or not privado.usuario_possui_perfil(v_contrato.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception using errcode='42501',message='Seu perfil atual não permite incluir documentos neste contrato.'; end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400',message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o título do documento.'; end if;
  v_cmd:=privado.v110_iniciar_comando(v_contrato.id_organizacao,'v110.criar_documento_contrato',p_chave_idempotencia,jsonb_build_object('id_contrato',v_contrato.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'id_arquivo',p_id_arquivo));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_contrato.id_organizacao,v_contrato.id);
  insert into public.documentos_contrato(id_organizacao,id_contrato,tipo,titulo,categoria,situacao,versao_atual)
  values(v_contrato.id_organizacao,v_contrato.id,btrim(p_tipo),btrim(p_titulo),nullif(btrim(coalesce(p_categoria,'')),''),'ativo',1) returning id into v_doc;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash,enviado_por)
  values(v_contrato.id_organizacao,v_contrato.id,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()) returning id into v_ver;
  v_job:=privado.enfileirar_job('documents',v_contrato.id_organizacao,v_contrato.id,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_contrato.id_organizacao,v_contrato.id,v_ver,'documents','pendente');
  v_resultado:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_contrato.id_organizacao,'DocumentoContratoCriado','documentos_contrato',v_doc,jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job),jsonb_build_object('id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,'id_arquivo',v_arquivo.id,'id_job',v_job));
  return v_resultado;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.criar_documento_contrato_v111(p_id_contrato uuid, p_tipo text, p_titulo text, p_categoria text, p_vigencia_inicio date, p_vigencia_fim date, p_observacoes text, p_id_arquivo uuid, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_contrato public.contratos%rowtype; v_cmd jsonb; v_base jsonb; v_doc uuid; v_resp jsonb;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.contratos where id=p_id_contrato),'documentos_contrato','criar',p_id_contrato);

  select * into v_contrato from public.contratos where id=p_id_contrato;
  if v_contrato.id is null then raise exception using errcode='PT404',message='Contrato não encontrado.'; end if;
  if p_vigencia_fim is not null and p_vigencia_inicio is null then raise exception using errcode='PT400',message='Informe o início da vigência quando houver fim de vigência.'; end if;
  if p_vigencia_inicio is not null and p_vigencia_fim is not null and p_vigencia_fim<p_vigencia_inicio then raise exception using errcode='PT400',message='O fim da vigência não pode ser anterior ao início.'; end if;

  v_cmd:=privado.v110_iniciar_comando(v_contrato.id_organizacao,'v111.criar_documento_contrato_completo',p_chave_idempotencia,
    jsonb_build_object('id_contrato',p_id_contrato,'tipo',p_tipo,'titulo',p_titulo,'categoria',p_categoria,
      'vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim,'observacoes',p_observacoes,'id_arquivo',p_id_arquivo));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_base:=privado.criar_documento_contrato_v110(p_id_contrato,p_tipo,p_titulo,p_categoria,p_id_arquivo,
    p_chave_idempotencia||':v110');
  v_doc:=(v_base->>'id_documento')::uuid;
  update public.documentos_contrato set vigencia_inicio=p_vigencia_inicio,vigencia_fim=p_vigencia_fim,
    observacoes=nullif(btrim(coalesce(p_observacoes,'')),'') where id=v_doc;

  v_resp:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_contrato.id_organizacao,
    'DocumentoContratoMetadadosCompletos','documentos_contrato',v_doc,null,
    v_base||jsonb_build_object('vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim));
  return v_resp;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.adicionar_versao_documento_contrato_v110(p_id_documento uuid, p_id_arquivo uuid, p_motivo text, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_doc public.documentos_contrato%rowtype; v_arquivo public.arquivos%rowtype; v_num integer; v_ver uuid; v_job uuid; v_cmd jsonb; v_resultado jsonb;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.documentos_contrato where id=p_id_documento),'documentos_contrato','editar',(select id_contrato from public.documentos_contrato where id=p_id_documento));

  select * into v_doc from public.documentos_contrato where id=p_id_documento;
  if v_doc.id is null then raise exception using errcode='PT404',message='Documento não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato) or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']::text[]) then raise exception using errcode='42501',message='Seu perfil atual não permite criar uma nova versão deste documento.'; end if;
  v_cmd:=privado.v110_iniciar_comando(v_doc.id_organizacao,'v110.adicionar_versao_documento_contrato',p_chave_idempotencia,jsonb_build_object('id_documento',v_doc.id,'id_arquivo',p_id_arquivo,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')));
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;
  select * into v_doc from public.documentos_contrato where id=p_id_documento for update;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_doc.id_organizacao,v_doc.id_contrato);
  select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_documento where id_documento_contrato=v_doc.id;
  if v_num>1 and nullif(btrim(coalesce(p_motivo,'')),'') is null then raise exception using errcode='PT400',message='Informe o motivo da nova versão para preservar a rastreabilidade documental.'; end if;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_contrato,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por)
  values(v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arquivo.id,v_arquivo.sha256,nullif(btrim(coalesce(p_motivo,'')),''),auth.uid()) returning id into v_ver;
  update public.documentos_contrato set versao_atual=v_num where id=v_doc.id;
  v_job:=privado.enfileirar_job('documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');
  v_resultado:=privado.v110_concluir_comando((v_cmd->>'id')::uuid,v_doc.id_organizacao,'VersaoDocumentoContratoCriada','versoes_documento',v_ver,jsonb_build_object('id_documento',v_doc.id,'id_versao',v_ver,'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')),jsonb_build_object('id_documento',v_doc.id,'id_versao',v_ver,'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job));
  return v_resultado;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.criar_competencia(p_id_contrato uuid, p_competencia_referencia date, p_periodo_inicio date DEFAULT NULL::date, p_periodo_fim date DEFAULT NULL::date, p_data_limite date DEFAULT NULL::date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org uuid; v_comp uuid; v_inicio date; v_fim date;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.contratos where id=p_id_contrato),'competencias','criar',p_id_contrato);

  select id_organizacao into v_org from public.contratos where id=p_id_contrato;
  if v_org is null then raise exception 'Contrato não encontrado.'; end if;
  if not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_org,array['administrador','gestor_contrato','prestacao_contas']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_competencia_referencia <> date_trunc('month',p_competencia_referencia)::date then raise exception 'Competência deve ser o primeiro dia do mês.'; end if;
  v_inicio:=coalesce(p_periodo_inicio,p_competencia_referencia);
  v_fim:=coalesce(p_periodo_fim,(p_competencia_referencia+interval '1 month - 1 day')::date);
  insert into public.competencias(id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,data_limite,situacao)
  values(v_org,p_id_contrato,p_competencia_referencia,v_inicio,v_fim,p_data_limite,'preparando') returning id into v_comp;

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'item_lista',il.id,vl.numero_versao::text,il.codigo,il.descricao,il.categoria,il.obrigatorio,il.aplicavel,il.impeditivo,il.criticidade,'lista_verificacao',lv.nome,jsonb_build_object('id_lista',lv.id,'id_versao_lista',vl.id),true,il.ordem,encode(extensions.digest(concat_ws('|',il.id::text,vl.numero_versao::text,il.codigo,il.descricao,il.obrigatorio::text,il.aplicavel::text,il.impeditivo::text),'sha256'),'hex')
  from public.listas_verificacao lv join public.versoes_lista vl on vl.id_lista=lv.id and vl.situacao='publicada' join public.itens_lista il on il.id_versao_lista=vl.id
  where lv.id_contrato=p_id_contrato and lv.situacao='ativa' and (vl.vigencia_inicio is null or vl.vigencia_inicio<=v_fim) and (vl.vigencia_fim is null or vl.vigencia_fim>=v_inicio);

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'regra_conformidade',rc.id,rc.versao_registro::text,rc.codigo,rc.descricao,'regra_conformidade',true,true,rc.efeito_portao,'alta','regra_conformidade',rc.codigo,rc.configuracao,rc.efeito_portao,100000+row_number() over(order by rc.codigo),encode(extensions.digest(concat_ws('|',rc.id::text,rc.codigo,rc.descricao,rc.versao_registro::text),'sha256'),'hex')
  from public.regras_conformidade rc where rc.id_contrato=p_id_contrato and rc.situacao='ativa';

  insert into public.requisitos_competencia(id_organizacao,id_contrato,id_competencia,origem_tipo,origem_id,origem_versao,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,fonte_tipo,fonte_referencia,fonte_detalhe,efeito_portao,ordem,hash_snapshot)
  select v_org,p_id_contrato,v_comp,'regra_preventiva',rp.id,rp.numero_versao::text,rp.codigo_regra,rp.descricao,'historica',true,true,(rp.efeito='bloqueio'),rp.criticidade,'historico',rp.codigo_regra,jsonb_build_object('escopo_aplicacao',rp.escopo_aplicacao,'efeito',rp.efeito),(rp.efeito='bloqueio'),200000+row_number() over(order by rp.codigo_regra),encode(extensions.digest(concat_ws('|',rp.id::text,rp.codigo_regra,rp.numero_versao::text,rp.descricao),'sha256'),'hex')
  from public.regras_preventivas rp join public.contratos c on c.id=p_id_contrato
  where rp.id_organizacao=v_org and rp.situacao='ativa' and (rp.vigencia_inicio is null or rp.vigencia_inicio<=v_fim) and (rp.vigencia_fim is null or rp.vigencia_fim>=v_inicio)
    and ((rp.escopo_aplicacao='contrato' and rp.id_contrato=p_id_contrato) or (rp.escopo_aplicacao='contratante' and rp.id_contratante=c.id_contratante) or (rp.escopo_aplicacao='tipo_contrato' and rp.tipo_contrato=c.tipo_contrato) or rp.escopo_aplicacao='organizacao');

  update public.competencias set situacao='rascunho' where id=v_comp;
  perform privado.registrar_evento_auditoria(v_org,'CompetenciaCriada','competencias',v_comp,null,jsonb_build_object('id_contrato',p_id_contrato,'competencia_referencia',p_competencia_referencia));
  return v_comp;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.obter_visao_geral_competencia(p_id_competencia uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.competencias%rowtype;
  v_portao jsonb;
  v_hash_atual text;
  v_hash_exec text;
  v_hash_aprovado text;
  v_parecer_aprovado boolean := false;
  v_analise_atual boolean := false;
  v_aprovacao_atual boolean := false;
  v_perfil_analise boolean := false;
  v_perfil_aprovar boolean := false;
  v_perfil_registrar boolean := false;
  v_pode_analisar boolean := false;
  v_pode_apresentar boolean := false;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'competencias','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  select * into v from public.competencias where id = p_id_competencia;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise sqlstate '42501' using message = 'Você não tem permissão para acessar esta competência.';
  end if;
  v_portao := privado.avaliar_portao_conformidade(v.id);
  v_hash_atual := privado.hash_contexto_competencia(v.id);
  select exists(select 1 from public.pareceres_internos p where p.id_competencia = v.id and p.status = 'aprovado') into v_parecer_aprovado;
  select e.hash_entrada into v_hash_exec from public.execucoes_analise e where e.id_competencia = v.id and e.status = 'concluida' and e.tipo in ('completa','reanálise') order by e.concluida_em desc nulls last, e.criado_em desc, e.id desc limit 1;
  v_analise_atual := v_hash_exec is not null and v_hash_exec = v_hash_atual;
  select a.hash_contexto into v_hash_aprovado from public.aprovacoes a where a.id_competencia = v.id and a.tipo = 'apresentacao' and a.status = 'aprovada' order by a.criado_em desc, a.id desc limit 1;
  v_aprovacao_atual := v_hash_aprovado is not null and v_hash_aprovado = v_hash_atual;
  v_perfil_analise := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]);
  v_perfil_aprovar := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]);
  v_perfil_registrar := privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]);
  v_pode_analisar := v_perfil_analise and v.situacao not in ('apresentado','aguardando_contratante','validada','encerrada','cancelada');
  v_pode_apresentar := (v.situacao = 'pode_apresentar_contratante' and v_perfil_registrar and v_aprovacao_atual and v_analise_atual) or (v.situacao in ('em_analise','em_reanalise','pendente_correcao','rascunho') and v_perfil_aprovar and coalesce((v_portao->>'liberado')::boolean,false) and v_parecer_aprovado and v_analise_atual);
  return jsonb_build_object(
    'competencia', jsonb_build_object('id',v.id,'id_contrato',v.id_contrato,'id_organizacao',v.id_organizacao,'competencia_referencia',v.competencia_referencia,'periodo_inicio',v.periodo_inicio,'periodo_fim',v.periodo_fim,'data_limite',v.data_limite,'situacao',v.situacao,'percentual_conformidade',v.percentual_conformidade,'versao_pacote_atual',v.versao_pacote_atual,'versao_registro',v.versao_registro,'atualizado_em',v.atualizado_em),
    'portao', v_portao,
    'blocking_summary', jsonb_build_object('pendentes',coalesce((v_portao->>'pendentes')::integer,0),'nao_conformes',coalesce((v_portao->>'nao_conformes')::integer,0),'inconclusivos',coalesce((v_portao->>'inconclusivos')::integer,0),'em_analise',coalesce((v_portao->>'em_analise')::integer,0),'nao_conformidades_bloqueantes',coalesce((v_portao->>'nao_conformidades_bloqueantes')::integer,0),'parecer_aprovado',v_parecer_aprovado,'analise_concluida_atual',v_analise_atual,'aprovacao_apresentacao_atual',v_aprovacao_atual),
    'allowed_actions', jsonb_build_object('abrir_documentos',true,'analisar',v_pode_analisar,'abrir_parecer',true,'apresentar',v_pode_apresentar)
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.obter_documentos_competencia_v115(p_id_competencia uuid, p_documentos_offset integer DEFAULT 0, p_documentos_limite integer DEFAULT 25, p_requisitos_offset integer DEFAULT 0, p_requisitos_limite integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_docs jsonb := '[]'::jsonb;
  v_reqs jsonb := '[]'::jsonb;
  v_docs_total integer := 0;
  v_req_total integer := 0;
  v_req_aplicaveis integer := 0;
  v_req_pendentes integer := 0;
  v_tem_erro boolean := false;
  v_processando boolean := false;
  v_estado text;
  v_pode_escrever boolean := false;
  v_motivo_obrigatorio boolean := false;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'documentos_competencia','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  if p_documentos_offset < 0 or p_requisitos_offset < 0
     or p_documentos_limite not between 1 and 100
     or p_requisitos_limite not between 1 and 100 then
    raise exception using errcode='PT400',message='Informe uma paginação válida.';
  end if;

  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then
    raise exception using errcode='PT404',message='Competência não encontrada.';
  end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) then
    raise exception using errcode='42501',message='Você não tem permissão para acessar esta competência.';
  end if;

  v_pode_escrever := privado.usuario_possui_perfil(
    v_comp.id_organizacao,
    array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]
  );
  select exists(select 1 from public.execucoes_analise e where e.id_competencia=v_comp.id)
    into v_motivo_obrigatorio;

  select count(*) into v_docs_total
    from public.documentos_competencia d
   where d.id_competencia=v_comp.id;

  select
    count(*),
    count(*) filter(where r.aplicavel),
    count(*) filter(
      where r.aplicavel and not exists(
        select 1 from public.documentos_competencia d
         where d.id_competencia=v_comp.id
           and d.id_requisito_competencia=r.id
           and d.situacao='ativo'
      )
    )
  into v_req_total,v_req_aplicaveis,v_req_pendentes
  from public.requisitos_competencia r
  where r.id_competencia=v_comp.id
    and privado.v115_requisito_exige_documento(r.regra_validacao);

  select coalesce(jsonb_agg(x.obj order by x.atualizado_em desc,x.id desc),'[]'::jsonb)
    into v_docs
  from (
    select d.id,d.atualizado_em,
      jsonb_build_object(
        'id',d.id,
        'tipo',d.tipo,
        'titulo',d.titulo,
        'categoria',d.categoria,
        'situacao',d.situacao,
        'versao_atual',d.versao_atual,
        'versao_registro',d.versao_registro,
        'criado_em',d.criado_em,
        'atualizado_em',d.atualizado_em,
        'id_requisito_competencia',d.id_requisito_competencia,
        'requisito',case when r.id is null then null else jsonb_build_object(
          'id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,
          'obrigatorio',r.obrigatorio,'aplicavel',r.aplicavel,'impeditivo',r.impeditivo,'criticidade',r.criticidade
        ) end,
        'versao',case when vd.id is null then null else jsonb_build_object(
          'id',vd.id,'numero_versao',vd.numero_versao,'hash',vd.hash,
          'motivo_substituicao',vd.motivo_substituicao,'metadados_extraidos',vd.metadados_extraidos,
          'criado_em',vd.criado_em,'id_arquivo',vd.id_arquivo
        ) end,
        'arquivo',case when a.id is null then null else jsonb_build_object(
          'id',a.id,'nome_original',a.nome_original,'mime',a.mime,'tamanho',a.tamanho,
          'sha256',a.sha256,'status_seguranca',a.status_seguranca,'origem',a.origem,'criado_em',a.criado_em
        ) end,
        'processamento',case when pr.id is null then null else jsonb_build_object(
          'id',pr.id,'etapa',pr.etapa,'status',pr.status,'tentativas',pr.tentativas,
          'erro_codigo',pr.erro_codigo,'resultado',pr.resultado,
          'iniciado_em',pr.iniciado_em,'concluido_em',pr.concluido_em,'atualizado_em',pr.atualizado_em
        ) end
      ) as obj
    from public.documentos_competencia d
    left join public.requisitos_competencia r on r.id=d.id_requisito_competencia and r.id_competencia=d.id_competencia
    left join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    left join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id
    order by d.atualizado_em desc,d.id desc
    offset p_documentos_offset limit p_documentos_limite
  ) x;

  select coalesce(jsonb_agg(x.obj order by x.ordem,x.id),'[]'::jsonb)
    into v_reqs
  from (
    select r.id,r.ordem,
      jsonb_build_object(
        'id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,
        'obrigatorio',r.obrigatorio,'aplicavel',r.aplicavel,'impeditivo',r.impeditivo,
        'criticidade',r.criticidade,'ordem',r.ordem,
        'tipos_esperados',case
          when jsonb_typeof(r.regra_validacao #> '{documento,tipos}')='array'
            then r.regra_validacao #> '{documento,tipos}'
          else '[]'::jsonb end,
        'atendido',exists(
          select 1 from public.documentos_competencia d
           where d.id_competencia=v_comp.id
             and d.id_requisito_competencia=r.id
             and d.situacao='ativo'
        )
      ) as obj
    from public.requisitos_competencia r
    where r.id_competencia=v_comp.id
      and privado.v115_requisito_exige_documento(r.regra_validacao)
    order by r.ordem,r.id
    offset p_requisitos_offset limit p_requisitos_limite
  ) x;

  select exists(
    select 1
    from public.documentos_competencia d
    join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id and d.situacao='ativo'
      and (a.status_seguranca in ('quarentena','bloqueado') or pr.status in ('falhou','cancelado'))
  ) into v_tem_erro;

  select exists(
    select 1
    from public.documentos_competencia d
    join lateral (
      select v.* from public.versoes_documento v
       where v.id_documento_competencia=d.id
       order by v.numero_versao desc,v.id desc limit 1
    ) vd on true
    join public.arquivos a on a.id=vd.id_arquivo
    left join lateral (
      select p.* from public.processamentos_documento p
       where p.id_versao_documento=vd.id
       order by p.criado_em desc,p.id desc limit 1
    ) pr on true
    where d.id_competencia=v_comp.id and d.situacao='ativo'
      and (a.status_seguranca='pendente' or pr.status in ('pendente','processando'))
  ) into v_processando;

  v_estado := case
    when v_tem_erro then 'error'
    when v_processando then 'processing'
    when v_req_pendentes>0 then 'missing_docs'
    else 'complete'
  end;

  return jsonb_build_object(
    'schema_versao','v115-v1',
    'competencia',jsonb_build_object(
      'id',v_comp.id,'id_contrato',v_comp.id_contrato,'id_organizacao',v_comp.id_organizacao,
      'competencia_referencia',v_comp.competencia_referencia,'situacao',v_comp.situacao,
      'versao_registro',v_comp.versao_registro,'atualizado_em',v_comp.atualizado_em
    ),
    'estado_documental',v_estado,
    'resumo',jsonb_build_object(
      'documentos_total',v_docs_total,
      'requisitos_documentais_total',v_req_total,
      'requisitos_documentais_aplicaveis',v_req_aplicaveis,
      'requisitos_documentais_pendentes',v_req_pendentes
    ),
    'documentos',v_docs,
    'documentos_paginacao',jsonb_build_object('offset',p_documentos_offset,'limite',p_documentos_limite,'total',v_docs_total),
    'requisitos_documentais',v_reqs,
    'requisitos_paginacao',jsonb_build_object('offset',p_requisitos_offset,'limite',p_requisitos_limite,'total',v_req_total),
    'capacidades',jsonb_build_object(
      'pode_enviar',v_pode_escrever,
      'pode_nova_versao',v_pode_escrever,
      'motivo_nova_versao_obrigatorio',v_motivo_obrigatorio
    )
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.criar_documento_competencia(p_id_competencia uuid, p_tipo text, p_titulo text, p_categoria text, p_id_requisito uuid, p_id_arquivo uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_comp public.competencias%rowtype; v_arq public.arquivos%rowtype; v_doc uuid; v_ver uuid;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'documentos_competencia','criar',(select id_contrato from public.competencias where id=p_id_competencia));

  select * into v_comp from public.competencias where id=p_id_competencia;
  select * into v_arq from public.arquivos where id=p_id_arquivo;
  if v_comp.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if v_arq.id is null or v_arq.id_organizacao<>v_comp.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_comp.id_contrato) then raise exception 'O arquivo informado não pertence a esta competência.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite incluir documentos nesta competência.'; end if;
  if p_id_requisito is not null and not exists(select 1 from public.requisitos_competencia r where r.id=p_id_requisito and r.id_competencia=v_comp.id) then raise exception 'O requisito informado não pertence a esta competência.'; end if;
  insert into public.documentos_competencia(id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,p_tipo,p_titulo,p_categoria,p_id_requisito,'ativo',1) returning id into v_doc;
  insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arq.id,v_arq.sha256,auth.uid()) returning id into v_ver;
  perform privado.enfileirar_job('documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');
  perform privado.registrar_evento_auditoria(v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,null,jsonb_build_object('id_versao_documento',v_ver,'id_arquivo',v_arq.id));
  return v_doc;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.criar_documento_competencia_v115(p_id_competencia uuid, p_tipo text, p_titulo text, p_categoria text, p_id_requisito uuid, p_id_arquivo uuid, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_req public.requisitos_competencia%rowtype;
  v_tipos jsonb := '[]'::jsonb;
  v_doc uuid;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'documentos_competencia','criar',(select id_contrato from public.competencias where id=p_id_competencia));

  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception using errcode='PT404',message='Competência não encontrada.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
     or not privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite incluir documentos nesta competência.';
  end if;
  if nullif(btrim(p_tipo),'') is null then raise exception using errcode='PT400',message='Informe o tipo do documento.'; end if;
  if nullif(btrim(p_titulo),'') is null then raise exception using errcode='PT400',message='Informe o título do documento.'; end if;

  if p_id_requisito is not null then
    select * into v_req
      from public.requisitos_competencia r
     where r.id=p_id_requisito and r.id_competencia=v_comp.id;

    if v_req.id is null then
      raise exception using errcode='PT400',message='O requisito informado não pertence a esta competência.';
    end if;

    if not privado.v115_requisito_exige_documento(v_req.regra_validacao) then
      raise exception using errcode='PT400',message='O requisito informado não é um requisito documental desta competência.';
    end if;

    v_tipos := case
      when jsonb_typeof(v_req.regra_validacao #> '{documento,tipos}')='array'
        then v_req.regra_validacao #> '{documento,tipos}'
      else '[]'::jsonb
    end;

    if jsonb_array_length(v_tipos)>0 and not (v_tipos ? btrim(p_tipo)) then
      raise exception using errcode='PT400',message='O tipo informado não é aceito para o requisito documental selecionado.';
    end if;
  end if;

  v_cmd:=privado.v110_iniciar_comando(
    v_comp.id_organizacao,'v115.criar_documento_competencia',p_chave_idempotencia,
    jsonb_build_object('id_competencia',v_comp.id,'tipo',btrim(p_tipo),'titulo',btrim(p_titulo),
      'categoria',nullif(btrim(coalesce(p_categoria,'')),''),'id_requisito',p_id_requisito,'id_arquivo',p_id_arquivo)
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_comp.id_organizacao,v_comp.id_contrato);
  insert into public.documentos_competencia(
    id_organizacao,id_contrato,id_competencia,tipo,titulo,categoria,id_requisito_competencia,situacao,versao_atual
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_comp.id,btrim(p_tipo),btrim(p_titulo),
    nullif(btrim(coalesce(p_categoria,'')),''),p_id_requisito,'ativo',1
  ) returning id into v_doc;
  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,enviado_por
  ) values(
    v_comp.id_organizacao,v_comp.id_contrato,v_doc,1,v_arquivo.id,v_arquivo.sha256,auth.uid()
  ) returning id into v_ver;
  v_job:=privado.enfileirar_job(
    'documents',v_comp.id_organizacao,v_comp.id_contrato,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text
  );
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_comp.id_organizacao,v_comp.id_contrato,v_ver,'documents','pendente');

  v_resultado:=privado.v115_concluir_comando(
    (v_cmd->>'id')::uuid,v_comp.id_organizacao,'DocumentoCompetenciaCriado','documentos_competencia',v_doc,
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_requisito',p_id_requisito,'id_job',v_job),
    jsonb_build_object('id_competencia',v_comp.id,'id_documento',v_doc,'id_versao',v_ver,'numero_versao',1,
      'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.adicionar_versao_documento_competencia(p_id_documento uuid, p_id_arquivo uuid, p_motivo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_doc public.documentos_competencia%rowtype; v_arq public.arquivos%rowtype; v_num integer; v_ver uuid;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.documentos_competencia where id=p_id_documento),'documentos_competencia','editar',(select id_contrato from public.documentos_competencia where id=p_id_documento));

 select * into v_doc from public.documentos_competencia where id=p_id_documento for update;
 select * into v_arq from public.arquivos where id=p_id_arquivo;
 if v_doc.id is null then raise exception 'Não encontramos o documento informado.'; end if;
 if v_arq.id is null or v_arq.id_organizacao<>v_doc.id_organizacao or (v_arq.id_contrato is not null and v_arq.id_contrato<>v_doc.id_contrato) then raise exception 'O arquivo informado não pertence a este contrato.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato) or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite criar uma nova versão deste documento.'; end if;
 select coalesce(max(numero_versao),0)+1 into v_num from public.versoes_documento where id_documento_competencia=v_doc.id;
 insert into public.versoes_documento(id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por)
 values(v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arq.id,v_arq.sha256,p_motivo,auth.uid()) returning id into v_ver;
 update public.documentos_competencia set versao_atual=v_num,versao_registro=versao_registro where id=v_doc.id;
 perform privado.enfileirar_job('documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text);
 insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status) values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');
 perform privado.registrar_evento_auditoria(v_doc.id_organizacao,'VersaoDocumentoCompetenciaCriada','versoes_documento',v_ver,null,jsonb_build_object('id_documento_competencia',v_doc.id,'numero_versao',v_num,'motivo',p_motivo));
 return v_ver;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.adicionar_versao_documento_competencia_v115(p_id_documento uuid, p_id_arquivo uuid, p_motivo text, p_chave_idempotencia text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_doc public.documentos_competencia%rowtype;
  v_arquivo public.arquivos%rowtype;
  v_num integer;
  v_ver uuid;
  v_job uuid;
  v_cmd jsonb;
  v_resultado jsonb;
  v_motivo_obrigatorio boolean;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.documentos_competencia where id=p_id_documento),'documentos_competencia','editar',(select id_contrato from public.documentos_competencia where id=p_id_documento));

  select * into v_doc from public.documentos_competencia where id=p_id_documento;
  if v_doc.id is null then raise exception using errcode='PT404',message='Documento não encontrado.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa()
     or not privado.usuario_tem_acesso_contrato(v_doc.id_contrato)
     or not privado.usuario_possui_perfil(v_doc.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite criar uma nova versão deste documento.';
  end if;

  v_cmd:=privado.v110_iniciar_comando(
    v_doc.id_organizacao,'v115.adicionar_versao_documento_competencia',p_chave_idempotencia,
    jsonb_build_object('id_documento',v_doc.id,'id_arquivo',p_id_arquivo,'motivo',nullif(btrim(coalesce(p_motivo,'')),''))
  );
  if v_cmd ? 'resposta' then return v_cmd->'resposta'; end if;

  select * into v_doc from public.documentos_competencia where id=p_id_documento for update;
  v_arquivo:=privado.v110_validar_arquivo_contrato(p_id_arquivo,v_doc.id_organizacao,v_doc.id_contrato);
  select exists(select 1 from public.execucoes_analise e where e.id_competencia=v_doc.id_competencia)
    into v_motivo_obrigatorio;
  if v_motivo_obrigatorio and nullif(btrim(coalesce(p_motivo,'')),'') is null then
    raise exception using errcode='PT400',message='Informe o motivo da nova versão porque esta competência já possui análise registrada.';
  end if;

  select coalesce(max(numero_versao),0)+1 into v_num
    from public.versoes_documento where id_documento_competencia=v_doc.id;
  insert into public.versoes_documento(
    id_organizacao,id_contrato,id_documento_competencia,numero_versao,id_arquivo,hash,motivo_substituicao,enviado_por
  ) values(
    v_doc.id_organizacao,v_doc.id_contrato,v_doc.id,v_num,v_arquivo.id,v_arquivo.sha256,
    nullif(btrim(coalesce(p_motivo,'')),''),auth.uid()
  ) returning id into v_ver;
  update public.documentos_competencia set versao_atual=v_num where id=v_doc.id;
  v_job:=privado.enfileirar_job(
    'documents',v_doc.id_organizacao,v_doc.id_contrato,'versao_documento',v_ver,
    jsonb_build_object('id_versao_documento',v_ver),'document:'||v_ver::text
  );
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_doc.id_organizacao,v_doc.id_contrato,v_ver,'documents','pendente');

  v_resultado:=privado.v115_concluir_comando(
    (v_cmd->>'id')::uuid,v_doc.id_organizacao,'VersaoDocumentoCompetenciaCriada','versoes_documento',v_ver,
    jsonb_build_object('id_competencia',v_doc.id_competencia,'id_documento',v_doc.id,'id_versao',v_ver,
      'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job,'motivo',nullif(btrim(coalesce(p_motivo,'')),'')),
    jsonb_build_object('id_competencia',v_doc.id_competencia,'id_documento',v_doc.id,'id_versao',v_ver,
      'numero_versao',v_num,'id_arquivo',v_arquivo.id,'id_job',v_job)
  );
  return v_resultado;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.obter_analise_competencia_v116(p_id_competencia uuid, p_resultados_offset integer DEFAULT 0, p_resultados_limite integer DEFAULT 25, p_execucoes_offset integer DEFAULT 0, p_execucoes_limite integer DEFAULT 10, p_apontamentos_offset integer DEFAULT 0, p_apontamentos_limite integer DEFAULT 25, p_filtro_resultado text DEFAULT NULL::text, p_filtro_criticidade text DEFAULT NULL::text, p_filtro_mecanismo text DEFAULT NULL::text, p_filtro_apontamento_status text DEFAULT NULL::text, p_busca text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_exec public.execucoes_analise%rowtype;
  v_hash_atual text; v_portao jsonb; v_estado text; v_stale boolean:=false;
  v_perfil_analise boolean:=false; v_situacao_permite boolean:=false; v_busy boolean:=false;
  v_resultados jsonb:='[]'::jsonb; v_resultados_total integer:=0;
  v_execucoes jsonb:='[]'::jsonb; v_execucoes_total integer:=0;
  v_apontamentos jsonb:='[]'::jsonb; v_apontamentos_total integer:=0;
  v_mecanismos jsonb:='{}'::jsonb; v_busca text:=nullif(trim(coalesce(p_busca,'')),'');
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'analises','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  if p_id_competencia is null then raise exception using errcode='PT400',message='Informe a competência para consultar a análise.'; end if;
  if p_resultados_offset<0 or p_execucoes_offset<0 or p_apontamentos_offset<0 or p_resultados_limite<1 or p_resultados_limite>100 or p_execucoes_limite<1 or p_execucoes_limite>50 or p_apontamentos_limite<1 or p_apontamentos_limite>100 then raise exception using errcode='PT400',message='Os parâmetros de paginação informados não são válidos.'; end if;
  if p_filtro_mecanismo is not null and p_filtro_mecanismo not in ('deterministico','semantico','humano','nao_identificado') then raise exception using errcode='PT400',message='O filtro de mecanismo não é válido.'; end if;
  if p_filtro_criticidade is not null and p_filtro_criticidade not in ('critica','alta','media','baixa','informativo') then raise exception using errcode='PT400',message='O filtro de criticidade não é válido.'; end if;
  if p_filtro_resultado is not null and p_filtro_resultado not in ('nao_enviado','recebido','pendente','em_analise','conforme','nao_conforme','inconclusivo','requer_revisao','nao_aplicavel') then raise exception using errcode='PT400',message='O filtro de resultado não é válido.'; end if;
  if p_filtro_apontamento_status is not null and p_filtro_apontamento_status not in ('aberto','em_tratamento','resolvido','descartado') then raise exception using errcode='PT400',message='O filtro de apontamento não é válido.'; end if;

  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then raise exception using errcode='PT404',message='Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato) then raise exception using errcode='42501',message='Você não possui acesso à competência informada.'; end if;
  v_perfil_analise:=privado.usuario_possui_perfil(v_comp.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]);
  if not v_perfil_analise then raise exception using errcode='42501',message='Seu perfil atual não permite consultar a análise desta competência.'; end if;

  select * into v_exec from public.execucoes_analise where id_competencia=v_comp.id order by criado_em desc,id desc limit 1;
  v_hash_atual:=privado.hash_contexto_competencia(v_comp.id);
  v_portao:=privado.avaliar_portao_conformidade(v_comp.id);
  v_situacao_permite:=v_comp.situacao not in ('apresentado','aguardando_contratante','validada','encerrada','cancelada');
  v_busy:=v_exec.id is not null and v_exec.status in ('pendente','processando');
  if v_exec.id is null then v_estado:='not_analyzed';
  elsif v_exec.status='pendente' then v_estado:='queued';
  elsif v_exec.status='processando' then v_estado:='processing';
  elsif v_exec.status in ('falhou','cancelada') then v_estado:='failed';
  elsif v_exec.status='concluida' then v_stale:=v_exec.hash_entrada is null or v_exec.hash_entrada<>v_hash_atual; v_estado:=case when v_stale then 'stale' else 'complete' end;
  else v_estado:='failed'; end if;

  select count(*)::integer into v_execucoes_total from public.execucoes_analise e where e.id_competencia=v_comp.id;
  select coalesce(jsonb_agg(x.obj order by x.criado_em desc,x.id desc),'[]'::jsonb) into v_execucoes from (
    select e.id,e.criado_em,jsonb_build_object('id',e.id,'tipo',e.tipo,'status',e.status,'hash_entrada',e.hash_entrada,'contexto_atual',coalesce(e.hash_entrada=v_hash_atual,false),'motor',e.motor,'versao_motor',e.versao_motor,'provedor',e.provedor,'modelo',e.modelo,'prompt_versao',e.prompt_versao,'iniciada_por',e.iniciada_por,'iniciada_em',e.iniciada_em,'concluida_em',e.concluida_em,'erro_codigo',e.erro_codigo,'requisitos_afetados',coalesce(to_jsonb(e.requisitos_afetados),'[]'::jsonb),'metadados',coalesce(e.metadados,'{}'::jsonb),'criado_em',e.criado_em) obj
    from public.execucoes_analise e where e.id_competencia=v_comp.id order by e.criado_em desc,e.id desc offset p_execucoes_offset limit p_execucoes_limite
  ) x;

  if v_exec.id is not null then
    with base as (
      select rr.*,r.codigo,r.descricao,r.categoria,r.criticidade,r.obrigatorio,r.aplicavel,r.impeditivo,r.efeito_portao,r.fonte_tipo,r.fonte_referencia,r.fonte_detalhe,
      case when rr.metadados->>'origem'='revisao_humana' then 'humano' when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo' when nullif(rr.metadados->>'provedor','') is not null then 'semantico' when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico' else 'nao_identificado' end mecanismo
      from public.resultados_requisitos rr join public.requisitos_competencia r on r.id=rr.id_requisito where rr.id_execucao=v_exec.id
    ), filtrado as (
      select * from base b where (p_filtro_resultado is null or b.resultado=p_filtro_resultado) and (p_filtro_criticidade is null or b.criticidade=p_filtro_criticidade) and (p_filtro_mecanismo is null or b.mecanismo=p_filtro_mecanismo) and (v_busca is null or coalesce(b.codigo,'') ilike '%'||v_busca||'%' or b.descricao ilike '%'||v_busca||'%')
    ), pagina as (
      select * from filtrado order by codigo nulls last,id_requisito,criado_em desc,id desc offset p_resultados_offset limit p_resultados_limite
    ), ev as (
      select e.id_resultado,jsonb_agg(jsonb_build_object('id',e.id,'id_versao_documento',e.id_versao_documento,'pagina',e.pagina,'trecho',e.trecho,'tipo_evidencia',e.tipo_evidencia,'referencia_externa',e.referencia_externa,'hash',e.hash,'criado_em',e.criado_em) order by e.criado_em,e.id) evidencias
      from public.evidencias_resultado e join pagina p on p.id=e.id_resultado group by e.id_resultado
    )
    select (select count(*)::integer from filtrado),coalesce((select jsonb_agg(jsonb_build_object('id_resultado',p.id,'id_requisito',p.id_requisito,'requisito',jsonb_build_object('codigo',p.codigo,'descricao',p.descricao,'categoria',p.categoria,'criticidade',p.criticidade,'obrigatorio',p.obrigatorio,'aplicavel',p.aplicavel,'impeditivo',p.impeditivo,'efeito_portao',p.efeito_portao,'fonte_tipo',p.fonte_tipo,'fonte_referencia',p.fonte_referencia,'fonte_detalhe',p.fonte_detalhe),'resultado',p.resultado,'mecanismo',p.mecanismo,'confianca',p.confianca,'justificativa',p.justificativa,'fundamento',p.fundamento,'hash_evidencias',p.hash_evidencias,'metadados',coalesce(p.metadados,'{}'::jsonb),'evidencias',coalesce(ev.evidencias,'[]'::jsonb),'criado_em',p.criado_em) order by p.codigo nulls last,p.id_requisito,p.criado_em desc,p.id desc) from pagina p left join ev on ev.id_resultado=p.id),'[]'::jsonb)
    into v_resultados_total,v_resultados;

    with b as (select case when rr.metadados->>'origem'='revisao_humana' then 'humano' when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo' when nullif(rr.metadados->>'provedor','') is not null then 'semantico' when nullif(v_exec.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico' else 'nao_identificado' end mecanismo from public.resultados_requisitos rr where rr.id_execucao=v_exec.id)
    select jsonb_build_object('deterministico',count(*) filter(where mecanismo='deterministico'),'semantico',count(*) filter(where mecanismo='semantico'),'humano',count(*) filter(where mecanismo='humano'),'nao_identificado',count(*) filter(where mecanismo='nao_identificado')) into v_mecanismos from b;
  end if;

  select count(*)::integer into v_apontamentos_total from public.apontamentos_internos a left join public.requisitos_competencia r on r.id=a.id_requisito where a.id_competencia=v_comp.id and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status) and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade) and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%');
  select coalesce(jsonb_agg(x.obj order by x.criado_em desc,x.id desc),'[]'::jsonb) into v_apontamentos from (
    select a.id,a.criado_em,jsonb_build_object('id',a.id,'id_requisito',a.id_requisito,'requisito',case when r.id is null then null else jsonb_build_object('codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria,'criticidade',r.criticidade) end,'descricao',a.descricao,'severidade',a.severidade,'status',a.status,'origem',a.origem,'regra_violada',a.regra_violada,'acao_sugerida',a.acao_sugerida,'fonte',coalesce(a.fonte,'{}'::jsonb),'criado_em',a.criado_em,'atualizado_em',a.atualizado_em) obj
    from public.apontamentos_internos a left join public.requisitos_competencia r on r.id=a.id_requisito where a.id_competencia=v_comp.id and (p_filtro_apontamento_status is null or a.status=p_filtro_apontamento_status) and (p_filtro_criticidade is null or a.severidade=p_filtro_criticidade) and (v_busca is null or a.descricao ilike '%'||v_busca||'%' or coalesce(r.codigo,'') ilike '%'||v_busca||'%' or coalesce(r.descricao,'') ilike '%'||v_busca||'%') order by a.criado_em desc,a.id desc offset p_apontamentos_offset limit p_apontamentos_limite
  ) x;

  return jsonb_build_object('schema_versao','v116-v1','competencia',jsonb_build_object('id',v_comp.id,'id_organizacao',v_comp.id_organizacao,'id_contrato',v_comp.id_contrato,'competencia_referencia',v_comp.competencia_referencia,'periodo_inicio',v_comp.periodo_inicio,'periodo_fim',v_comp.periodo_fim,'situacao',v_comp.situacao),'estado_analise',v_estado,'stale',v_stale,'hash_contexto_atual',v_hash_atual,'execucao_atual',case when v_exec.id is null then null else jsonb_build_object('id',v_exec.id,'tipo',v_exec.tipo,'status',v_exec.status,'hash_entrada',v_exec.hash_entrada,'motor',v_exec.motor,'versao_motor',v_exec.versao_motor,'provedor',v_exec.provedor,'modelo',v_exec.modelo,'prompt_versao',v_exec.prompt_versao,'iniciada_por',v_exec.iniciada_por,'iniciada_em',v_exec.iniciada_em,'concluida_em',v_exec.concluida_em,'erro_codigo',v_exec.erro_codigo,'requisitos_afetados',coalesce(to_jsonb(v_exec.requisitos_afetados),'[]'::jsonb),'metadados',coalesce(v_exec.metadados,'{}'::jsonb),'criado_em',v_exec.criado_em) end,'percentual',coalesce((v_portao->>'percentual')::numeric,0),'blocking_summary',v_portao,'allowed_actions',jsonb_build_object('executar_analise',v_perfil_analise and v_situacao_permite and not v_busy and (v_exec.id is null or v_exec.status in ('falhou','cancelada')),'reanalisar',v_perfil_analise and v_situacao_permite and not v_busy and v_exec.id is not null and v_exec.status='concluida','abrir_requisito',v_exec.id is not null),'mecanismos',coalesce(v_mecanismos,'{}'::jsonb),'resultados',v_resultados,'resultados_paginacao',jsonb_build_object('offset',p_resultados_offset,'limite',p_resultados_limite,'total',v_resultados_total),'execucoes',v_execucoes,'execucoes_paginacao',jsonb_build_object('offset',p_execucoes_offset,'limite',p_execucoes_limite,'total',v_execucoes_total),'apontamentos',v_apontamentos,'apontamentos_paginacao',jsonb_build_object('offset',p_apontamentos_offset,'limite',p_apontamentos_limite,'total',v_apontamentos_total));
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.obter_detalhe_requisito_v117(p_id_competencia uuid, p_id_requisito uuid, p_evidencias_offset integer DEFAULT 0, p_evidencias_limite integer DEFAULT 25, p_historico_offset integer DEFAULT 0, p_historico_limite integer DEFAULT 25, p_apontamentos_offset integer DEFAULT 0, p_apontamentos_limite integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_req public.requisitos_competencia%rowtype;
  v_exec public.execucoes_analise%rowtype;
  v_atual public.resultados_requisitos%rowtype;
  v_ultimo public.resultados_requisitos%rowtype;
  v_na_valido boolean;
  v_evidencias jsonb := '[]'::jsonb;
  v_historico jsonb := '[]'::jsonb;
  v_apontamentos jsonb := '[]'::jsonb;
  v_evidencias_total integer := 0;
  v_historico_total integer := 0;
  v_apontamentos_total integer := 0;
  v_capacidades jsonb;
  v_mecanismo text;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'analises','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  if p_id_competencia is null or p_id_requisito is null then
    raise exception using errcode='PT400', message='Informe a competência e o requisito.';
  end if;
  if p_evidencias_offset is null or p_historico_offset is null or p_apontamentos_offset is null
    or p_evidencias_limite is null or p_historico_limite is null or p_apontamentos_limite is null
    or p_evidencias_offset < 0 or p_historico_offset < 0 or p_apontamentos_offset < 0
    or p_evidencias_limite not between 1 and 100 or p_historico_limite not between 1 and 100
    or p_apontamentos_limite not between 1 and 100 then
    raise exception using errcode='PT400', message='Paginação inválida para o detalhe do requisito.';
  end if;
  if auth.uid() is null then
    raise exception using errcode='42501',message='Você não possui acesso a este requisito.';
  end if;
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null then
    raise exception using errcode='PT404',message='Requisito não encontrado.';
  end if;
  if not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
    or not privado.usuario_possui_perfil(
      v_comp.id_organizacao,
      array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
    ) then
    raise exception using errcode='42501',message='Você não possui acesso a este requisito.';
  end if;
  select * into v_req from public.requisitos_competencia
  where id=p_id_requisito and id_competencia=v_comp.id
    and id_contrato=v_comp.id_contrato and id_organizacao=v_comp.id_organizacao;
  if v_req.id is null then
    raise exception using errcode='PT404',message='Requisito não encontrado.';
  end if;
  -- Fonte única para capacidades; não duplicar regras de análise do V1-16.
  v_capacidades := (public.obter_analise_competencia_v116(
    v_comp.id,0,1,0,1,0,1,null,null,null,null,null
  ))->'allowed_actions';
  select * into v_exec from public.execucoes_analise e
    where e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
      and e.id_organizacao=v_comp.id_organizacao
    order by e.criado_em desc,e.id desc limit 1;
  if v_exec.id is not null then
    select * into v_atual from public.resultados_requisitos rr
      where rr.id_execucao=v_exec.id and rr.id_requisito=v_req.id
        and rr.id_competencia=v_comp.id and rr.id_contrato=v_comp.id_contrato
        and rr.id_organizacao=v_comp.id_organizacao
      order by rr.criado_em desc,rr.id desc limit 1;
  end if;
  -- Referencia do portão = último resultado daquele requisito em qualquer execução.
  select * into v_ultimo from public.resultados_requisitos rr
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao
    order by rr.criado_em desc,rr.id desc limit 1;
  v_na_valido := v_ultimo.id is not null and v_ultimo.resultado='nao_aplicavel'
    and nullif(trim(coalesce(v_ultimo.fundamento,'')),'') is not null
    and exists (select 1 from public.evidencias_resultado ev
      where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
        and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao);
  if v_ultimo.id is not null then
    v_mecanismo := case
      when v_ultimo.metadados->>'origem'='revisao_humana' then 'humano'
      when v_ultimo.metadados->>'mecanismo' in ('deterministico','semantico','humano')
        then v_ultimo.metadados->>'mecanismo'
      when nullif(v_ultimo.metadados->>'provedor','') is not null then 'semantico'
      when exists (select 1 from public.execucoes_analise ee where ee.id=v_ultimo.id_execucao
        and nullif(ee.provedor,'') is not null and v_ultimo.metadados->>'origem' is null)
        then 'semantico'
      else 'nao_identificado'
    end;
    select count(*)::integer into v_evidencias_total
      from public.evidencias_resultado ev where ev.id_resultado=v_ultimo.id
        and ev.id_competencia=v_comp.id and ev.id_contrato=v_comp.id_contrato
        and ev.id_organizacao=v_comp.id_organizacao;
    select coalesce(jsonb_agg(q.obj order by q.criado_em,q.id),'[]'::jsonb)
    into v_evidencias from (
      select ev.id,ev.criado_em,
        jsonb_build_object(
          'id',ev.id,'id_resultado',ev.id_resultado,
          'id_versao_documento',ev.id_versao_documento,
          'pagina',ev.pagina,'trecho',ev.trecho,'tipo_evidencia',ev.tipo_evidencia,
          'referencia_externa',ev.referencia_externa,'hash',ev.hash,'criado_em',ev.criado_em,
          'documento',case when vd.id is null then null else jsonb_build_object(
            'id_versao_documento',vd.id,'numero_versao',vd.numero_versao,
            'hash_versao',vd.hash,'id_arquivo',a.id,
            'nome_original',a.nome_original,'mime',a.mime,'status_seguranca',a.status_seguranca
          ) end
        ) obj
      from public.evidencias_resultado ev
      left join public.versoes_documento vd on vd.id=ev.id_versao_documento
        and vd.id_contrato=v_comp.id_contrato and vd.id_organizacao=v_comp.id_organizacao
      left join public.arquivos a on a.id=vd.id_arquivo
        and a.id_organizacao=v_comp.id_organizacao and a.id_contrato=v_comp.id_contrato
      where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
        and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao
      order by ev.criado_em,ev.id offset p_evidencias_offset limit p_evidencias_limite
    ) q;
  end if;
  select count(*)::integer into v_historico_total
    from public.resultados_requisitos rr join public.execucoes_analise ee on ee.id=rr.id_execucao
      and ee.id_competencia=v_comp.id and ee.id_contrato=v_comp.id_contrato
      and ee.id_organizacao=v_comp.id_organizacao
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao;
  select coalesce(jsonb_agg(q.obj order by q.exec_criado desc,q.exec_id desc,q.res_criado desc,q.res_id desc),'[]'::jsonb)
  into v_historico from (
    select rr.id res_id,rr.criado_em res_criado,ee.id exec_id,ee.criado_em exec_criado,
      jsonb_build_object(
        'id_resultado',rr.id,'id_execucao',ee.id,'resultado',rr.resultado,
        'confianca',rr.confianca,'fundamento',rr.fundamento,'justificativa',rr.justificativa,
        'hash_evidencias',rr.hash_evidencias,'criado_em',rr.criado_em,
        'tipo_execucao',ee.tipo,'status_execucao',ee.status,
        'motor',ee.motor,'versao_motor',ee.versao_motor,'provedor',ee.provedor,
        'modelo',ee.modelo,'prompt_versao',ee.prompt_versao,'hash_entrada',ee.hash_entrada,
        'iniciada_em',ee.iniciada_em,'concluida_em',ee.concluida_em,
        'mecanismo',case
          when rr.metadados->>'origem'='revisao_humana' then 'humano'
          when rr.metadados->>'mecanismo' in ('deterministico','semantico','humano') then rr.metadados->>'mecanismo'
          when nullif(rr.metadados->>'provedor','') is not null then 'semantico'
          when nullif(ee.provedor,'') is not null and rr.metadados->>'origem' is null then 'semantico'
          else 'nao_identificado' end
      ) obj
    from public.resultados_requisitos rr join public.execucoes_analise ee
      on ee.id=rr.id_execucao and ee.id_competencia=v_comp.id
      and ee.id_contrato=v_comp.id_contrato and ee.id_organizacao=v_comp.id_organizacao
    where rr.id_requisito=v_req.id and rr.id_competencia=v_comp.id
      and rr.id_contrato=v_comp.id_contrato and rr.id_organizacao=v_comp.id_organizacao
    order by ee.criado_em desc,ee.id desc,rr.criado_em desc,rr.id desc
    offset p_historico_offset limit p_historico_limite
  ) q;
  select count(*)::integer into v_apontamentos_total
    from public.apontamentos_internos ap
    where ap.id_requisito=v_req.id and ap.id_competencia=v_comp.id
      and ap.id_contrato=v_comp.id_contrato and ap.id_organizacao=v_comp.id_organizacao;
  select coalesce(jsonb_agg(q.obj order by q.criado_em desc,q.id desc),'[]'::jsonb)
  into v_apontamentos from (
    select ap.id,ap.criado_em,jsonb_build_object(
      'id',ap.id,'descricao',ap.descricao,'severidade',ap.severidade,
      'status',ap.status,'origem',ap.origem,'regra_violada',ap.regra_violada,
      'acao_sugerida',ap.acao_sugerida,'fonte',ap.fonte,
      'criado_em',ap.criado_em,'atualizado_em',ap.atualizado_em
    ) obj from public.apontamentos_internos ap
    where ap.id_requisito=v_req.id and ap.id_competencia=v_comp.id
      and ap.id_contrato=v_comp.id_contrato and ap.id_organizacao=v_comp.id_organizacao
    order by ap.criado_em desc,ap.id desc
    offset p_apontamentos_offset limit p_apontamentos_limite
  ) q;
  return jsonb_build_object(
    'schema_versao','v117-v1',
    'competencia',jsonb_build_object(
      'id',v_comp.id,'id_organizacao',v_comp.id_organizacao,
      'id_contrato',v_comp.id_contrato,'competencia_referencia',v_comp.competencia_referencia,
      'situacao',v_comp.situacao
    ),
    'requisito',jsonb_build_object(
      'id',v_req.id,'codigo',v_req.codigo,'descricao',v_req.descricao,
      'categoria',v_req.categoria,'origem_tipo',v_req.origem_tipo,
      'origem_id',v_req.origem_id,'origem_versao',v_req.origem_versao,
      'obrigatorio',v_req.obrigatorio,'aplicavel',v_req.aplicavel,
      'impeditivo',v_req.impeditivo,'criticidade',v_req.criticidade,
      'fonte_tipo',v_req.fonte_tipo,'fonte_referencia',v_req.fonte_referencia,
      'fonte_detalhe',v_req.fonte_detalhe,'efeito_portao',v_req.efeito_portao,
      'hash_snapshot',v_req.hash_snapshot,'regra_validacao',v_req.regra_validacao,
      'condicao_aplicabilidade',v_req.condicao_aplicabilidade
    ),
    'execucao_atual',case when v_exec.id is null then null else jsonb_build_object(
      'id',v_exec.id,'tipo',v_exec.tipo,'status',v_exec.status,
      'hash_entrada',v_exec.hash_entrada,'motor',v_exec.motor,
      'versao_motor',v_exec.versao_motor,'provedor',v_exec.provedor,
      'modelo',v_exec.modelo,'prompt_versao',v_exec.prompt_versao,
      'iniciada_em',v_exec.iniciada_em,'concluida_em',v_exec.concluida_em,
      'criado_em',v_exec.criado_em
    ) end,
    'resultado_atual',case when v_atual.id is null then null else jsonb_build_object(
      'id',v_atual.id,'id_execucao',v_atual.id_execucao,
      'resultado',v_atual.resultado,'confianca',v_atual.confianca,
      'justificativa',v_atual.justificativa,'fundamento',v_atual.fundamento,
      'hash_evidencias',v_atual.hash_evidencias,'criado_em',v_atual.criado_em
    ) end,
    'resultado_referencia',case when v_ultimo.id is null then null else jsonb_build_object(
      'id',v_ultimo.id,'id_execucao',v_ultimo.id_execucao,
      'resultado',v_ultimo.resultado,'mecanismo',v_mecanismo,
      'confianca',v_ultimo.confianca,'justificativa',v_ultimo.justificativa,
      'fundamento',v_ultimo.fundamento,'hash_evidencias',v_ultimo.hash_evidencias,
      'criado_em',v_ultimo.criado_em
    ) end,
    'na_validade',case when v_ultimo.resultado='nao_aplicavel' then jsonb_build_object(
      'valido',v_na_valido,'id_resultado_referencia',v_ultimo.id,
      'possui_fundamento',nullif(trim(coalesce(v_ultimo.fundamento,'')),'') is not null,
      'possui_evidencia',exists (select 1 from public.evidencias_resultado ev
          where ev.id_resultado=v_ultimo.id and ev.id_competencia=v_comp.id
          and ev.id_contrato=v_comp.id_contrato and ev.id_organizacao=v_comp.id_organizacao)
    ) else null end,
    'allowed_actions',coalesce(v_capacidades,'{}'::jsonb),
    'evidencias',v_evidencias,
    'evidencias_paginacao',jsonb_build_object('offset',p_evidencias_offset,'limite',p_evidencias_limite,'total',v_evidencias_total),
    'historico',v_historico,
    'historico_paginacao',jsonb_build_object('offset',p_historico_offset,'limite',p_historico_limite,'total',v_historico_total),
    'apontamentos',v_apontamentos,
    'apontamentos_paginacao',jsonb_build_object('offset',p_apontamentos_offset,'limite',p_apontamentos_limite,'total',v_apontamentos_total)
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.avaliar_portao_conformidade(p_id_competencia uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org uuid; v_contrato uuid; v_total int:=0; v_ok int:=0; v_pend int:=0; v_nok int:=0; v_inc int:=0; v_analise int:=0; v_nc int:=0; v_percent numeric(5,2):=0; v_liberado boolean:=false;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'analises','consultar',(select id_contrato from public.competencias where id=p_id_competencia));

  select id_organizacao,id_contrato into v_org,v_contrato from public.competencias where id=p_id_competencia;
  if v_org is null then raise exception 'Não encontramos a competência informada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  with ultimos as (
    select distinct on (r.id_requisito) r.id_requisito,r.resultado,r.fundamento,r.id
    from public.resultados_requisitos r where r.id_competencia=p_id_competencia order by r.id_requisito,r.criado_em desc,r.id desc
  ), avaliacao as (
    select req.id,coalesce(u.resultado,'pendente') resultado,
      case when u.resultado='nao_aplicavel' and nullif(trim(coalesce(u.fundamento,'')),'') is not null and exists(select 1 from public.evidencias_resultado e where e.id_resultado=u.id) then true else false end na_valido
    from public.requisitos_competencia req left join ultimos u on u.id_requisito=req.id
    where req.id_competencia=p_id_competencia and req.obrigatorio=true and req.aplicavel=true and req.efeito_portao=true
  )
  select count(*)::int,
         count(*) filter(where resultado='conforme' or (resultado='nao_aplicavel' and na_valido))::int,
         count(*) filter(where resultado='pendente' or (resultado='nao_aplicavel' and not na_valido))::int,
         count(*) filter(where resultado='nao_conforme')::int,
         count(*) filter(where resultado='inconclusivo')::int,
         count(*) filter(where resultado='em_analise')::int
    into v_total,v_ok,v_pend,v_nok,v_inc,v_analise from avaliacao;
  select count(*)::int into v_nc
  from public.nao_conformidades nc
  join public.controles_conformidade c on c.id=nc.id_controle
  left join public.aplicabilidades_controle ac on ac.id_controle=c.id and ac.id_contrato=v_contrato and ac.ativo=true
  where nc.id_organizacao=v_org and nc.id_contrato=v_contrato
    and (nc.id_competencia is null or nc.id_competencia=p_id_competencia)
    and nc.status not in ('resolvida','encerrada','aceita')
    and coalesce(ac.bloqueia_competencia,c.bloqueia_competencia,false)=true;
  v_percent:=case when v_total=0 then 0 else round((v_ok::numeric/v_total::numeric)*100,2) end;
  v_liberado:=(v_total>0 and v_ok=v_total and v_pend=0 and v_nok=0 and v_inc=0 and v_analise=0 and v_nc=0);
  return jsonb_build_object('total',v_total,'conformes_ou_na_validos',v_ok,'pendentes',v_pend,'nao_conformes',v_nok,'inconclusivos',v_inc,'em_analise',v_analise,'nao_conformidades_bloqueantes',v_nc,'percentual',v_percent,'liberado',v_liberado);
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.solicitar_analise_competencia(p_id_competencia uuid, p_tipo text DEFAULT 'completa'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.competencias%rowtype;
  v_exec uuid;
  v_snapshot jsonb;
  v_hash text;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'analises','processar',(select id_contrato from public.competencias where id=p_id_competencia));

  select * into v
  from public.competencias
  where id=p_id_competencia
  for update;

  if v.id is null then
    raise exception 'Não encontramos a competência informada.';
  end if;
  if p_tipo not in ('completa','reanálise','parcial') then
    raise exception 'O tipo de análise informado não é válido.';
  end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise exception 'Seu usuário não possui acesso a este contrato.';
  end if;
  if not privado.usuario_possui_perfil(
    v.id_organizacao,
    array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
  ) then
    raise exception 'Seu perfil atual não permite solicitar esta análise.';
  end if;
  if v.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then
    raise exception 'A situação atual desta competência não permite iniciar uma nova análise.';
  end if;

  select ea.id into v_exec
  from public.execucoes_analise ea
  where ea.id_competencia=v.id
    and ea.status in ('pendente','processando')
  order by ea.criado_em desc
  limit 1;

  if v_exec is not null then
    return v_exec;
  end if;

  v_snapshot:=privado.snapshot_contexto_competencia(v.id);
  v_hash:=encode(extensions.digest(v_snapshot::text,'sha256'),'hex');

  insert into public.execucoes_analise(
    id_organizacao,id_contrato,id_competencia,tipo,status,hash_entrada,motor,
    versao_motor,prompt_versao,iniciada_por,iniciada_em,snapshot_entrada
  ) values(
    v.id_organizacao,v.id_contrato,v.id,p_tipo,'pendente',v_hash,'contaos',
    '4.1','analise-pt-BR-v4.1',auth.uid(),now(),v_snapshot
  ) returning id into v_exec;

  update public.competencias
  set situacao=case when p_tipo='reanálise' then 'em_reanalise' else 'em_analise' end
  where id=v.id;

  perform privado.enfileirar_job(
    'ai',v.id_organizacao,v.id_contrato,'execucao_analise',v_exec,
    jsonb_build_object('entidade_tipo','execucao_analise','id_execucao',v_exec,'id_competencia',v.id),
    'analysis:'||v_exec::text
  );

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,'AnaliseSolicitada','execucoes_analise',v_exec,null,
    jsonb_build_object('id_competencia',v.id,'tipo',p_tipo,'hash_entrada',v_hash,'versao_snapshot','4.1')
  );
  return v_exec;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.solicitar_reanalise_requisitos(p_id_competencia uuid, p_requisitos uuid[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_comp public.competencias%rowtype;
  v_busy public.execucoes_analise%rowtype;
  v_ids uuid[];
  v_busy_ids uuid[];
  v_exec uuid;
  v_written uuid;
begin
  if not privado.rbac_permite((select id_organizacao from public.competencias where id=p_id_competencia),'analises','processar',(select id_contrato from public.competencias where id=p_id_competencia)) then raise sqlstate '42501' using message='Você não possui autorização para solicitar reanálise.'; end if;

  if auth.uid() is null then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  if p_id_competencia is null or p_requisitos is null or cardinality(p_requisitos)=0
    or exists(select 1 from unnest(p_requisitos) as q(id) where q.id is null) then
    raise exception using errcode='PT400',message='Selecione ao menos um requisito válido para reanálise.';
  end if;
  select * into v_comp from public.competencias where id=p_id_competencia;
  if v_comp.id is null
    or not privado.usuario_tem_acesso_contrato(v_comp.id_contrato)
    or not privado.usuario_possui_perfil(
      v_comp.id_organizacao,
      array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]
    ) then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  -- Mesma trava que privado.solicitar_analise_competencia, serializa selecoes.
  select * into v_comp from public.competencias
    where id=p_id_competencia and id_contrato=v_comp.id_contrato
      and id_organizacao=v_comp.id_organizacao for update;
  if v_comp.id is null then
    raise exception using errcode='42501',message='Você não possui autorização para solicitar reanálise.';
  end if;
  if v_comp.situacao in ('apresentado','aguardando_contratante','validada','encerrada','cancelada') then
    raise exception using errcode='PT409',message='A situação da competência não permite reanálise.';
  end if;
  select array_agg(q.id order by q.id) into v_ids
    from (select distinct id from unnest(p_requisitos) as z(id)) q;
  if exists(
    select 1 from unnest(v_ids) as q(id)
    where not exists (
      select 1 from public.requisitos_competencia r
      where r.id=q.id and r.id_competencia=v_comp.id
        and r.id_contrato=v_comp.id_contrato
        and r.id_organizacao=v_comp.id_organizacao
    )
  ) then
    raise exception using errcode='PT400',message='A seleção contém requisito inválido para esta competência.';
  end if;
  select * into v_busy from public.execucoes_analise e
    where e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
      and e.id_organizacao=v_comp.id_organizacao
      and e.status in ('pendente','processando')
    order by e.criado_em desc,e.id desc limit 1;
  if v_busy.id is not null then
    select coalesce(array_agg(q.id order by q.id),array[]::uuid[]) into v_busy_ids
    from (select distinct id from unnest(v_busy.requisitos_afetados) as z(id)) q;
    if v_busy.tipo='parcial' and v_busy_ids=v_ids then
      -- Repeticao idempotente, zero UPDATE na execucao existente.
      return v_busy.id;
    end if;
    raise exception using errcode='PT409',
      message='Já existe uma análise em andamento. Consulte o andamento antes de solicitar outra.';
  end if;
  -- O INSERT da execucao e sua fila só ficam visíveis ao worker após COMMIT.
  v_exec := privado.solicitar_analise_competencia(v_comp.id,'parcial');
  update public.execucoes_analise e
  set requisitos_afetados=v_ids,
      metadados=e.metadados || jsonb_build_object('reanálise_incremental',true)
  where e.id=v_exec and e.id_competencia=v_comp.id and e.id_contrato=v_comp.id_contrato
    and e.id_organizacao=v_comp.id_organizacao
    and e.tipo='parcial' and e.status='pendente'
    and cardinality(e.requisitos_afetados)=0
  returning e.id into v_written;
  if v_written is null then
    raise exception using errcode='PT409',
      message='Não foi possível garantir o escopo desta reanálise. Atualize a competência e tente novamente.';
  end if;
  perform privado.registrar_evento_auditoria(
    v_comp.id_organizacao,'ReanaliseIncrementalSolicitada',
    'execucoes_analise',v_exec,null,
    jsonb_build_object('id_competencia',v_comp.id,'requisitos_afetados',to_jsonb(v_ids))
  );
  return v_exec;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.registrar_resultado_requisito(p_id_execucao uuid, p_id_requisito uuid, p_resultado text, p_justificativa text DEFAULT NULL::text, p_fundamento text DEFAULT NULL::text, p_evidencias jsonb DEFAULT '[]'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_exec public.execucoes_analise%rowtype; v_req public.requisitos_competencia%rowtype; v_id uuid; v_ev jsonb; v_portao jsonb;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.execucoes_analise where id=p_id_execucao),'analises','editar',(select id_contrato from public.execucoes_analise where id=p_id_execucao));

  select * into v_exec from public.execucoes_analise where id=p_id_execucao;
  select * into v_req from public.requisitos_competencia where id=p_id_requisito;
  if v_exec.id is null or v_req.id is null or v_exec.id_competencia<>v_req.id_competencia then raise exception 'Execução/requisito inválido.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v_exec.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_exec.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','auditor','juridico_conformidade','financeiro','contabilidade','rh_dp']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  if p_resultado not in ('pendente','em_analise','conforme','nao_conforme','inconclusivo','nao_aplicavel') then raise exception 'Resultado inválido.'; end if;
  if p_resultado='nao_aplicavel' and nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Não aplicável exige fundamento.'; end if;
  insert into public.resultados_requisitos(id_organizacao,id_contrato,id_competencia,id_execucao,id_requisito,resultado,justificativa,fundamento,metadados)
  values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_exec.id,v_req.id,p_resultado,p_justificativa,p_fundamento,jsonb_build_object('origem','revisao_humana')) returning id into v_id;
  if jsonb_typeof(coalesce(p_evidencias,'[]'::jsonb))='array' then
    for v_ev in select * from jsonb_array_elements(coalesce(p_evidencias,'[]'::jsonb)) loop
      insert into public.evidencias_resultado(id_organizacao,id_contrato,id_competencia,id_resultado,id_versao_documento,pagina,trecho,tipo_evidencia,referencia_externa,hash)
      values(v_exec.id_organizacao,v_exec.id_contrato,v_exec.id_competencia,v_id,nullif(v_ev->>'id_versao_documento','')::uuid,nullif(v_ev->>'pagina','')::integer,v_ev->>'trecho',coalesce(v_ev->>'tipo_evidencia','documento'),v_ev->>'referencia_externa',v_ev->>'hash');
    end loop;
  end if;
  v_portao:=privado.avaliar_portao_conformidade(v_exec.id_competencia);
  update public.competencias set percentual_conformidade=coalesce((v_portao->>'percentual')::numeric,0) where id=v_exec.id_competencia;
  perform privado.registrar_evento_auditoria(v_exec.id_organizacao,'ResultadoRequisitoRegistrado','resultados_requisitos',v_id,null,jsonb_build_object('id_requisito',v_req.id,'resultado',p_resultado));
  return v_id;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.solicitar_parecer_interno(p_id_competencia uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.competencias%rowtype; v_job uuid;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'pareceres','criar',(select id_contrato from public.competencias where id=p_id_competencia));

 select * into v from public.competencias where id=p_id_competencia;
 if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
 if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
 if coalesce((privado.avaliar_portao_conformidade(v.id)->>'liberado')::boolean,false) is not true then raise exception 'O parecer final somente pode ser gerado depois que os requisitos obrigatórios estiverem integralmente tratados.'; end if;
 v_job:=privado.enfileirar_job('ai',v.id_organizacao,v.id_contrato,'gerar_parecer_interno',v.id,jsonb_build_object('entidade_tipo','gerar_parecer_interno','id_competencia',v.id),'parecer:'||v.id::text||':'||v.versao_registro::text);
 return v_job;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.aprovar_parecer_interno(p_id_parecer uuid, p_aprovar boolean, p_fundamento text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.pareceres_internos%rowtype;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.pareceres_internos where id=p_id_parecer),'pareceres','aprovar',(select id_contrato from public.pareceres_internos where id=p_id_parecer));

  select * into v
  from public.pareceres_internos
  where id = p_id_parecer
  for update;

  if v.id is null then
    raise exception 'Não encontramos o parecer informado.';
  end if;

  if auth.uid() is null
     or not privado.usuario_tem_acesso_contrato(v.id_contrato)
     or not privado.usuario_possui_perfil(
       v.id_organizacao,
       array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]
     ) then
    raise sqlstate '42501' using
      message = 'Você não tem permissão para aprovar este parecer.',
      detail = 'A operação exige acesso ao contrato e perfil autorizado na organização.',
      hint = 'Selecione um contrato ao qual seu usuário tenha acesso ou procure um administrador autorizado.';
  end if;

  if v.autor = auth.uid() then
    raise exception 'O parecer deve ser aprovado por uma pessoa diferente de quem o elaborou.';
  end if;

  update public.pareceres_internos
     set status = case when p_aprovar then 'aprovado' else 'rejeitado' end,
         aprovado_por = auth.uid(),
         aprovado_em = now()
   where id = v.id;

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,
    'ParecerInternoRevisado',
    'pareceres_internos',
    v.id,
    null,
    jsonb_build_object('aprovado',p_aprovar,'fundamento',p_fundamento)
  );
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.aprovar_apresentacao(p_id_competencia uuid, p_fundamento text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.competencias%rowtype; v_portao jsonb; v_exec uuid; v_exec_hash text; v_exec_tipo text; v_parecer uuid; v_aprov uuid; v_hash_atual text;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'apresentacoes','aprovar',(select id_contrato from public.competencias where id=p_id_competencia));

  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Não encontramos a competência informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Seu usuário não possui acesso a este contrato.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato']::text[]) then raise exception 'Seu perfil atual não permite liberar esta apresentação.'; end if;
  if v.situacao not in ('em_analise','em_reanalise','pendente_correcao','rascunho') then raise exception 'A situação atual desta competência ainda não permite a liberação.'; end if;
  v_portao:=privado.avaliar_portao_conformidade(v.id);
  if coalesce((v_portao->>'liberado')::boolean,false) is not true then raise exception 'A competência ainda não atingiu 100,00%% de conformidade dos requisitos obrigatórios e aplicáveis.'; end if;
  select id into v_parecer from public.pareceres_internos where id_competencia=v.id and status='aprovado' order by versao desc limit 1;
  if v_parecer is null then raise exception 'Antes de liberar a apresentação, gere o parecer interno e obtenha a aprovação do responsável autorizado.'; end if;
  select id,hash_entrada,tipo into v_exec,v_exec_hash,v_exec_tipo from public.execucoes_analise where id_competencia=v.id and status='concluida' order by concluida_em desc nulls last,criado_em desc limit 1;
  if v_exec is null or v_exec_tipo not in ('completa','reanálise') then raise exception 'Execute uma análise completa ou reanálise concluída antes de liberar a apresentação.'; end if;
  v_hash_atual:=privado.hash_contexto_competencia(v.id);
  if v_exec_hash is distinct from v_hash_atual then raise exception 'Os documentos ou dados da competência foram alterados após a análise. Execute nova análise completa antes de liberar a apresentação.'; end if;
  insert into public.aprovacoes(id_organizacao,id_contrato,id_competencia,tipo,status,aprovado_por,fundamento,hash_contexto,percentual_conformidade,id_execucao_analise)
  values(v.id_organizacao,v.id_contrato,v.id,'apresentacao','aprovada',auth.uid(),p_fundamento,v_hash_atual,100.00,v_exec) returning id into v_aprov;
  update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100.00,liberada_para_apresentacao_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'CompetenciaLiberadaParaApresentacao','competencias',v.id,jsonb_build_object('situacao',v.situacao),jsonb_build_object('situacao','pode_apresentar_contratante','id_aprovacao',v_aprov,'id_parecer',v_parecer,'hash_contexto',v_hash_atual));
  return jsonb_build_object('id_aprovacao',v_aprov,'situacao','pode_apresentar_contratante','percentual_conformidade',100.00,'id_parecer',v_parecer,'hash_contexto',v_hash_atual);
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.registrar_apresentacao(p_id_competencia uuid, p_idempotency_key text, p_protocolo text DEFAULT NULL::text, p_forma_apresentacao text DEFAULT NULL::text, p_id_comprovante_arquivo uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.competencias%rowtype; v_pacote uuid; v_num integer; v_hash text; v_apres uuid; v_exist uuid; v_hash_atual text; v_hash_aprovado text; v_hash_exec text;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.competencias where id=p_id_competencia),'apresentacoes','apresentar',(select id_contrato from public.competencias where id=p_id_competencia));

  if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency_key obrigatório.'; end if;
  select * into v from public.competencias where id=p_id_competencia for update;
  if v.id is null then raise exception 'Competência não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','gestor_contrato','prestacao_contas','direcao_aprovador']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  select id into v_exist from public.apresentacoes_contratante where id_organizacao=v.id_organizacao and idempotency_key=p_idempotency_key;
  if v_exist is not null then return v_exist; end if;
  if v.situacao <> 'pode_apresentar_contratante' then raise exception 'Competência não liberada para apresentação.'; end if;
  v_hash_atual:=privado.hash_contexto_competencia(v.id);
  select a.hash_contexto into v_hash_aprovado from public.aprovacoes a where a.id_competencia=v.id and a.tipo='apresentacao' and a.status='aprovada' order by a.criado_em desc limit 1;
  if v_hash_aprovado is null then raise exception 'Aprovação humana ausente.'; end if;
  if v_hash_aprovado is distinct from v_hash_atual then raise exception 'Os documentos ou dados mudaram após a aprovação. Execute nova análise e nova aprovação antes de apresentar.'; end if;
  select e.hash_entrada into v_hash_exec from public.execucoes_analise e where e.id_competencia=v.id and e.status='concluida' and e.tipo in ('completa','reanálise') order by e.concluida_em desc nulls last,e.criado_em desc limit 1;
  if v_hash_exec is distinct from v_hash_atual then raise exception 'A análise concluída não corresponde mais aos documentos e dados atuais. Execute nova análise antes de apresentar.'; end if;
  select coalesce(max(numero),0)+1 into v_num from public.pacotes_competencia where id_competencia=v.id and tipo='apresentacao';
  select encode(extensions.digest(string_agg(x.hash,'|' order by x.id::text),'sha256'),'hex') into v_hash from (
    select vd.id,vd.hash from public.versoes_documento vd join public.documentos_competencia dc on dc.id=vd.id_documento_competencia where dc.id_competencia=v.id and dc.situacao='ativo'
    union all
    select pi.id,pi.hash from public.pareceres_internos pi where pi.id_competencia=v.id and pi.status='aprovado'
  ) x;
  v_hash:=coalesce(v_hash,encode(extensions.digest(v.id::text,'sha256'),'hex'));
  insert into public.pacotes_competencia(id_organizacao,id_contrato,id_competencia,numero,tipo,status,hash_pacote,criado_por,congelado_em)
  values(v.id_organizacao,v.id_contrato,v.id,v_num,'apresentacao','congelado',v_hash,auth.uid(),now()) returning id into v_pacote;
  insert into public.itens_pacote_competencia(id_organizacao,id_contrato,id_competencia,id_pacote,entidade_tipo,entidade_id,versao_id,hash,ordem)
  select v.id_organizacao,v.id_contrato,v.id,v_pacote,'documento_competencia',dc.id,vd.id,vd.hash,row_number() over(order by dc.tipo,dc.id)
  from public.documentos_competencia dc join lateral (select * from public.versoes_documento x where x.id_documento_competencia=dc.id order by numero_versao desc limit 1) vd on true
  where dc.id_competencia=v.id and dc.situacao='ativo';
  insert into public.apresentacoes_contratante(id_organizacao,id_contrato,id_competencia,id_pacote,numero_rodada,tipo,protocolo,forma_apresentacao,id_comprovante_arquivo,idempotency_key,apresentado_por)
  values(v.id_organizacao,v.id_contrato,v.id,v_pacote,1,'apresentacao',p_protocolo,p_forma_apresentacao,p_id_comprovante_arquivo,p_idempotency_key,auth.uid()) returning id into v_apres;
  update public.pacotes_competencia set status='apresentado' where id=v_pacote;
  update public.competencias set situacao='aguardando_contratante',versao_pacote_atual=v_num where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'ApresentacaoRegistrada','apresentacoes_contratante',v_apres,null,jsonb_build_object('id_competencia',v.id,'id_pacote',v_pacote,'protocolo',p_protocolo,'hash_contexto',v_hash_atual));
  return v_apres;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.enfileirar_ingestao_historica_hml(p_id_relatorio uuid, p_id_versao_documento uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r public.relatorios_historicos_contratante%ROWTYPE; v public.versoes_documento%ROWTYPE; e uuid; m bigint;
BEGIN
  perform privado.exigir_permissao_rbac((select id_organizacao from public.relatorios_historicos_contratante where id=p_id_relatorio),'historico','processar',(select id_contrato from public.relatorios_historicos_contratante where id=p_id_relatorio));

 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO r FROM public.relatorios_historicos_contratante WHERE id=p_id_relatorio FOR UPDATE;
 SELECT * INTO v FROM public.versoes_documento WHERE id=p_id_versao_documento;
 IF r.id IS NULL OR v.id IS NULL THEN RAISE EXCEPTION 'Relatório ou versão documental não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(r.id_contrato) OR NOT privado.usuario_possui_perfil(r.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão.'; END IF;
 IF r.id_arquivo<>v.id_arquivo OR r.id_organizacao<>v.id_organizacao OR r.id_contrato<>v.id_contrato THEN RAISE EXCEPTION 'Versão não pertence ao relatório deste contrato.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.processamentos_documento WHERE id_versao_documento=v.id AND status='concluido') THEN RAISE EXCEPTION 'Aguarde a conclusão da leitura documental.'; END IF;
 SELECT id INTO e FROM public.execucoes_assincronas WHERE fila='historico' AND id_organizacao=r.id_organizacao AND chave_idempotencia='historico:'||r.id::text;
 IF e IS NOT NULL THEN RETURN e; END IF;
 SELECT pgmq.send('historico',pg_catalog.jsonb_build_object('id_relatorio',r.id,'id_versao_documento',v.id,'id_organizacao',r.id_organizacao,'id_contrato',r.id_contrato)) INTO m;
 INSERT INTO public.execucoes_assincronas(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,chave_idempotencia,message_id) VALUES(r.id_organizacao,r.id_contrato,'historico','relatorio_historico',r.id,'historico:'||r.id::text,m) RETURNING id INTO e;
 PERFORM privado.registrar_evento_auditoria(r.id_organizacao,'IngestaoHistoricaEnfileirada','relatorios_historicos_contratante',r.id,NULL,pg_catalog.jsonb_build_object('id_execucao',e,'id_versao_documento',v.id));
 RETURN e;
END;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.registrar_relatorio_historico_hml(p_id_arquivo uuid, p_competencia date, p_tipo text DEFAULT 'relatorio_contratante'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_arquivo public.arquivos%ROWTYPE; v_id uuid;
BEGIN
  perform privado.exigir_permissao_rbac((select id_organizacao from public.arquivos where id=p_id_arquivo),'historico','criar',(select id_contrato from public.arquivos where id=p_id_arquivo));

 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO v_arquivo FROM public.arquivos WHERE id=p_id_arquivo;
 IF NOT FOUND THEN RAISE EXCEPTION 'Arquivo não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(v_arquivo.id_contrato) OR NOT privado.usuario_possui_perfil(v_arquivo.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão para importar histórico.'; END IF;
 IF v_arquivo.status_seguranca <> 'aprovado' THEN RAISE EXCEPTION 'Arquivo ainda não aprovado pela validação de segurança.'; END IF;
 IF p_competencia IS NULL OR extract(day FROM p_competencia) <> 1 THEN RAISE EXCEPTION 'Informe o primeiro dia da competência.'; END IF;
 IF p_tipo NOT IN ('relatorio_contratante','parecer_contratante','resposta_contratante','outro') THEN RAISE EXCEPTION 'Tipo de relatório inválido.'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id_arquivo::text,0));
 SELECT id INTO v_id FROM public.relatorios_historicos_contratante WHERE id_arquivo=p_id_arquivo AND id_contrato=v_arquivo.id_contrato ORDER BY criado_em LIMIT 1;
 IF v_id IS NOT NULL THEN RETURN v_id; END IF;
 INSERT INTO public.relatorios_historicos_contratante(id_organizacao,id_contrato,id_arquivo,competencia_referencia,tipo,origem_temporal,status_processamento,criado_por)
 VALUES(v_arquivo.id_organizacao,v_arquivo.id_contrato,v_arquivo.id,p_competencia,p_tipo,'pre_implantacao','pendente',auth.uid()) RETURNING id INTO v_id;
 PERFORM privado.registrar_evento_auditoria(v_arquivo.id_organizacao,'HistoricoImportacaoRegistrada','relatorios_historicos_contratante',v_id,NULL,pg_catalog.jsonb_build_object('id_arquivo',p_id_arquivo,'competencia',p_competencia));
 RETURN v_id;
END;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION public.vincular_tratamento_historico_hml(p_id_apontamento uuid, p_resposta text DEFAULT NULL::text, p_desfecho text DEFAULT NULL::text, p_fundamento text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a public.apontamentos_historicos%ROWTYPE; vr uuid; vd uuid;
BEGIN
  perform privado.exigir_permissao_rbac((select id_organizacao from public.apontamentos_historicos where id=p_id_apontamento),'historico','editar',(select id_contrato from public.apontamentos_historicos where id=p_id_apontamento));

 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO a FROM public.apontamentos_historicos WHERE id=p_id_apontamento;
 IF a.id IS NULL THEN RAISE EXCEPTION 'Apontamento não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(a.id_contrato) OR NOT privado.usuario_possui_perfil(a.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão.'; END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_resposta,'')),'') IS NULL AND nullif(pg_catalog.btrim(coalesce(p_desfecho,'')),'') IS NULL THEN RAISE EXCEPTION 'Informe resposta ou desfecho.'; END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_resposta,'')),'') IS NOT NULL THEN
 INSERT INTO public.respostas_historicas(id_organizacao,id_contrato,id_apontamento,texto) VALUES(a.id_organizacao,a.id_contrato,a.id,left(pg_catalog.btrim(p_resposta),12000)) RETURNING id INTO vr;
 END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_desfecho,'')),'') IS NOT NULL THEN
 INSERT INTO public.desfechos_historicos(id_organizacao,id_contrato,id_apontamento,resultado,fundamento,data) VALUES(a.id_organizacao,a.id_contrato,a.id,left(pg_catalog.btrim(p_desfecho),5000),nullif(left(pg_catalog.btrim(coalesce(p_fundamento,'')),5000),''),CURRENT_DATE) RETURNING id INTO vd;
 END IF;
 PERFORM privado.registrar_evento_auditoria(a.id_organizacao,'TratamentoHistoricoVinculado','apontamentos_historicos',a.id,NULL,pg_catalog.jsonb_build_object('id_resposta',vr,'id_desfecho',vd));
 RETURN pg_catalog.jsonb_build_object('id_resposta',vr,'id_desfecho',vd);
END;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.confirmar_upload_arquivo(p_id_organizacao uuid, p_id_contrato uuid, p_path text, p_nome_original text, p_mime text, p_tamanho bigint, p_sha256 text, p_origem text DEFAULT 'upload_usuario'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_cfg public.configuracao_upload%rowtype;
  v_ext text;
  v_tamanho_real bigint;
  v_mime_real text;
  v_padrao_path text;
begin
  perform privado.exigir_permissao_rbac(p_id_organizacao,'arquivos','criar',null::uuid);

  if auth.uid() is null then raise exception 'Para continuar, faça login novamente.'; end if;
  if not privado.usuario_tem_acesso_organizacao(p_id_organizacao) then raise exception 'Seu usuário não possui acesso à organização informada.'; end if;
  if p_id_contrato is not null and not privado.usuario_tem_acesso_contrato(p_id_contrato) then raise exception 'Seu usuário não possui acesso ao contrato informado.'; end if;

  v_padrao_path := '^' || p_id_organizacao::text || '/uploads/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}/[A-Za-z0-9._-]{1,180}$';
  if p_path is null or p_path !~ v_padrao_path then
    raise exception 'O caminho do arquivo não corresponde ao padrão seguro de upload desta organização.';
  end if;

  select * into v_cfg from public.configuracao_upload where id=true;
  if not found then raise exception 'A configuração de upload não está disponível.'; end if;

  v_ext := lower(regexp_replace(p_nome_original,'^.*\\.','','g'));
  if not (v_ext=any(v_cfg.extensoes_permitidas)) then raise exception 'Este formato de arquivo não é aceito pelo ContaOS.'; end if;
  if p_mime is null or not (lower(p_mime)=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo do arquivo enviado não é aceito pelo ContaOS.'; end if;
  if not privado.mime_compativel_extensao(v_ext, p_mime) then raise exception 'A extensão e o tipo do arquivo informado não são compatíveis.'; end if;
  if p_tamanho < 0 then raise exception 'O tamanho do arquivo informado é inválido.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and p_tamanho > v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo ultrapassa o limite configurado para este ambiente.'; end if;
  if p_sha256 !~ '^[0-9a-fA-F]{64}$' then raise exception 'Não foi possível confirmar a integridade do arquivo. Tente enviar novamente.'; end if;

  select
    case when (o.metadata->>'size') ~ '^[0-9]+$' then (o.metadata->>'size')::bigint else null end,
    lower(nullif(o.metadata->>'mimetype',''))
  into v_tamanho_real, v_mime_real
  from storage.objects o
  where o.bucket_id='contaos-documentos' and o.name=p_path;

  if not found then raise exception 'O upload ainda não foi concluído no armazenamento.'; end if;
  if v_tamanho_real is null then raise exception 'Não foi possível confirmar o tamanho real do arquivo armazenado.'; end if;
  if v_cfg.tamanho_maximo_bytes is not null and v_tamanho_real > v_cfg.tamanho_maximo_bytes then raise exception 'O arquivo armazenado ultrapassa o limite configurado para este ambiente.'; end if;
  if v_tamanho_real <> p_tamanho then raise exception 'O tamanho informado não corresponde ao arquivo realmente armazenado.'; end if;
  if v_mime_real is null or not (v_mime_real=any(v_cfg.mimes_permitidos)) then raise exception 'O tipo real registrado no armazenamento não é aceito pelo ContaOS.'; end if;
  if v_mime_real <> lower(p_mime) then raise exception 'O tipo informado não corresponde ao arquivo realmente armazenado.'; end if;
  if not privado.mime_compativel_extensao(v_ext, v_mime_real) then raise exception 'A extensão e o tipo real do arquivo armazenado não são compatíveis.'; end if;

  insert into public.arquivos(id_organizacao,id_contrato,bucket,path,nome_original,mime,tamanho,sha256,status_seguranca,origem,criado_por)
  values(p_id_organizacao,p_id_contrato,'contaos-documentos',p_path,p_nome_original,v_mime_real,v_tamanho_real,lower(p_sha256),'pendente',coalesce(nullif(trim(p_origem),''),'upload_usuario'),auth.uid())
  returning id into v_id;

  perform privado.registrar_evento_auditoria(
    p_id_organizacao,'UploadArquivoConfirmado','arquivos',v_id,null,
    jsonb_build_object('id_contrato',p_id_contrato,'nome_original',p_nome_original,'tamanho',v_tamanho_real,'mime',v_mime_real,'sha256',lower(p_sha256))
  );
  return v_id;
end;
$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.enfileirar_processamento_documento(p_id_versao_documento uuid, p_chave_idempotencia text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_org uuid; v_contrato uuid; v_exec uuid;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.versoes_documento where id=p_id_versao_documento),'arquivos','editar',(select id_contrato from public.versoes_documento where id=p_id_versao_documento));

  select id_organizacao,id_contrato into v_org,v_contrato from public.versoes_documento where id=p_id_versao_documento;
  if v_org is null then raise exception 'Versão documental não encontrada.'; end if;
  if not privado.usuario_tem_acesso_contrato(v_contrato) then raise exception 'Acesso negado.'; end if;
  if not privado.usuario_possui_perfil(v_org,array['administrador','gestor_contrato','prestacao_contas','financeiro','contabilidade','rh_dp','juridico_conformidade','auditor']::text[]) then raise exception 'Perfil sem permissão.'; end if;
  v_exec:=privado.enfileirar_job('documents',v_org,v_contrato,'versao_documento',p_id_versao_documento,jsonb_build_object('id_versao_documento',p_id_versao_documento),coalesce(p_chave_idempotencia,'document:'||p_id_versao_documento::text));
  insert into public.processamentos_documento(id_organizacao,id_contrato,id_versao_documento,etapa,status)
  values(v_org,v_contrato,p_id_versao_documento,'documents','pendente');
  return v_exec;
end;$function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.revisar_sugestao_extracao(p_id_sugestao uuid, p_aprovar boolean, p_conteudo_revisado text DEFAULT NULL::text, p_categoria_revisada text DEFAULT NULL::text, p_id_requisito_revisado uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.sugestoes_extracao_documento%rowtype; v_regra uuid; v_conteudo text; v_categoria text; v_req uuid;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.sugestoes_extracao_documento where id=p_id_sugestao),'arquivos','editar',(select id_contrato from public.sugestoes_extracao_documento where id=p_id_sugestao));

  select * into v from public.sugestoes_extracao_documento where id=p_id_sugestao for update;
  if v.id is null then raise exception 'Não encontramos a sugestão informada.'; end if;
  if auth.uid() is null or not privado.usuario_tem_acesso_contrato(v.id_contrato) then raise exception 'Você não possui acesso ao contrato desta sugestão.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then raise exception 'Seu perfil atual não permite revisar esta sugestão.'; end if;
  if v.status<>'pendente' then raise exception 'Esta sugestão já foi revisada anteriormente.'; end if;
  v_conteudo:=coalesce(nullif(trim(p_conteudo_revisado),''),v.conteudo);
  v_categoria:=coalesce(nullif(trim(p_categoria_revisada),''),v.categoria_sugerida);
  v_req:=coalesce(p_id_requisito_revisado,v.id_requisito_sugerido);
  if not p_aprovar then
    update public.sugestoes_extracao_documento set status='rejeitada',revisado_por=auth.uid(),revisado_em=now(),metadados=metadados||jsonb_build_object('conteudo_revisado',p_conteudo_revisado,'categoria_revisada',p_categoria_revisada) where id=v.id;
    perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoRejeitada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo));
    return jsonb_build_object('status','rejeitada','mensagem','A sugestão foi rejeitada e nenhuma regra ou metadado foi alterado.');
  end if;
  if v.tipo='classificacao' then
    update public.documentos_competencia d set categoria=coalesce(v_categoria,d.categoria),id_requisito_competencia=coalesce(v_req,d.id_requisito_competencia)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_competencia=d.id;
    update public.documentos_contrato d set categoria=coalesce(v_categoria,d.categoria)
    from public.versoes_documento vd where vd.id=v.id_versao_documento and vd.id_documento_contrato=d.id;
  elsif v.tipo='metadado' then
    update public.versoes_documento set metadados_extraidos=coalesce(metadados_extraidos,'{}'::jsonb)||coalesce(v.metadados->'campos','{}'::jsonb)||jsonb_build_object('resumo_revisado',v_conteudo,'revisado_por',auth.uid(),'revisado_em',now()) where id=v.id_versao_documento;
  else
    insert into public.regras_conformidade(id_organizacao,id_contrato,codigo,descricao,tipo,efeito_portao,configuracao,situacao)
    values(v.id_organizacao,v.id_contrato,'SUG-'||upper(substr(replace(v.id::text,'-',''),1,12)),v_conteudo,'assistida',false,jsonb_build_object('origem','sugestao_extracao','id_sugestao',v.id,'id_versao_documento',v.id_versao_documento,'pagina',v.pagina,'trecho_fonte',v.trecho_fonte,'tipo_sugestao',v.tipo,'observacao','Regra criada em rascunho após revisão humana. A ativação material exige fluxo próprio de aprovação.'),'rascunho') returning id into v_regra;
  end if;
  update public.sugestoes_extracao_documento set status='aprovada',conteudo=v_conteudo,categoria_sugerida=v_categoria,id_requisito_sugerido=v_req,revisado_por=auth.uid(),revisado_em=now() where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'SugestaoExtracaoAprovada','sugestoes_extracao_documento',v.id,null,jsonb_build_object('tipo',v.tipo,'id_regra_rascunho',v_regra));
  return jsonb_build_object('status','aprovada','id_regra_rascunho',v_regra,'mensagem',case when v_regra is null then 'A sugestão foi aprovada e aplicada ao documento.' else 'A sugestão foi aprovada e gerou uma regra em rascunho para revisão material.' end);
end; $function$
;

-- Explicit matrix guard; original business checks are preserved.
CREATE OR REPLACE FUNCTION privado.definir_vigencia_sugestao_extracao_v111(p_id_sugestao uuid, p_vigencia_inicio date, p_vigencia_fim date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.sugestoes_extracao_documento%rowtype;
begin
  perform privado.exigir_permissao_rbac((select id_organizacao from public.sugestoes_extracao_documento where id=p_id_sugestao),'arquivos','editar',(select id_contrato from public.sugestoes_extracao_documento where id=p_id_sugestao));

  select * into v from public.sugestoes_extracao_documento where id=p_id_sugestao for update;
  if v.id is null then raise exception using errcode='PT404',message='Não encontramos a sugestão informada.'; end if;
  if auth.uid() is null or not privado.sessao_usuario_ativa() or not privado.usuario_tem_acesso_contrato(v.id_contrato) then
    raise exception using errcode='42501',message='Você não possui acesso ao contrato desta sugestão.'; end if;
  if not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','direcao_aprovador','gestor_contrato','prestacao_contas','juridico_conformidade','auditor']::text[]) then
    raise exception using errcode='42501',message='Seu perfil atual não permite definir a vigência desta sugestão.'; end if;
  if v.status<>'pendente' then raise exception using errcode='PT409',message='Esta sugestão já foi revisada. Atualize a tela.'; end if;
  if p_vigencia_inicio is null then raise exception using errcode='PT400',message='Informe o início da vigência da regra extraída.'; end if;
  if p_vigencia_fim is not null and p_vigencia_fim<p_vigencia_inicio then raise exception using errcode='PT400',message='O fim da vigência não pode ser anterior ao início.'; end if;
  if v.vigencia_inicio is not distinct from p_vigencia_inicio and v.vigencia_fim is not distinct from p_vigencia_fim then
    return jsonb_build_object('status','sem_alteracao','vigencia_inicio',v.vigencia_inicio,'vigencia_fim',v.vigencia_fim);
  end if;
  update public.sugestoes_extracao_documento set vigencia_inicio=p_vigencia_inicio,vigencia_fim=p_vigencia_fim where id=v.id;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'VigenciaSugestaoExtracaoDefinida','sugestoes_extracao_documento',v.id,
    jsonb_build_object('vigencia_inicio',v.vigencia_inicio,'vigencia_fim',v.vigencia_fim),
    jsonb_build_object('vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim));
  return jsonb_build_object('status','atualizada','vigencia_inicio',p_vigencia_inicio,'vigencia_fim',p_vigencia_fim);
end;$function$
;

create or replace function public.pode_consultar_auditoria_organizacao(p_id_organizacao uuid)
returns boolean language sql stable security invoker set search_path='' as $$
select privado.rbac_permite(p_id_organizacao,'auditoria','consultar',null)
and privado.usuario_possui_perfil(p_id_organizacao,array['administrador','auditor','juridico_conformidade']::text[])
$$;
notify pgrst,'reload schema';
commit;
