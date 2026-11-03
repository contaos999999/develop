-- V1-08 follow-up: alinha wrappers ao padrão V107 e torna remoção replay-safe.
begin;

-- O wrapper SECURITY INVOKER precisa executar somente a função privada endpoint.
grant execute on function privado.salvar_proposta_orcamentaria_v108(uuid,uuid,uuid,text,bigint,text) to authenticated;
grant execute on function privado.registrar_versao_proposta_v108(uuid,uuid,date,date,uuid,text) to authenticated;
grant execute on function privado.salvar_linha_orcamentaria_v108(uuid,uuid,uuid,text,text,text,text,text,numeric,numeric,boolean,numeric,text,bigint,text) to authenticated;
grant execute on function privado.publicar_versao_proposta_v108(uuid,uuid,text,text,text) to authenticated;

-- A remoção recebe a versão explicitamente para revalidar escopo mesmo após o registro já ter sido apagado.
drop function if exists public.remover_linha_orcamentaria_v108(uuid,uuid,bigint,text);
drop function if exists privado.remover_linha_orcamentaria_v108(uuid,uuid,bigint,text);

create function privado.remover_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_versao_proposta uuid,p_id_linha uuid,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare l public.linhas_orcamentarias%rowtype; v public.versoes_proposta%rowtype; v_cmd jsonb; v_antes jsonb;
begin
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
end $$;
revoke all on function privado.remover_linha_orcamentaria_v108(uuid,uuid,uuid,bigint,text) from public,anon,authenticated;
grant execute on function privado.remover_linha_orcamentaria_v108(uuid,uuid,uuid,bigint,text) to authenticated;

create function public.remover_linha_orcamentaria_v108(p_id_organizacao uuid,p_id_versao_proposta uuid,p_id_linha uuid,p_versao_esperada bigint,p_chave_idempotencia text)
returns jsonb language sql security invoker set search_path='' as $$select privado.remover_linha_orcamentaria_v108(p_id_organizacao,p_id_versao_proposta,p_id_linha,p_versao_esperada,p_chave_idempotencia);$$;
revoke all on function public.remover_linha_orcamentaria_v108(uuid,uuid,uuid,bigint,text) from public,anon;
grant execute on function public.remover_linha_orcamentaria_v108(uuid,uuid,uuid,bigint,text) to authenticated;

commit;