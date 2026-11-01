begin;

create table public.eventos_acesso_pacote_evidencias (
  id uuid primary key default gen_random_uuid(),
  id_organizacao uuid not null references public.organizacoes(id) on delete restrict,
  id_pacote uuid not null references public.pacotes_evidencias(id) on delete restrict,
  id_acesso uuid references public.acessos_pacote_evidencias(id) on delete set null,
  resultado text not null check(resultado in ('permitido','expirado','revogado','limite_atingido','token_invalido','pacote_indisponivel')),
  ip_hash text,
  user_agent_hash text,
  metadados jsonb not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);
create index eventos_acesso_pacote_idx on public.eventos_acesso_pacote_evidencias(id_pacote,criado_em desc);
alter table public.eventos_acesso_pacote_evidencias enable row level security;
create policy eventos_acesso_pacote_select on public.eventos_acesso_pacote_evidencias for select to authenticated using(privado.usuario_possui_perfil(id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]));

create trigger eventos_acesso_pacote_immutable before update or delete on public.eventos_acesso_pacote_evidencias for each row execute function privado.bloquear_mutacao_historico();

create or replace function public.validar_acesso_temporario_pacote(p_token text,p_ip_hash text default null,p_user_agent_hash text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_hash text; v_acesso public.acessos_pacote_evidencias%rowtype; v_pacote public.pacotes_evidencias%rowtype; v_resultado text; v_permitido boolean:=false;
begin
  v_hash:=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex');
  select * into v_acesso from public.acessos_pacote_evidencias where token_hash=v_hash for update;
  if v_acesso.id is null then
    return jsonb_build_object('permitido',false,'codigo','TOKEN_INVALIDO','titulo','Acesso não reconhecido','mensagem','Este link de acesso não é válido ou não está mais disponível.');
  end if;
  select * into v_pacote from public.pacotes_evidencias where id=v_acesso.id_pacote;
  if v_acesso.revogado_em is not null then v_resultado:='revogado';
  elsif v_acesso.expira_em<=now() then v_resultado:='expirado';
  elsif v_acesso.max_acessos is not null and v_acesso.quantidade_acessos>=v_acesso.max_acessos then v_resultado:='limite_atingido';
  elsif v_pacote.id is null or v_pacote.status<>'disponivel' or (v_pacote.expira_em is not null and v_pacote.expira_em<=now()) then v_resultado:='pacote_indisponivel';
  else v_resultado:='permitido'; v_permitido:=true; end if;

  insert into public.eventos_acesso_pacote_evidencias(id_organizacao,id_pacote,id_acesso,resultado,ip_hash,user_agent_hash,metadados)
  values(v_acesso.id_organizacao,v_acesso.id_pacote,v_acesso.id,v_resultado,p_ip_hash,p_user_agent_hash,jsonb_build_object('acesso_numero',v_acesso.quantidade_acessos+case when v_permitido then 1 else 0 end));

  if v_permitido then
    update public.acessos_pacote_evidencias set quantidade_acessos=quantidade_acessos+1 where id=v_acesso.id;
    perform privado.registrar_evento_auditoria(v_acesso.id_organizacao,'PacoteEvidenciasAcessado','pacotes_evidencias',v_acesso.id_pacote,null,jsonb_build_object('id_acesso',v_acesso.id,'quantidade_acessos',v_acesso.quantidade_acessos+1));
    return jsonb_build_object('permitido',true,'id_pacote',v_pacote.id,'id_organizacao',v_pacote.id_organizacao,'id_contrato',v_pacote.id_contrato,'id_arquivo_exportacao',v_pacote.id_arquivo_exportacao,'expira_em',v_acesso.expira_em,'acessos_restantes',case when v_acesso.max_acessos is null then null else greatest(v_acesso.max_acessos-(v_acesso.quantidade_acessos+1),0) end);
  end if;

  return jsonb_build_object('permitido',false,'codigo',upper(v_resultado),'titulo',case v_resultado when 'expirado' then 'Acesso expirado' when 'revogado' then 'Acesso revogado' when 'limite_atingido' then 'Limite de acessos atingido' else 'Pacote indisponível' end,'mensagem',case v_resultado when 'expirado' then 'O período autorizado para consultar este pacote terminou.' when 'revogado' then 'Este acesso foi revogado pelo responsável.' when 'limite_atingido' then 'Este link atingiu o número máximo de acessos permitido.' else 'O pacote de evidências não está disponível neste momento.' end);
end;$$;
revoke all on function public.validar_acesso_temporario_pacote(text,text,text) from public,anon,authenticated;
grant execute on function public.validar_acesso_temporario_pacote(text,text,text) to service_role;

create or replace function privado.revogar_acesso_temporario_pacote(p_id_acesso uuid,p_fundamento text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.acessos_pacote_evidencias%rowtype;
begin
  select * into v from public.acessos_pacote_evidencias where id=p_id_acesso for update;
  if v.id is null then raise exception 'Não encontramos o acesso temporário informado.'; end if;
  if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite revogar este acesso.'; end if;
  if nullif(trim(coalesce(p_fundamento,'')),'') is null then raise exception 'Informe o motivo da revogação.'; end if;
  if v.revogado_em is null then update public.acessos_pacote_evidencias set revogado_em=now() where id=v.id; end if;
  perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasRevogado','acessos_pacote_evidencias',v.id,null,jsonb_build_object('id_pacote',v.id_pacote,'fundamento',p_fundamento));
end;$$;
create or replace function public.revogar_acesso_temporario_pacote(p_id_acesso uuid,p_fundamento text)
returns void language sql security invoker set search_path='' as $$select privado.revogar_acesso_temporario_pacote($1,$2)$$;
revoke all on function public.revogar_acesso_temporario_pacote(uuid,text) from public,anon;
grant execute on function public.revogar_acesso_temporario_pacote(uuid,text) to authenticated;

-- Atualiza a criação do acesso com validações e sem permitir expiração além do pacote.
create or replace function privado.criar_acesso_temporario_pacote(p_id_pacote uuid,p_expira_em timestamptz,p_descricao_destinatario text default null,p_max_acessos integer default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.pacotes_evidencias%rowtype; v_token text; v_hash text; v_id uuid;
begin
 select * into v from public.pacotes_evidencias where id=p_id_pacote;
 if v.id is null then raise exception 'Não encontramos o pacote de evidências informado.'; end if;
 if v.status<>'disponivel' then raise exception 'O pacote precisa estar disponível antes de criar um acesso temporário.'; end if;
 if auth.uid() is null or not privado.usuario_possui_perfil(v.id_organizacao,array['administrador','auditor','juridico_conformidade']::text[]) then raise exception 'Seu perfil atual não permite compartilhar este pacote.'; end if;
 if p_expira_em<=now() then raise exception 'A data de expiração deve ser futura.'; end if;
 if v.expira_em is not null and p_expira_em>v.expira_em then raise exception 'O acesso não pode expirar depois do próprio pacote.'; end if;
 if p_max_acessos is not null and p_max_acessos<1 then raise exception 'O limite de acessos deve ser maior que zero.'; end if;
 v_token:='ev_'||encode(extensions.gen_random_bytes(32),'hex'); v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
 insert into public.acessos_pacote_evidencias(id_organizacao,id_pacote,token_hash,descricao_destinatario,expira_em,max_acessos,criado_por)
 values(v.id_organizacao,v.id,v_hash,p_descricao_destinatario,p_expira_em,p_max_acessos,auth.uid()) returning id into v_id;
 perform privado.registrar_evento_auditoria(v.id_organizacao,'AcessoPacoteEvidenciasCriado','acessos_pacote_evidencias',v_id,null,jsonb_build_object('id_pacote',v.id,'expira_em',p_expira_em,'max_acessos',p_max_acessos));
 return jsonb_build_object('id',v_id,'token_uma_vez',v_token,'expira_em',p_expira_em,'max_acessos',p_max_acessos);
end;$$;

commit;
