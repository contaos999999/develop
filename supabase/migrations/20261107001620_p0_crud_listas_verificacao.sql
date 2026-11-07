-- P0 V1-CHK: aggregate concurrency, immutable published content and scoped commands.
begin;
create function privado.crud_lista_autorizar_v1(p_org uuid,p_contrato uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare escrita boolean; editor boolean;
begin
 perform privado.exigir_permissao_rbac(p_org,'listas','consultar',p_contrato);
 select o.situacao='ativa' and c.situacao in ('rascunho','ativo') into escrita
 from public.contratos c join public.organizacoes o on o.id=c.id_organizacao
 where c.id=p_contrato and c.id_organizacao=p_org;
 if not found then raise exception using errcode='42501',message='Contexto de lista indisponível.'; end if;
 editor:=privado.usuario_possui_perfil(p_org,array['administrador','gestor_contrato','prestacao_contas','juridico_conformidade']);
 return jsonb_build_object(
  'criar',escrita and editor and privado.rbac_permite(p_org,'listas','criar',p_contrato),
  'editar',escrita and editor and privado.rbac_permite(p_org,'listas','editar',p_contrato),
  'publicar',escrita and privado.usuario_possui_perfil(p_org,array['administrador','direcao_aprovador']) and privado.rbac_permite(p_org,'listas','editar',p_contrato),
  'situacao',escrita and privado.usuario_possui_perfil(p_org,array['administrador']) and privado.rbac_permite(p_org,'listas','editar',p_contrato));
end $$;

create function privado.crud_lista_validar_regra_v1(p_regra jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare d jsonb; c jsonb; tipo text;
begin
 if jsonb_typeof(p_regra) is distinct from 'object' or octet_length(p_regra::text)>65536 then
  raise exception using errcode='PT422',message='A configuração de validação deve ser um objeto de até 64 KiB.';
 end if;
 if p_regra ? 'documento' then
  d:=p_regra->'documento';
  if jsonb_typeof(d) is distinct from 'object' then raise exception using errcode='PT422',message='Configuração de documento inválida.'; end if;
  if d ? 'obrigatorio' and jsonb_typeof(d->'obrigatorio') is distinct from 'boolean' then raise exception using errcode='PT422',message='Obrigatoriedade documental inválida.'; end if;
  if d ? 'tipos' then
   if jsonb_typeof(d->'tipos') is distinct from 'array' then raise exception using errcode='PT422',message='Tipos documentais inválidos.'; end if;
   if exists(select 1 from jsonb_array_elements(d->'tipos') x where jsonb_typeof(x)<>'string' or nullif(trim(x#>>'{}'),'') is null) then raise exception using errcode='PT422',message='Informe tipos documentais não vazios.'; end if;
  end if;
 end if;
 if p_regra ? 'condicao' then
  c:=p_regra->'condicao';
  if jsonb_typeof(c) is distinct from 'object' then raise exception using errcode='PT422',message='Condição inválida.'; end if;
  if c='{}'::jsonb then return; end if;
  tipo:=c->>'tipo';
  if tipo is null or tipo not in ('sempre','tipo_contrato_em','valor_global_minimo','valor_global_maximo','existe_documento_tipo','existe_transacao_tipo','existe_rescisao','existe_imobilizado','existe_aplicacao_financeira') then
   raise exception using errcode='PT422',message='Tipo de condição não reconhecido pelo mecanismo vigente.';
  end if;
  if tipo='tipo_contrato_em' then
   if jsonb_typeof(c->'valores') is distinct from 'array' then raise exception using errcode='PT422',message='Informe a lista de tipos de contrato.'; end if;
   if jsonb_array_length(c->'valores')=0 or exists(select 1 from jsonb_array_elements(c->'valores') x where jsonb_typeof(x)<>'string' or nullif(trim(x#>>'{}'),'') is null) then raise exception using errcode='PT422',message='Tipos de contrato inválidos.'; end if;
  elsif tipo in ('valor_global_minimo','valor_global_maximo') and jsonb_typeof(c->'valor') is distinct from 'number' then
   raise exception using errcode='PT422',message='Informe um valor numérico para a condição.';
  elsif tipo in ('existe_documento_tipo','existe_transacao_tipo') and (jsonb_typeof(c->'valor') is distinct from 'string' or nullif(trim(c->>'valor'),'') is null) then
   raise exception using errcode='PT422',message='Informe o tipo procurado pela condição.';
  end if;
 end if;
end $$;

create function privado.crud_lista_integridade_v1() returns trigger language plpgsql set search_path='' as $$
begin
 if current_user='authenticated' then raise exception using errcode='42501',message='Use a operação oficial de gestão de listas.'; end if;
 if tg_op='DELETE' then return old; end if;
 if tg_table_name='listas_verificacao' and tg_op='UPDATE' then new.atualizado_em:=now();
 elsif tg_table_name='versoes_lista' then
  if not exists(select 1 from public.listas_verificacao l where l.id=new.id_lista and l.id_organizacao=new.id_organizacao and l.id_contrato=new.id_contrato) then raise exception using errcode='23503',message='Versão fora do contexto da lista.'; end if;
 elsif tg_table_name='itens_lista' then
  if not exists(select 1 from public.versoes_lista v where v.id=new.id_versao_lista and v.id_organizacao=new.id_organizacao and v.id_contrato=new.id_contrato) then raise exception using errcode='23503',message='Item fora do contexto da versão.'; end if;
 end if;
 return new;
end $$;
drop trigger listas_verificacao_touch on public.listas_verificacao;
create trigger listas_verificacao_touch before update on public.listas_verificacao for each row execute function privado.crud_lista_integridade_v1();
create trigger trg_crud_lista_dml before insert or delete on public.listas_verificacao for each row execute function privado.crud_lista_integridade_v1();
create trigger trg_crud_lista_dml before insert or update or delete on public.versoes_lista for each row execute function privado.crud_lista_integridade_v1();
create trigger trg_crud_lista_dml before insert or update or delete on public.itens_lista for each row execute function privado.crud_lista_integridade_v1();

create function privado.crud_lista_consultar_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid,p_id_versao uuid,p_pagina_versoes integer,p_pagina_itens integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare caps jsonb; l public.listas_verificacao%rowtype; v public.versoes_lista%rowtype; versoes jsonb:='[]'; itens jsonb:='[]'; nv bigint:=0; ni bigint:=0; rascunho boolean:=false; usada boolean:=false; tem_rascunho boolean:=false; fim_minimo date;
begin
 caps:=privado.crud_lista_autorizar_v1(p_id_organizacao,p_id_contrato);
 if p_pagina_versoes is null or p_pagina_itens is null or p_pagina_versoes not between 0 and 100000 or p_pagina_itens not between 0 and 100000 then raise exception using errcode='PT422',message='Página inválida.'; end if;
 if p_id_lista is not null then
  select * into l from public.listas_verificacao where id=p_id_lista and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
  if not found then raise exception using errcode='42501',message='Lista indisponível neste contexto.'; end if;
  select count(*),coalesce(bool_or(situacao='rascunho'),false) into nv,tem_rascunho from public.versoes_lista where id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.numero_versao desc,x.id desc),'[]'::jsonb) into versoes from
   (select id,id_organizacao,id_contrato,id_lista,numero_versao,vigencia_inicio,vigencia_fim,situacao,aprovado_por,aprovado_em,criado_em from public.versoes_lista where id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato order by numero_versao desc,id desc limit 25 offset p_pagina_versoes*25) x;
  if p_id_versao is not null then
   select * into v from public.versoes_lista where id=p_id_versao and id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
   if not found then raise exception using errcode='42501',message='Versão indisponível nesta lista.'; end if;
  else
   select * into v from public.versoes_lista where id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato order by numero_versao desc,id desc limit 1;
  end if;
  if v.id is not null then
   rascunho:=v.situacao='rascunho';
   select count(*) into ni from public.itens_lista where id_versao_lista=v.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
   select exists(select 1 from public.requisitos_competencia r join public.itens_lista i on r.origem_tipo='item_lista' and r.origem_id=i.id where i.id_versao_lista=v.id) into usada;
   select greatest(v.vigencia_inicio,max(c.periodo_fim)) into fim_minimo from public.requisitos_competencia r join public.competencias c on c.id=r.id_competencia join public.itens_lista i on r.origem_tipo='item_lista' and r.origem_id=i.id where i.id_versao_lista=v.id;
   select coalesce(jsonb_agg(to_jsonb(x) order by x.ordem,x.id),'[]'::jsonb) into itens from
    (select i.id,i.id_organizacao,i.id_contrato,i.id_versao_lista,i.codigo,i.descricao,i.categoria,i.obrigatorio,i.aplicavel,i.impeditivo,i.criticidade,i.id_fonte_versao,i.regra_validacao,i.ordem,i.criado_em,
      rascunho and (caps->>'editar')::boolean and not exists(select 1 from public.requisitos_competencia r where r.origem_tipo='item_lista' and r.origem_id=i.id) as pode_remover
     from public.itens_lista i where i.id_versao_lista=v.id and i.id_organizacao=p_id_organizacao and i.id_contrato=p_id_contrato order by i.ordem,i.id limit 25 offset p_pagina_itens*25) x;
  end if;
 elsif p_id_versao is not null then raise exception using errcode='PT422',message='Selecione a lista da versão.';
 end if;
 return jsonb_build_object('schema_versao','crud-lista-v1','id_organizacao',p_id_organizacao,'id_contrato',p_id_contrato,'lista',case when l.id is null then null else to_jsonb(l) end,'versao',case when v.id is null then null else to_jsonb(v) end,
  'versoes',versoes,'total_versoes',nv,'pagina_versoes',p_pagina_versoes,'itens',itens,'total_itens',ni,'pagina_itens',p_pagina_itens,'vigencia_fim_minima',fim_minimo,
  'acoes',jsonb_build_object('criar_lista',(caps->>'criar')::boolean,'editar_lista',l.id is not null and (caps->>'editar')::boolean,'criar_versao',l.id is not null and not tem_rascunho and (caps->>'criar')::boolean,
   'editar_vigencia_rascunho',rascunho and (caps->>'editar')::boolean,'criar_item',rascunho and (caps->>'criar')::boolean,'editar_item',rascunho and (caps->>'editar')::boolean,'remover_item',rascunho and (caps->>'editar')::boolean,
   'publicar_versao',rascunho and (caps->>'publicar')::boolean,'encerrar_vigencia',coalesce(v.situacao='publicada' and v.vigencia_fim is null and (caps->>'publicar')::boolean,false),'alterar_situacao',l.id is not null and (caps->>'situacao')::boolean,'descartar_rascunho',rascunho and not usada and (caps->>'editar')::boolean),
  'exclusao_lista_permitida',false,'motivo_retencao','Cabeçalhos, versões e snapshots são retidos. Somente itens de rascunho sem referências podem ser removidos.');
end $$;

create function privado.crud_lista_mutar_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid,p_versao_esperada bigint,p_acao text,p_payload jsonb,p_motivo text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 caps jsonb; permissao text; permitidos text[]; v_comando text; v_hash text; anterior public.comandos_idempotentes%rowtype;
 l public.listas_verificacao%rowtype; antes_l public.listas_verificacao%rowtype; v public.versoes_lista%rowtype; origem public.versoes_lista%rowtype; i public.itens_lista%rowtype;
 versao_id uuid; item_id uuid; dados jsonb; antes jsonb; depois jsonb; evento uuid; resposta jsonb; inicio date; fim date; fim_usado date; n integer; quantidade integer:=0;
begin
 if p_acao is null or p_acao not in ('criar_lista','editar_lista','criar_versao','editar_vigencia_rascunho','salvar_item','remover_item','publicar_versao','encerrar_vigencia','alterar_situacao','descartar_rascunho') then raise exception using errcode='PT422',message='Operação de lista inválida.'; end if;
 if p_request_id is null or length(trim(coalesce(p_motivo,''))) not between 3 and 2000 or jsonb_typeof(p_payload) is distinct from 'object' then raise exception using errcode='PT422',message='Informe identificador, campos e motivo de 3 a 2000 caracteres.'; end if;
 if p_acao='criar_lista' then
  if p_id_lista is not null or p_versao_esperada is not null then raise exception using errcode='PT422',message='Criação não recebe lista ou versão anterior.'; end if;
 elsif p_id_lista is null or p_versao_esperada is null or p_versao_esperada<1 then raise exception using errcode='PT422',message='Informe a lista e sua versão atual.';
 end if;
 permitidos:=case p_acao
  when 'criar_lista' then array['nome','descricao','vigencia_inicio','vigencia_fim']
  when 'editar_lista' then array['nome','descricao']
  when 'criar_versao' then array['id_versao_origem','vigencia_inicio','vigencia_fim']
  when 'editar_vigencia_rascunho' then array['id_versao','vigencia_inicio','vigencia_fim']
  when 'salvar_item' then array['id_versao','id_item','codigo','descricao','categoria','obrigatorio','aplicavel','impeditivo','criticidade','id_fonte_versao','regra_validacao','ordem']
  when 'remover_item' then array['id_versao','id_item']
  when 'publicar_versao' then array['id_versao']
  when 'encerrar_vigencia' then array['id_versao','vigencia_fim']
  when 'alterar_situacao' then array['situacao']
  when 'descartar_rascunho' then array['id_versao'] end;
 if exists(select 1 from jsonb_object_keys(p_payload) k where not(k=any(permitidos))) then raise exception using errcode='PT422',message='Campo não permitido para esta operação.'; end if;
 if exists(select 1 from jsonb_each(p_payload) x where x.key in ('id_versao','id_versao_origem','id_item','id_fonte_versao','vigencia_inicio','vigencia_fim') and jsonb_typeof(x.value) not in ('string','null')) then raise exception using errcode='PT422',message='Datas e referências devem ser textos válidos ou nulos.'; end if;
 permissao:=case when p_acao in ('criar_lista','criar_versao') or (p_acao='salvar_item' and p_payload->>'id_item' is null) then 'criar' when p_acao in ('publicar_versao','encerrar_vigencia') then 'publicar' when p_acao='alterar_situacao' then 'situacao' else 'editar' end;
 caps:=privado.crud_lista_autorizar_v1(p_id_organizacao,p_id_contrato);
 if not coalesce((caps->>permissao)::boolean,false) then raise exception using errcode='42501',message='Sem permissão para esta operação de lista.'; end if;
 perform 1 from public.organizacoes where id=p_id_organizacao for share;
 perform 1 from public.contratos where id=p_id_contrato and id_organizacao=p_id_organizacao for update;
 v_comando:='crud-lista-v1:'||p_acao;
 v_hash:=encode(extensions.digest(jsonb_build_array(auth.uid(),p_id_organizacao,p_id_contrato,p_id_lista,p_versao_esperada,p_acao,p_payload,p_motivo)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_id_organizacao::text||v_comando||p_request_id::text,0));
 caps:=privado.crud_lista_autorizar_v1(p_id_organizacao,p_id_contrato);
 if not coalesce((caps->>permissao)::boolean,false) then raise exception using errcode='42501',message='A permissão foi revogada durante a espera.'; end if;
 select * into anterior from public.comandos_idempotentes ci where ci.id_organizacao=p_id_organizacao and ci.comando=v_comando and ci.chave=p_request_id::text;
 if found then
  if anterior.hash_payload is distinct from v_hash or anterior.status<>'concluido' then raise exception using errcode='PT409',message='Identificador já usado para outro comando.'; end if;
  return anterior.resposta;
 end if;
 if p_acao<>'criar_lista' then
  select * into l from public.listas_verificacao where id=p_id_lista and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato for update;
  if not found then raise exception using errcode='42501',message='Lista indisponível neste contexto.'; end if;
  if l.versao_registro<>p_versao_esperada then raise exception using errcode='PT409',message='Lista alterada por outra pessoa. Recarregue e revise o rascunho.'; end if;
 end if;
 caps:=privado.crud_lista_autorizar_v1(p_id_organizacao,p_id_contrato);
 if not coalesce((caps->>permissao)::boolean,false) then raise exception using errcode='42501',message='A permissão foi revogada durante a espera.'; end if;
 antes_l:=l; antes:=case when l.id is null then null else to_jsonb(l) end;
 if p_acao in ('editar_vigencia_rascunho','salvar_item','remover_item','publicar_versao','encerrar_vigencia','descartar_rascunho') then
  versao_id:=(p_payload->>'id_versao')::uuid;
  select * into v from public.versoes_lista where id=versao_id and id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato for update;
  if not found then raise exception using errcode='42501',message='Versão indisponível nesta lista.'; end if;
  antes:=jsonb_build_object('lista',to_jsonb(l),'versao',to_jsonb(v));
  if p_acao in ('editar_vigencia_rascunho','salvar_item','remover_item','publicar_versao','descartar_rascunho') and v.situacao<>'rascunho' then raise exception using errcode='PT422',message='Somente versões em rascunho admitem esta alteração.'; end if;
  if exists(select 1 from public.itens_lista x where x.id_versao_lista=v.id and (x.id_organizacao<>p_id_organizacao or x.id_contrato<>p_id_contrato)) then raise exception using errcode='PT409',message='A versão contém itens com contexto inconsistente.'; end if;
 end if;

 if p_acao='criar_lista' then
  if jsonb_typeof(p_payload->'nome') is distinct from 'string' or nullif(trim(p_payload->>'nome'),'') is null or (p_payload ? 'descricao' and jsonb_typeof(p_payload->'descricao') not in ('string','null')) then raise exception using errcode='PT422',message='Informe nome e descrição válidos.'; end if;
  inicio:=(p_payload->>'vigencia_inicio')::date; fim:=(p_payload->>'vigencia_fim')::date;
  if inicio is not null and fim<inicio then raise exception using errcode='PT422',message='Fim anterior ao início da vigência.'; end if;
  insert into public.listas_verificacao(id_organizacao,id_contrato,nome,descricao) values(p_id_organizacao,p_id_contrato,trim(p_payload->>'nome'),nullif(trim(p_payload->>'descricao'),'')) returning * into l;
  insert into public.versoes_lista(id_organizacao,id_contrato,id_lista,numero_versao,vigencia_inicio,vigencia_fim) values(p_id_organizacao,p_id_contrato,l.id,1,inicio,fim) returning * into v;
  versao_id:=v.id;
 elsif p_acao='editar_lista' then
  if p_payload='{}'::jsonb or (p_payload ? 'nome' and (jsonb_typeof(p_payload->'nome') is distinct from 'string' or nullif(trim(p_payload->>'nome'),'') is null)) or (p_payload ? 'descricao' and jsonb_typeof(p_payload->'descricao') not in ('string','null')) then raise exception using errcode='PT422',message='Informe nome ou descrição válidos.'; end if;
  if p_payload ? 'nome' then l.nome:=trim(p_payload->>'nome'); end if;
  if p_payload ? 'descricao' then l.descricao:=nullif(trim(p_payload->>'descricao'),''); end if;
 elsif p_acao='criar_versao' then
  if exists(select 1 from public.versoes_lista where id_lista=l.id and situacao='rascunho') then raise exception using errcode='PT409',message='Conclua ou descarte o rascunho aberto antes de criar outra versão.'; end if;
  if p_payload->>'id_versao_origem' is not null then
   select * into origem from public.versoes_lista where id=(p_payload->>'id_versao_origem')::uuid and id_lista=l.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato;
   if not found then raise exception using errcode='42501',message='Versão de origem indisponível nesta lista.'; end if;
   if exists(select 1 from public.itens_lista x where x.id_versao_lista=origem.id and (x.id_organizacao<>p_id_organizacao or x.id_contrato<>p_id_contrato)) then raise exception using errcode='PT409',message='A origem contém itens com contexto inconsistente.'; end if;
  end if;
  inicio:=(p_payload->>'vigencia_inicio')::date; fim:=(p_payload->>'vigencia_fim')::date;
  if inicio is not null and fim<inicio then raise exception using errcode='PT422',message='Fim anterior ao início da vigência.'; end if;
  select coalesce(max(numero_versao),0)+1 into n from public.versoes_lista where id_lista=l.id;
  insert into public.versoes_lista(id_organizacao,id_contrato,id_lista,numero_versao,vigencia_inicio,vigencia_fim) values(p_id_organizacao,p_id_contrato,l.id,n,inicio,fim) returning * into v;
  versao_id:=v.id;
  if origem.id is not null then
   insert into public.itens_lista(id_organizacao,id_contrato,id_versao_lista,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,id_fonte_versao,regra_validacao,ordem)
   select p_id_organizacao,p_id_contrato,v.id,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,id_fonte_versao,regra_validacao,ordem from public.itens_lista where id_versao_lista=origem.id;
   get diagnostics quantidade=row_count;
  end if;
 elsif p_acao='editar_vigencia_rascunho' then
  if not (p_payload ? 'vigencia_inicio' or p_payload ? 'vigencia_fim') then raise exception using errcode='PT422',message='Informe uma alteração de vigência.'; end if;
  inicio:=case when p_payload ? 'vigencia_inicio' then (p_payload->>'vigencia_inicio')::date else v.vigencia_inicio end;
  fim:=case when p_payload ? 'vigencia_fim' then (p_payload->>'vigencia_fim')::date else v.vigencia_fim end;
  if inicio is not null and fim<inicio then raise exception using errcode='PT422',message='Fim anterior ao início da vigência.'; end if;
  update public.versoes_lista set vigencia_inicio=inicio,vigencia_fim=fim where id=v.id returning * into v;
 elsif p_acao='salvar_item' then
  item_id:=(p_payload->>'id_item')::uuid;
  if item_id is not null then
   select * into i from public.itens_lista where id=item_id and id_versao_lista=v.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato for update;
   if not found then raise exception using errcode='42501',message='Item indisponível nesta versão.'; end if;
   if exists(select 1 from public.requisitos_competencia r where r.origem_tipo='item_lista' and r.origem_id=i.id) then raise exception using errcode='PT422',message='Este item já integra um snapshot e não pode ser alterado.'; end if;
   dados:=to_jsonb(i)||p_payload; antes:=antes||jsonb_build_object('item',to_jsonb(i));
  else dados:=jsonb_build_object('categoria',null,'obrigatorio',true,'aplicavel',true,'impeditivo',false,'criticidade','media','id_fonte_versao',null,'regra_validacao','{}'::jsonb,'ordem',0)||p_payload; end if;
  if jsonb_typeof(dados->'codigo') is distinct from 'string' or nullif(trim(dados->>'codigo'),'') is null or jsonb_typeof(dados->'descricao') is distinct from 'string' or nullif(trim(dados->>'descricao'),'') is null
   or jsonb_typeof(dados->'obrigatorio') is distinct from 'boolean' or jsonb_typeof(dados->'aplicavel') is distinct from 'boolean' or jsonb_typeof(dados->'impeditivo') is distinct from 'boolean'
   or jsonb_typeof(dados->'ordem') is distinct from 'number' or jsonb_typeof(dados->'criticidade') is distinct from 'string' or dados->>'criticidade' not in ('baixa','media','alta','critica')
   or (dados ? 'categoria' and jsonb_typeof(dados->'categoria') not in ('string','null')) then raise exception using errcode='PT422',message='Campos do item inválidos.'; end if;
  perform privado.crud_lista_validar_regra_v1(dados->'regra_validacao');
  if dados->>'id_fonte_versao' is not null and not exists(select 1 from public.versoes_fontes_normativas fv join public.fontes_normativas f on f.id=fv.id_fonte and f.id_organizacao=fv.id_organizacao and f.id_contrato is not distinct from fv.id_contrato where fv.id=(dados->>'id_fonte_versao')::uuid and fv.id_organizacao=p_id_organizacao and (fv.id_contrato=p_id_contrato or fv.id_contrato is null)) then raise exception using errcode='42501',message='Fonte indisponível neste contexto.'; end if;
  if item_id is null then
   insert into public.itens_lista(id_organizacao,id_contrato,id_versao_lista,codigo,descricao,categoria,obrigatorio,aplicavel,impeditivo,criticidade,id_fonte_versao,regra_validacao,ordem)
   values(p_id_organizacao,p_id_contrato,v.id,trim(dados->>'codigo'),trim(dados->>'descricao'),nullif(trim(dados->>'categoria'),''),(dados->>'obrigatorio')::boolean,(dados->>'aplicavel')::boolean,(dados->>'impeditivo')::boolean,dados->>'criticidade',(dados->>'id_fonte_versao')::uuid,dados->'regra_validacao',(dados->>'ordem')::integer) returning * into i;
   item_id:=i.id;
  else
   update public.itens_lista set codigo=trim(dados->>'codigo'),descricao=trim(dados->>'descricao'),categoria=nullif(trim(dados->>'categoria'),''),obrigatorio=(dados->>'obrigatorio')::boolean,aplicavel=(dados->>'aplicavel')::boolean,impeditivo=(dados->>'impeditivo')::boolean,criticidade=dados->>'criticidade',id_fonte_versao=(dados->>'id_fonte_versao')::uuid,regra_validacao=dados->'regra_validacao',ordem=(dados->>'ordem')::integer where id=i.id returning * into i;
  end if;
 elsif p_acao='remover_item' then
  item_id:=(p_payload->>'id_item')::uuid;
  select * into i from public.itens_lista where id=item_id and id_versao_lista=v.id and id_organizacao=p_id_organizacao and id_contrato=p_id_contrato for update;
  if not found then raise exception using errcode='42501',message='Item indisponível nesta versão.'; end if;
  if exists(select 1 from public.requisitos_competencia r where r.origem_tipo='item_lista' and r.origem_id=i.id) then raise exception using errcode='PT422',message='O item está referenciado por um snapshot e deve ser preservado.'; end if;
  antes:=antes||jsonb_build_object('item',to_jsonb(i)); delete from public.itens_lista where id=i.id;
 elsif p_acao='publicar_versao' then
  if v.vigencia_inicio is null or v.vigencia_fim<v.vigencia_inicio then raise exception using errcode='PT422',message='Informe a vigência da versão antes de publicar.'; end if;
  if not exists(select 1 from public.itens_lista where id_versao_lista=v.id) then raise exception using errcode='PT422',message='Inclua ao menos um item na versão.'; end if;
  if exists(select 1 from public.versoes_lista x where x.id_lista=l.id and x.id<>v.id and x.situacao='publicada' and daterange(x.vigencia_inicio,x.vigencia_fim,'[]') && daterange(v.vigencia_inicio,v.vigencia_fim,'[]')) then raise exception using errcode='PT422',message='A vigência se sobrepõe a outra versão publicada. Encerre a vigência anterior antes de publicar.'; end if;
  for i in select * from public.itens_lista where id_versao_lista=v.id order by ordem,id loop
   perform privado.crud_lista_validar_regra_v1(i.regra_validacao);
   -- Snapshot conditions can turn an initially inactive item into an applicable one.
   if (i.aplicavel or coalesce(i.regra_validacao->'condicao','{}'::jsonb)<>'{}'::jsonb) and (i.obrigatorio or i.impeditivo or i.regra_validacao<>'{}'::jsonb) then
    if i.id_fonte_versao is null or not exists(
     select 1 from public.versoes_fontes_normativas fv join public.fontes_normativas f on f.id=fv.id_fonte and f.id_organizacao=fv.id_organizacao and f.id_contrato is not distinct from fv.id_contrato
     left join public.aplicabilidades_fonte a on a.id_fonte_versao=fv.id and a.id_contrato=p_id_contrato and a.id_organizacao=p_id_organizacao
     where fv.id=i.id_fonte_versao and fv.id_organizacao=p_id_organizacao and f.situacao='ativa' and fv.aprovado_em is not null and fv.inicio_vigencia<=v.vigencia_inicio
      and (fv.fim_vigencia is null or (v.vigencia_fim is not null and v.vigencia_fim<=fv.fim_vigencia))
      and ((fv.id_contrato=p_id_contrato and (a.id is null or (a.aplicavel and a.aprovado_em is not null))) or (fv.id_contrato is null and a.aplicavel and a.aprovado_em is not null))
    ) then raise exception using errcode='PT422',message='Item material exige fonte aprovada, aplicável e vigente em todo o período da lista.'; end if;
   end if;
  end loop;
  update public.versoes_lista set situacao='publicada',aprovado_por=auth.uid(),aprovado_em=clock_timestamp() where id=v.id returning * into v;
  l.situacao:='ativa'; l.versao_atual:=greatest(l.versao_atual,v.numero_versao);
 elsif p_acao='encerrar_vigencia' then
  fim:=(p_payload->>'vigencia_fim')::date;
  if v.situacao<>'publicada' or v.vigencia_fim is not null or fim is null or (v.vigencia_inicio is not null and fim<v.vigencia_inicio) then raise exception using errcode='PT422',message='Somente uma versão publicada com vigência aberta pode ser encerrada, uma única vez.'; end if;
  select max(c.periodo_fim) into fim_usado from public.requisitos_competencia r join public.competencias c on c.id=r.id_competencia join public.itens_lista x on r.origem_tipo='item_lista' and r.origem_id=x.id where x.id_versao_lista=v.id;
  if fim_usado is not null and fim<fim_usado then raise exception using errcode='PT422',message='A vigência não pode terminar antes dos períodos já preservados em snapshots.'; end if;
  update public.versoes_lista set vigencia_fim=fim where id=v.id returning * into v;
 elsif p_acao='alterar_situacao' then
  if p_payload->>'situacao' is null or p_payload->>'situacao' not in ('ativa','inativa') or p_payload->>'situacao'=l.situacao then raise exception using errcode='PT422',message='Mudança de situação inválida.'; end if;
  if p_payload->>'situacao'='ativa' and not exists(select 1 from public.versoes_lista where id_lista=l.id and situacao='publicada') then raise exception using errcode='PT422',message='Publique uma versão antes de ativar a lista.'; end if;
  l.situacao:=p_payload->>'situacao';
 elsif p_acao='descartar_rascunho' then
  if exists(select 1 from public.requisitos_competencia r join public.itens_lista x on r.origem_tipo='item_lista' and r.origem_id=x.id where x.id_versao_lista=v.id) then raise exception using errcode='PT422',message='O rascunho está referenciado por snapshots e deve ser preservado.'; end if;
  update public.versoes_lista set situacao='substituida' where id=v.id returning * into v;
 end if;
 if p_acao<>'criar_lista' then update public.listas_verificacao set nome=l.nome,descricao=l.descricao,situacao=l.situacao,versao_atual=l.versao_atual where id=l.id returning * into l; end if;
 depois:=jsonb_build_object('lista',to_jsonb(l),'versao',case when v.id is null then null else to_jsonb(v) end,'item',case when i.id is null or p_acao='remover_item' then null else to_jsonb(i) end);
 if p_acao='publicar_versao' then
  select encode(extensions.digest(coalesce(jsonb_agg(to_jsonb(x) order by x.ordem,x.id),'[]'::jsonb)::text,'sha256'),'hex') into v_hash from public.itens_lista x where x.id_versao_lista=v.id;
  depois:=depois||jsonb_build_object('hash_conteudo',v_hash);
 end if;
 evento:=privado.registrar_evento_auditoria(p_id_organizacao,'ListaOperacionalAlterada','listas_verificacao',l.id,antes,depois,jsonb_build_object('acao',p_acao,'motivo',trim(p_motivo),'request_id',p_request_id,'id_versao',versao_id,'id_item',item_id,'itens_clonados',quantidade,'id_versao_origem',origem.id));
 resposta:=jsonb_build_object('schema_versao','crud-lista-v1','acao',p_acao,'id_organizacao',p_id_organizacao,'id_contrato',p_id_contrato,'lista',to_jsonb(l),'id_versao',versao_id,'id_item',item_id,'request_id',p_request_id,'evento_id',evento);
 -- The payload hash is recomputed separately from the optional published-content hash.
 insert into public.comandos_idempotentes(id_organizacao,comando,chave,hash_payload,status,resposta) values(p_id_organizacao,v_comando,p_request_id::text,encode(extensions.digest(jsonb_build_array(auth.uid(),p_id_organizacao,p_id_contrato,p_id_lista,p_versao_esperada,p_acao,p_payload,p_motivo)::text,'sha256'),'hex'),'concluido',resposta);
 return resposta;
exception
 when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or check_violation or not_null_violation or numeric_value_out_of_range or foreign_key_violation then raise exception using errcode='PT422',message='Valor ou referência inválida nos campos da lista.';
 when unique_violation then raise exception using errcode='PT409',message='Código ou versão já cadastrado. Recarregue e revise.';
 when serialization_failure or deadlock_detected then raise exception using errcode='PT409',message='A operação concorreu com outra alteração. Recarregue e revise.';
end $$;

create function public.obter_lista_operacional_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid default null,p_id_versao uuid default null,p_pagina_versoes integer default 0,p_pagina_itens integer default 0)
returns jsonb language sql security invoker set search_path='' as $$select privado.crud_lista_consultar_v1($1,$2,$3,$4,$5,$6)$$;
create function public.executar_comando_lista_v1(p_id_organizacao uuid,p_id_contrato uuid,p_id_lista uuid,p_versao_esperada bigint,p_acao text,p_payload jsonb,p_motivo text,p_request_id uuid)
returns jsonb language sql security invoker set search_path='' as $$select privado.crud_lista_mutar_v1($1,$2,$3,$4,$5,$6,$7,$8)$$;
revoke all on function privado.crud_lista_autorizar_v1(uuid,uuid),privado.crud_lista_validar_regra_v1(jsonb),privado.crud_lista_integridade_v1(),privado.crud_lista_consultar_v1(uuid,uuid,uuid,uuid,integer,integer),privado.crud_lista_mutar_v1(uuid,uuid,uuid,bigint,text,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function privado.crud_lista_consultar_v1(uuid,uuid,uuid,uuid,integer,integer),privado.crud_lista_mutar_v1(uuid,uuid,uuid,bigint,text,jsonb,text,uuid) to authenticated;
revoke all on function public.obter_lista_operacional_v1(uuid,uuid,uuid,uuid,integer,integer),public.executar_comando_lista_v1(uuid,uuid,uuid,bigint,text,jsonb,text,uuid) from public,anon,authenticated;
grant execute on function public.obter_lista_operacional_v1(uuid,uuid,uuid,uuid,integer,integer),public.executar_comando_lista_v1(uuid,uuid,uuid,bigint,text,jsonb,text,uuid) to authenticated;
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
  -- Serialize the complete checklist snapshot with canonical list publication/closure.
  perform 1 from public.organizacoes where id=v_org for share;
  perform 1 from public.contratos where id=p_id_contrato and id_organizacao=v_org for share;
  perform privado.exigir_permissao_rbac(v_org,'competencias','criar',p_id_contrato);
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
end;$function$;

commit;
