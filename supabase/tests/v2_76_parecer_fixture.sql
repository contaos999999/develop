create schema auth;
create schema privado;
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
create table public.competencias(id uuid primary key,id_organizacao uuid,id_contrato uuid,situacao text,validada_em timestamptz);
create table public.apresentacoes_contratante(id uuid primary key,id_organizacao uuid,id_contrato uuid,id_competencia uuid,numero_rodada integer);
create table public.arquivos(id uuid primary key,id_organizacao uuid,id_contrato uuid,status_seguranca text,mime text,sha256 text,bucket text);
create table public.ciclos_diligencia(id uuid primary key default gen_random_uuid(),id_organizacao uuid,id_contrato uuid,id_competencia uuid,
  numero_rodada integer,status text,prazo_resposta date,unique(id_competencia,numero_rodada));
create table public.pareceres_contratante(id uuid primary key default gen_random_uuid(),id_organizacao uuid,id_contrato uuid,id_competencia uuid,
  id_ciclo uuid references public.ciclos_diligencia,id_apresentacao uuid references public.apresentacoes_contratante,id_arquivo uuid references public.arquivos,
  resultado_geral text,parecer_final_favoravel boolean,numero_documento text,data_emissao date,registrado_por uuid,
  extracao_apontamentos_concluida_em timestamptz,extracao_apontamentos_sha256 text,recebido_em timestamptz default now());
create table public.execucoes_assincronas(id uuid primary key default gen_random_uuid(),id_organizacao uuid,id_contrato uuid,
  fila text,entidade_tipo text,entidade_id uuid,status text,tentativas integer,iniciado_em timestamptz,concluido_em timestamptz,
  criado_em timestamptz default now(),atualizado_em timestamptz default now(),correlation_id uuid default gen_random_uuid(),erro_detalhe text);
create table public.eventos_auditoria(id uuid primary key default gen_random_uuid(),id_organizacao uuid,
  evento text,entidade text,id_entidade uuid,depois jsonb, id_usuario uuid default auth.uid());
create function privado.registrar_evento_auditoria(uuid,text,text,uuid,jsonb,jsonb)
returns uuid language sql as $$
  insert into public.eventos_auditoria(id_organizacao,evento,entidade,id_entidade,depois)
  values($1,$2,$3,$4,$6) returning id
$$;
create function privado.enfileirar_fixture() returns trigger language plpgsql as $$
begin
  insert into public.execucoes_assincronas(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,status,tentativas,erro_detalhe)
  values(new.id_organizacao,new.id_contrato,'ai','extrair_diligencia',new.id,'enfileirado',0,'conteúdo privado sintético');
  return new;
end
$$;
create trigger parecer_contratante_extracao after insert on public.pareceres_contratante
for each row when (new.parecer_final_favoravel=false) execute function privado.enfileirar_fixture();

create function public.fixture_id(n integer) returns uuid language sql immutable as $$
  select ('76000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;
insert into public.competencias
select fixture_id(n),fixture_id(1),fixture_id(2),'aguardando_contratante',null
from generate_series(20,25) n;
insert into public.apresentacoes_contratante
select fixture_id(n+100),fixture_id(1),fixture_id(2),fixture_id(n),1
from generate_series(20,25) n;
insert into public.arquivos values
  (fixture_id(40),fixture_id(1),fixture_id(2),'aprovado','application/pdf',repeat('c',64),'contaos-documentos'),
  (fixture_id(41),fixture_id(1),fixture_id(2),'quarentena','application/pdf',repeat('d',64),'contaos-documentos'),
  (fixture_id(42),fixture_id(9),fixture_id(3),'aprovado','application/pdf',repeat('e',64),'contaos-documentos'),
  (fixture_id(43),fixture_id(1),fixture_id(2),'aprovado','application/pdf',repeat('f',64),'contaos-documentos'),
  (fixture_id(44),fixture_id(1),fixture_id(2),'aprovado','application/pdf',repeat('b',64),'contaos-documentos'),
  (fixture_id(45),fixture_id(1),fixture_id(2),'aprovado','application/pdf',repeat('1',64),'contaos-documentos');
