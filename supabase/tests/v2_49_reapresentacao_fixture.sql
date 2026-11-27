create schema auth;
create schema privado;
create schema extensions;
create extension pgcrypto with schema extensions;
create role anon;
create role authenticated;
create role service_role;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('fixture.actor',true),'')::uuid
$$;
create function privado.sessao_usuario_ativa() returns boolean language sql stable as $$
  select coalesce(current_setting('fixture.disabled',true),'') <> 'true'
$$;
create function privado.usuario_tem_acesso_contrato(uuid) returns boolean language sql stable as $$
  select auth.uid() is not null and coalesce(current_setting('fixture.contract_denied',true),'') <> 'true'
$$;
create function privado.usuario_possui_perfil(uuid,text[]) returns boolean language sql stable as $$
  select auth.uid() is not null and coalesce(current_setting('fixture.profile_denied',true),'') <> 'true'
$$;
create table public.competencias(id uuid primary key,id_organizacao uuid,id_contrato uuid,situacao text);
create table public.ciclos_diligencia(id uuid primary key,id_organizacao uuid,id_contrato uuid,id_competencia uuid,
  numero_rodada integer,status text);
create table public.aprovacoes(id_competencia uuid,tipo text,status text,hash_contexto text,criado_em timestamptz);
create table public.execucoes_analise(id_competencia uuid,status text,tipo text,hash_entrada text,
  concluida_em timestamptz,criado_em timestamptz);
create table public.arquivos(id uuid primary key,id_organizacao uuid,id_contrato uuid,status_seguranca text);
create table public.contestacoes(id_ciclo uuid,status_aprovacao text,hash text);
create table public.versoes_documento(id uuid primary key,hash text);
create table public.tarefas_diligencia(id_ciclo uuid,id_evidencia_versao_documento uuid,status text);
create table public.pacotes_reapresentacao(id uuid primary key default gen_random_uuid(),id_organizacao uuid,
  id_contrato uuid,id_competencia uuid,id_ciclo uuid,numero integer,hash text,snapshot jsonb,
  criado_por uuid,reapresentado_em timestamptz);
create table public.pacotes_competencia(id uuid primary key default gen_random_uuid(),id_organizacao uuid,
  id_contrato uuid,id_competencia uuid,numero integer,tipo text,status text,hash_pacote text,criado_por uuid,
  congelado_em timestamptz);
create table public.apresentacoes_contratante(id uuid primary key default gen_random_uuid(),id_organizacao uuid,
  id_contrato uuid,id_competencia uuid,id_pacote uuid,numero_rodada integer,tipo text,protocolo text,
  forma_apresentacao text,id_comprovante_arquivo uuid references public.arquivos,idempotency_key text,
  apresentado_por uuid,unique(id_organizacao,idempotency_key));
create table public.eventos_auditoria(id uuid primary key default gen_random_uuid(),id_organizacao uuid,
  evento text,entidade text,id_entidade uuid,depois jsonb);
create function privado.registrar_evento_auditoria(uuid,text,text,uuid,jsonb,jsonb)
returns uuid language sql as $$
  insert into public.eventos_auditoria(id_organizacao,evento,entidade,id_entidade,depois)
  values($1,$2,$3,$4,$6) returning id
$$;
create function privado.hash_contexto_competencia(uuid) returns text language sql stable as $$
  select coalesce(nullif(current_setting('fixture.hash',true),''),'contexto-fixture')
$$;
create function public.avaliar_portao_reapresentacao(uuid) returns jsonb language sql stable as $$
  select jsonb_build_object('liberado',coalesce(current_setting('fixture.open_item',true),'') <> 'true')
$$;
create function public.fixture_id(n integer) returns uuid language sql immutable as $$
  select ('49000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
create function public.fixture_rodada(n integer, org integer, contrato integer)
returns void language plpgsql as $$
begin
  insert into public.competencias values (fixture_id(n+100),fixture_id(org),fixture_id(contrato),'pode_reapresentar_contratante');
  insert into public.ciclos_diligencia values (fixture_id(n),fixture_id(org),fixture_id(contrato),fixture_id(n+100),1,'pronto_reapresentar');
  insert into public.aprovacoes values (fixture_id(n+100),'reapresentacao','aprovada','contexto-fixture',now());
  insert into public.execucoes_analise values (fixture_id(n+100),'concluida','completa','contexto-fixture',now(),now());
end
$$;
select fixture_rodada(n,1,case when n=22 then 3 else 2 end) from generate_series(20,28) n;
insert into public.arquivos values
  (fixture_id(40),fixture_id(1),fixture_id(2),'aprovado'),
  (fixture_id(41),fixture_id(1),fixture_id(3),'aprovado'),
  (fixture_id(42),fixture_id(9),fixture_id(2),'aprovado'),
  (fixture_id(43),fixture_id(1),fixture_id(2),'quarentena');
