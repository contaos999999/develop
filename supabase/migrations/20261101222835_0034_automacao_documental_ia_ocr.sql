begin;

create table if not exists public.configuracoes_automacao (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete cascade,
  provedor_ia text not null default 'openai_compatible',
  modelo_ia text,
  provedor_ocr text not null default 'rest_compatible',
  modo_ia text not null default 'assistido' check (modo_ia in ('desativado','assistido')),
  modo_ocr text not null default 'assistido' check (modo_ocr in ('desativado','assistido')),
  configuracao_publica jsonb not null default '{}'::jsonb,
  ativo boolean not null default true,
  versao_registro bigint not null default 1,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique(id_organizacao)
);
alter table public.configuracoes_automacao enable row level security;
create policy configuracoes_automacao_select on public.configuracoes_automacao for select to authenticated using (privado.usuario_tem_acesso_organizacao(id_organizacao));
create policy configuracoes_automacao_insert on public.configuracoes_automacao for insert to authenticated with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create policy configuracoes_automacao_update on public.configuracoes_automacao for update to authenticated using (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[])) with check (privado.usuario_possui_perfil(id_organizacao,array['administrador']::text[]));
create trigger configuracoes_automacao_touch before update on public.configuracoes_automacao for each row execute function privado.tocar_atualizado_em();
grant select,insert,update on public.configuracoes_automacao to authenticated;
revoke delete,truncate,references,trigger on public.configuracoes_automacao from authenticated,anon;

create or replace function privado.enfileirar_extracao_assistida_documento()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_hash text; v_contrato uuid; v_org uuid;
begin
  if new.etapa='documents' and new.status='concluido' and (old.status is distinct from new.status) then
    select vd.hash,vd.id_contrato,vd.id_organizacao into v_hash,v_contrato,v_org from public.versoes_documento vd where vd.id=new.id_versao_documento;
    if v_org is not null then
      perform privado.enfileirar_job('ai',v_org,v_contrato,'extrair_documento',new.id_versao_documento,jsonb_build_object('entidade_tipo','extrair_documento','id_versao_documento',new.id_versao_documento),'extrair-doc:'||new.id_versao_documento::text||':'||coalesce(v_hash,'sem_hash'));
    end if;
  end if;
  return new;
end; $$;
revoke all on function privado.enfileirar_extracao_assistida_documento() from public,anon,authenticated;
drop trigger if exists processamentos_documento_enfileirar_ia on public.processamentos_documento;
create trigger processamentos_documento_enfileirar_ia after update of status on public.processamentos_documento for each row execute function privado.enfileirar_extracao_assistida_documento();

create or replace function privado.revisar_sugestao_extracao(p_id_sugestao uuid,p_aprovar boolean,p_conteudo_revisado text default null,p_categoria_revisada text default null,p_id_requisito_revisado uuid default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v public.sugestoes_extracao_documento%rowtype; v_regra uuid; v_conteudo text; v_categoria text; v_req uuid;
begin
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
end; $$;

create or replace function public.revisar_sugestao_extracao(p_id_sugestao uuid,p_aprovar boolean,p_conteudo_revisado text default null,p_categoria_revisada text default null,p_id_requisito_revisado uuid default null)
returns jsonb language sql security invoker set search_path='' as $$ select privado.revisar_sugestao_extracao($1,$2,$3,$4,$5); $$;
revoke all on function public.revisar_sugestao_extracao(uuid,boolean,text,text,uuid) from public,anon;
grant execute on function public.revisar_sugestao_extracao(uuid,boolean,text,text,uuid) to authenticated;

create or replace function public.worker_obter_contexto_documento(p_id_versao uuid)
returns jsonb language sql stable security definer set search_path=''
as $$
select jsonb_build_object(
 'versao',to_jsonb(vd),
 'arquivo',to_jsonb(a),
 'documento_competencia',case when dc.id is null then null else to_jsonb(dc) end,
 'documento_contrato',case when dco.id is null then null else to_jsonb(dco) end,
 'paginas',coalesce((select jsonb_agg(jsonb_build_object('pagina',p.numero_pagina,'texto',p.texto_extraido) order by p.numero_pagina) from public.paginas_documento p where p.id_versao_documento=vd.id),'[]'::jsonb),
 'requisitos',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'codigo',r.codigo,'descricao',r.descricao,'categoria',r.categoria) order by r.ordem) from public.requisitos_competencia r join public.competencias c on c.id=r.id_competencia where c.id_contrato=vd.id_contrato and c.situacao not in ('encerrada','cancelada')),'[]'::jsonb)
)
from public.versoes_documento vd join public.arquivos a on a.id=vd.id_arquivo
left join public.documentos_competencia dc on dc.id=vd.id_documento_competencia
left join public.documentos_contrato dco on dco.id=vd.id_documento_contrato
where vd.id=p_id_versao;
$$;
revoke all on function public.worker_obter_contexto_documento(uuid) from public,anon,authenticated;
grant execute on function public.worker_obter_contexto_documento(uuid) to service_role;

commit;
