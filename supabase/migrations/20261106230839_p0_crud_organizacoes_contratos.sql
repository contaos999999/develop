-- P0 CRUD: public invoker APIs, private authorization, optimistic locking and replay.
begin;
create function privado.crud_cadastro_transicoes_v1(p_entidade text,p_situacao text,p_master boolean)
returns jsonb language sql immutable set search_path='' as $$
select coalesce(jsonb_agg(jsonb_build_object('situacao',s,'rotulo',s)),'[]'::jsonb)
from unnest(case
 when p_entidade='organizacoes' and p_master then array_remove(array['ativa','inativa','suspensa'],p_situacao)
 when p_entidade='organizacoes' and p_situacao='ativa' then array['inativa']
 when p_entidade='organizacoes' and p_situacao='inativa' then array['ativa']
 when p_entidade='contratos' and p_situacao='rascunho' then array['ativo','cancelado']
 when p_entidade='contratos' and p_situacao='ativo' then array['suspenso','encerrado','cancelado']
 when p_entidade='contratos' and p_situacao='suspenso' then array['ativo','encerrado','cancelado']
 else array[]::text[] end) s
$$;

create function privado.crud_cadastro_consultar_v1(p_id_organizacao uuid,p_entidade text,p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r jsonb; editar boolean; m boolean; org_ativa boolean;
begin
 if p_entidade not in ('organizacoes','contratos') or p_entidade is null then
  raise exception using errcode='PT422',message='Cadastro inválido.';
 end if;
 perform privado.exigir_permissao_rbac(p_id_organizacao,p_entidade,'consultar',case when p_entidade='contratos' then p_id else null end);
 m:=privado.usuario_e_administrador_master();
 select situacao='ativa' into org_ativa from public.organizacoes where id=p_id_organizacao;
 if p_entidade='organizacoes' then
  if p_id is distinct from p_id_organizacao then raise exception using errcode='42501',message='Contexto inválido.'; end if;
  select jsonb_build_object('id',id,'id_organizacao',id,'razao_social',razao_social,'nome_fantasia',nome_fantasia,'cnpj',cnpj,'situacao',situacao,'versao_registro',versao_registro,'atualizado_em',atualizado_em)
  into r from public.organizacoes where id=p_id;
  editar:=privado.rbac_permite(p_id_organizacao,'organizacoes','administrar',null) and
   (m or privado.usuario_possui_perfil(p_id_organizacao,array['administrador']));
 else
  select jsonb_build_object('id',id,'id_organizacao',id_organizacao,'numero',numero,'objeto',objeto,'tipo_contrato',tipo_contrato,'unidade_vinculada',unidade_vinculada,'fonte_recurso',fonte_recurso,'inicio',inicio,'fim',fim,'valor_global',valor_global,'valor_mensal_referencia',valor_mensal_referencia,'periodicidade',periodicidade,'prazo_prestacao_dias',prazo_prestacao_dias,'dia_limite_apresentacao',dia_limite_apresentacao,'criticidade',criticidade,'situacao',situacao,'versao_registro',versao_registro,'atualizado_em',atualizado_em)
  into r from public.contratos where id=p_id and id_organizacao=p_id_organizacao;
  editar:=coalesce(org_ativa,false) and privado.rbac_permite(p_id_organizacao,'contratos','editar',p_id) and
   (m or privado.usuario_possui_perfil(p_id_organizacao,array['administrador','gestor_contrato']));
 end if;
 if r is null then raise exception using errcode='PT404',message='Cadastro não encontrado neste contexto.'; end if;
 return jsonb_build_object('schema_versao','crud-cadastro-v1','entidade',p_entidade,'registro',r,'pode_editar',editar,
  'transicoes',case when editar then privado.crud_cadastro_transicoes_v1(p_entidade,r->>'situacao',m) else '[]'::jsonb end,
  'exclusao_permitida',false,'motivo_retencao','Cadastro retido para preservar vínculos, histórico e auditoria.');
end $$;

create function privado.crud_cadastro_touch_v1() returns trigger language plpgsql set search_path='' as $$
begin
 -- Direct client UPDATE would bypass snapshots, reason and canonical lifecycle.
 if current_user='authenticated' then raise exception using errcode='42501',message='Use a operação oficial de gestão do cadastro.'; end if;
 new.atualizado_em:=now(); return new;
end $$;
drop trigger organizacoes_touch on public.organizacoes;
create trigger organizacoes_touch before update on public.organizacoes for each row execute function privado.crud_cadastro_touch_v1();
drop trigger contratos_touch on public.contratos;
create trigger contratos_touch before update on public.contratos for each row execute function privado.crud_cadastro_touch_v1();

create function privado.crud_cadastro_mutar_v1(p_id_organizacao uuid,p_entidade text,p_id uuid,p_versao_esperada bigint,p_acao text,p_alteracoes jsonb,p_motivo text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 contexto jsonb; antes jsonb; depois jsonb; resposta jsonb; v_comando text; hash text; existente public.comandos_idempotentes%rowtype;
 org public.organizacoes%rowtype; contrato public.contratos%rowtype; dados jsonb; permitidos text[]; evento uuid; prox integer;
begin
 if p_acao not in ('editar','situacao') or p_acao is null then raise exception using errcode='PT422',message='Operação inválida.'; end if;
 contexto:=privado.crud_cadastro_consultar_v1(p_id_organizacao,p_entidade,p_id);
 if not (contexto->>'pode_editar')::boolean then raise exception using errcode='42501',message='Sem permissão para administrar este cadastro.'; end if;
 if p_request_id is null or p_versao_esperada is null or p_versao_esperada<1 or length(trim(coalesce(p_motivo,''))) not between 3 and 2000 or jsonb_typeof(p_alteracoes) is distinct from 'object' then
  raise exception using errcode='PT422',message='Informe versão, identificador, alterações e motivo de 3 a 2000 caracteres.';
 end if;
 -- Organization first: stable lock order and no contract write during deactivation.
 if p_entidade='organizacoes' then
  select * into org from public.organizacoes where id=p_id_organizacao for update;
 else
  select * into org from public.organizacoes where id=p_id_organizacao for share;
  if org.situacao is distinct from 'ativa' then raise exception using errcode='42501',message='A organização precisa estar ativa.'; end if;
 end if;
 v_comando:='crud-cadastro-v1:'||p_entidade||':'||p_acao;
 hash:=encode(extensions.digest(jsonb_build_object('ator',auth.uid(),'org',p_id_organizacao,'id',p_id,'versao',p_versao_esperada,'acao',p_acao,'alteracoes',p_alteracoes,'motivo',p_motivo)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_id_organizacao::text||v_comando||p_request_id::text,0));
 contexto:=privado.crud_cadastro_consultar_v1(p_id_organizacao,p_entidade,p_id);
 if not (contexto->>'pode_editar')::boolean then raise exception using errcode='42501',message='A permissão de administração foi revogada.'; end if;
 select * into existente from public.comandos_idempotentes where id_organizacao=p_id_organizacao and comandos_idempotentes.comando=v_comando and chave=p_request_id::text;
 if found then
  if existente.hash_payload is distinct from hash or existente.status<>'concluido' then raise exception using errcode='PT409',message='Identificador já utilizado para outra operação.'; end if;
  return existente.resposta;
 end if;
 if p_entidade='contratos' then
  select * into contrato from public.contratos where id=p_id and id_organizacao=p_id_organizacao for update;
  if not found then raise exception using errcode='PT404',message='Contrato não encontrado.'; end if;
 end if;
 -- Recalculate after lock so a concurrent state transition cannot authorize stale choices.
 contexto:=privado.crud_cadastro_consultar_v1(p_id_organizacao,p_entidade,p_id); antes:=contexto->'registro';
 if not (contexto->>'pode_editar')::boolean then raise exception using errcode='42501',message='A permissão de administração foi revogada.'; end if;
 if (antes->>'versao_registro')::bigint<>p_versao_esperada then raise exception using errcode='PT409',message='Cadastro alterado por outra pessoa. Recarregue e revise suas alterações.'; end if;
 if p_acao='situacao' then
  permitidos:=array['situacao'];
  if not exists(select 1 from jsonb_array_elements(contexto->'transicoes') t where t->>'situacao'=p_alteracoes->>'situacao') then
   raise exception using errcode='PT422',message='Transição de situação não permitida.';
  end if;
 elsif p_entidade='organizacoes' then permitidos:=array['razao_social','nome_fantasia','cnpj'];
 else permitidos:=array['numero','objeto','tipo_contrato','unidade_vinculada','fonte_recurso','inicio','fim','valor_global','valor_mensal_referencia','periodicidade','prazo_prestacao_dias','dia_limite_apresentacao','criticidade']; end if;
 if p_alteracoes='{}'::jsonb or exists(select 1 from jsonb_object_keys(p_alteracoes) k where not(k=any(permitidos))) then raise exception using errcode='PT422',message='Campos não permitidos para esta operação.'; end if;
 dados:=antes||p_alteracoes;
 if p_entidade='organizacoes' then
  if nullif(trim(dados->>'razao_social'),'') is null then raise exception using errcode='PT422',message='Informe a razão social.'; end if;
  update public.organizacoes set razao_social=trim(dados->>'razao_social'),nome_fantasia=nullif(trim(dados->>'nome_fantasia'),''),cnpj=nullif(trim(dados->>'cnpj'),''),situacao=dados->>'situacao' where id=p_id;
 else
  if nullif(trim(dados->>'numero'),'') is null or nullif(trim(dados->>'objeto'),'') is null or nullif(trim(dados->>'periodicidade'),'') is null or dados->>'inicio' is null then raise exception using errcode='PT422',message='Informe número, objeto, início e periodicidade.'; end if;
  select coalesce(max(numero_versao),0)+1 into prox from public.versoes_contrato where id_contrato=p_id;
  if prox=1 then
   insert into public.versoes_contrato(id_organizacao,id_contrato,numero_versao,snapshot,hash,motivo,criado_por) values(p_id_organizacao,p_id,prox,to_jsonb(contrato),encode(extensions.digest(to_jsonb(contrato)::text,'sha256'),'hex'),'Estado anterior à primeira edição operacional',auth.uid()); prox:=prox+1;
  end if;
  update public.contratos set numero=trim(dados->>'numero'),objeto=trim(dados->>'objeto'),tipo_contrato=dados->>'tipo_contrato',unidade_vinculada=dados->>'unidade_vinculada',fonte_recurso=dados->>'fonte_recurso',inicio=(dados->>'inicio')::date,fim=(dados->>'fim')::date,valor_global=(dados->>'valor_global')::numeric,valor_mensal_referencia=(dados->>'valor_mensal_referencia')::numeric,periodicidade=trim(dados->>'periodicidade'),prazo_prestacao_dias=(dados->>'prazo_prestacao_dias')::integer,dia_limite_apresentacao=(dados->>'dia_limite_apresentacao')::integer,criticidade=dados->>'criticidade',situacao=dados->>'situacao'
  where id=p_id and id_organizacao=p_id_organizacao returning * into contrato;
  insert into public.versoes_contrato(id_organizacao,id_contrato,numero_versao,snapshot,hash,motivo,criado_por) values(p_id_organizacao,p_id,prox,to_jsonb(contrato),encode(extensions.digest(to_jsonb(contrato)::text,'sha256'),'hex'),trim(p_motivo),auth.uid());
 end if;
 resposta:=privado.crud_cadastro_consultar_v1(p_id_organizacao,p_entidade,p_id); depois:=resposta->'registro';
 evento:=privado.registrar_evento_auditoria(p_id_organizacao,'CadastroOperacionalAtualizado',p_entidade,p_id,antes,depois,jsonb_build_object('acao',p_acao,'motivo',trim(p_motivo),'request_id',p_request_id));
 resposta:=resposta||jsonb_build_object('request_id',p_request_id,'evento_id',evento);
 insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,resposta) values(p_id_organizacao,v_comando,p_request_id::text,hash,'concluido',resposta);
 return resposta;
exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or check_violation or not_null_violation or numeric_value_out_of_range then
 raise exception using errcode='PT422',message='Valor inválido para os campos do cadastro.';
end $$;

create function public.obter_cadastro_operacional_v1(p_id_organizacao uuid,p_entidade text,p_id uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.crud_cadastro_consultar_v1($1,$2,$3)$$;
create function public.atualizar_organizacao_v1(p_id_organizacao uuid,p_versao_esperada bigint,p_alteracoes jsonb,p_motivo text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.crud_cadastro_mutar_v1($1,'organizacoes',$1,$2,'editar',$3,$4,$5)$$;
create function public.alterar_situacao_organizacao_v1(p_id_organizacao uuid,p_versao_esperada bigint,p_situacao text,p_motivo text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.crud_cadastro_mutar_v1($1,'organizacoes',$1,$2,'situacao',jsonb_build_object('situacao',$3),$4,$5)$$;
create function public.atualizar_contrato_v1(p_id_organizacao uuid,p_id_contrato uuid,p_versao_esperada bigint,p_alteracoes jsonb,p_motivo text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.crud_cadastro_mutar_v1($1,'contratos',$2,$3,'editar',$4,$5,$6)$$;
create function public.alterar_situacao_contrato_v1(p_id_organizacao uuid,p_id_contrato uuid,p_versao_esperada bigint,p_situacao text,p_motivo text,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select privado.crud_cadastro_mutar_v1($1,'contratos',$2,$3,'situacao',jsonb_build_object('situacao',$4),$5,$6)$$;

revoke all on function privado.crud_cadastro_transicoes_v1(text,text,boolean),privado.crud_cadastro_touch_v1(),privado.crud_cadastro_consultar_v1(uuid,text,uuid),privado.crud_cadastro_mutar_v1(uuid,text,uuid,bigint,text,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function privado.crud_cadastro_consultar_v1(uuid,text,uuid),privado.crud_cadastro_mutar_v1(uuid,text,uuid,bigint,text,jsonb,text,uuid) to authenticated;
revoke all on function public.obter_cadastro_operacional_v1(uuid,text,uuid),public.atualizar_organizacao_v1(uuid,bigint,jsonb,text,uuid),public.alterar_situacao_organizacao_v1(uuid,bigint,text,text,uuid),public.atualizar_contrato_v1(uuid,uuid,bigint,jsonb,text,uuid),public.alterar_situacao_contrato_v1(uuid,uuid,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function public.obter_cadastro_operacional_v1(uuid,text,uuid),public.atualizar_organizacao_v1(uuid,bigint,jsonb,text,uuid),public.alterar_situacao_organizacao_v1(uuid,bigint,text,text,uuid),public.atualizar_contrato_v1(uuid,uuid,bigint,jsonb,text,uuid),public.alterar_situacao_contrato_v1(uuid,uuid,bigint,text,text,uuid) to authenticated;
commit;
