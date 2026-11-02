-- V1-07. Fixtures sintéticas; nenhuma persistência após ROLLBACK.
begin;
create temp table v107_resultados(teste text primary key, passou boolean not null, detalhe jsonb) on commit drop;
create temp table v107_valores(k text primary key,j jsonb) on commit drop;
grant all on v107_resultados,v107_valores to authenticated;
create function pg_temp.v107_tentar(q text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare j jsonb;
begin execute q into j; return jsonb_build_object('ok',true,'valor',j);
exception when others then return jsonb_build_object('ok',false,'codigo',sqlstate,'mensagem',sqlerrm); end $$;
grant execute on function pg_temp.v107_tentar(text) to authenticated;
insert into auth.users(id,aud,role,email,created_at,updated_at)
select ('c7070707-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated','v107-'||n||'@contaos.invalid',now(),now() from generate_series(1,5)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('c7070707-0000-4000-9000-'||lpad(n::text,12,'0'))::uuid,('c7070707-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour' from generate_series(1,5)n;
insert into public.organizacoes(id,razao_social) values ('c7070707-aaaa-4000-8000-000000000001','V107 A'),('c7070707-bbbb-4000-8000-000000000001','V107 B');
insert into public.contratantes(id,id_organizacao,razao_social)
select ('c7070707-1000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=3 then 'c7070707-bbbb-4000-8000-000000000001'::uuid else 'c7070707-aaaa-4000-8000-000000000001'::uuid end,'V107 contratante '||n from generate_series(1,3)n;
insert into public.contratos(id,id_organizacao,id_contratante,numero,objeto,inicio)
select ('c7070707-2000-4000-8000-'||lpad(n::text,12,'0'))::uuid,id_organizacao,id,'V107-'||n,'Teste normativo','2026-01-01' from public.contratantes cross join lateral(select right(id::text,1)::int n)x where id::text like 'c7070707-1000%';
insert into public.vinculos_usuarios(id,id_organizacao,id_usuario,perfil,escopo_todos_contratos,ativo)
select ('c7070707-3000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c7070707-aaaa-4000-8000-000000000001',('c7070707-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case n when 1 then 'administrador' when 2 then 'leitor' when 3 then 'gestor_contrato' else 'direcao_aprovador' end,n<>3,true from generate_series(1,4)n;
insert into public.vinculos_usuario_contratos(id_organizacao,id_vinculo_usuario,id_contrato,ativo) values('c7070707-aaaa-4000-8000-000000000001','c7070707-3000-4000-8000-000000000003','c7070707-2000-4000-8000-000000000001',true);
insert into privado.administradores_master(id_usuario,ativo,motivo) values('c7070707-0000-4000-8000-000000000005',true,'Fixture V107');
set local role authenticated;
select set_config('request.jwt.claim.sub','c7070707-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"c7070707-0000-4000-8000-000000000001","role":"authenticated","session_id":"c7070707-0000-4000-9000-000000000001"}',true);
insert into v107_valores values('criar',pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',null,'lei','Lei teste','Origem formal',null,'rascunho',null,'criar-1')$q$));
insert into v107_resultados select '01 criar fonte rascunho',coalesce((j->>'ok')::boolean and j->'valor'->'fonte'->>'situacao'='rascunho' and j->'valor'->'fonte'->>'versao_registro'='1',false),j from v107_valores where k='criar';
insert into v107_valores values('replay',pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',null,'lei','Lei teste','Origem formal',null,'rascunho',null,'criar-1')$q$));
insert into v107_resultados select '02 replay resposta idêntica',coalesce(a.j=b.j and (a.j->>'ok')::boolean,false),a.j from v107_valores a join v107_valores b on b.k='replay' where a.k='criar';
insert into v107_resultados select '03 chave payload divergente',j->>'codigo'='PT409',j from (select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',null,'lei','Outro título',null,null,'rascunho',null,'criar-1')$q$)j)x;
insert into v107_valores values('editar',pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'lei','Lei atualizada','Origem formal',null,'rascunho',1,'editar-1')$q$));
insert into v107_resultados select '04 edição incrementa exatamente uma vez',coalesce(j->'valor'->'fonte'->>'versao_registro'='2',false),j from v107_valores where k='editar';
insert into v107_resultados select '05 obsoleto PT409',j->>'codigo'='PT409',j from (select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'lei','Não sobrescrever',null,null,'rascunho',1,'stale')$q$)j)x;
insert into v107_valores values('versao',pg_temp.v107_tentar($q$select public.registrar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'2026-01-01',null,null,'Texto oficial','{"pagina":1,"trecho":"Texto oficial"}','versao-1')$q$));
insert into v107_resultados select '06 versão sem upload válida e não aprovada',coalesce((j->>'ok')::boolean and j->'valor'->'versao'->>'versao'='1' and j->'valor'->'versao'->>'aprovado_em' is null and length(j->'valor'->'versao'->>'hash')=64,false),j from v107_valores where k='versao';
insert into v107_resultados select '07 vigência invertida negada',j->>'codigo'='PT400',j from (select pg_temp.v107_tentar($q$select public.registrar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'2026-02-01','2026-01-01',null,'texto','{}','vigencia')$q$)j)x;
insert into v107_resultados select '08 aprovação hash errado negada',j->>'codigo'='PT409',j from (select pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),'incorreto','Revisão humana','aprovar-errado')$q$)j)x;
insert into v107_valores values('aprovar',pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),(select j->'valor'->'versao'->>'hash' from v107_valores where k='versao'),'Revisão humana','aprovar-1')$q$));
insert into v107_resultados select '09 aprovação ator/data backend',coalesce((j->>'ok')::boolean and j->'valor'->'versao'->>'aprovado_por'='c7070707-0000-4000-8000-000000000001' and j->'valor'->'versao'->>'aprovado_em' is not null,false),j from v107_valores where k='aprovar';
insert into v107_valores values('aplicar',pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),true,'Aplicável conforme objeto',null,'aplicar-1')$q$));
insert into v107_resultados select '10 aplicabilidade aprovada',coalesce((j->>'ok')::boolean and (j->'valor'->'aplicabilidade'->>'aplicavel')::boolean and j->'valor'->'aplicabilidade'->>'aprovado_em' is not null,false),j from v107_valores where k='aplicar';
insert into v107_resultados select '11 versão de outro contrato negada',j->>'codigo' in('PT404','42501'),j from (select pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000002',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),true,'Tentativa cruzada',null,'cruzado')$q$)j)x;
select set_config('request.jwt.claim.sub','c7070707-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"c7070707-0000-4000-8000-000000000002","role":"authenticated","session_id":"c7070707-0000-4000-9000-000000000002"}',true);
insert into v107_resultados select '12 leitor não aprova',j->>'codigo'='42501',j from (select pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),(select j->'valor'->'versao'->>'hash' from v107_valores where k='versao'),'Leitor','leitor')$q$)j)x;
insert into v107_resultados select '13 DML fonte não contorna RPC',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$with x as(insert into public.fontes_normativas(id_organizacao,tipo,titulo,situacao)values('c7070707-aaaa-4000-8000-000000000001','lei','Bypass','ativa')returning id)select to_jsonb(x) from x$q$)j)x;
reset role;
insert into v107_resultados select '14 grants sem bypass authenticated',not has_table_privilege('authenticated','public.fontes_normativas','INSERT') and not has_table_privilege('authenticated','public.fontes_normativas','UPDATE') and not has_table_privilege('authenticated','public.versoes_fontes_normativas','INSERT') and not has_table_privilege('authenticated','public.aplicabilidades_fonte','UPDATE'),null;
insert into v107_resultados select '15 auditoria única por comando efetivo',count(*)=5,jsonb_build_object('eventos',count(*)) from public.eventos_auditoria where id_organizacao='c7070707-aaaa-4000-8000-000000000001' and evento like 'V107%';
-- Acesso real e replays após revogação. SQL dinâmico somente neste teste.
select set_config('request.jwt.claim.sub','c7070707-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"c7070707-0000-4000-8000-000000000003","role":"authenticated","session_id":"c7070707-0000-4000-9000-000000000003"}',true);
set local role authenticated;
insert into v107_resultados select '16 gestor sem escopo negado',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000002',null,'lei','Sem acesso',null,null,'rascunho',null,'sem-escopo')$q$)j)x;
insert into v107_resultados select '17 gestor não aprova',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),(select j->'valor'->'versao'->>'hash' from v107_valores where k='versao'),'Não é aprovador','gestor-aprovar')$q$)j)x;
insert into v107_resultados select '18 tenant cruzado negado',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-bbbb-4000-8000-000000000001','c7070707-2000-4000-8000-000000000003',null,'lei','Outro tenant',null,null,'rascunho',null,'tenant')$q$)j)x;
reset role;
select set_config('request.jwt.claim.sub','c7070707-0000-4000-8000-000000000005',true);
select set_config('request.jwt.claims','{"sub":"c7070707-0000-4000-8000-000000000005","role":"authenticated","session_id":"c7070707-0000-4000-9000-000000000005"}',true);
set local role authenticated;
insert into v107_resultados select '19 Master sem vínculo organizacional funciona',coalesce((j->>'ok')::boolean,false),j from(select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-bbbb-4000-8000-000000000001','c7070707-2000-4000-8000-000000000003',null,'lei','Master',null,null,'rascunho',null,'master')$q$)j)x;
reset role;
update auth.sessions set not_after=now()-interval '1 minute' where id='c7070707-0000-4000-9000-000000000005';
set local role authenticated;
insert into v107_resultados select '20 sessão expirada nega inclusive replay',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-bbbb-4000-8000-000000000001','c7070707-2000-4000-8000-000000000003',null,'lei','Master',null,null,'rascunho',null,'master')$q$)j)x;
reset role;
insert into v107_resultados select '21 anon sem EXECUTE nas quatro operações',count(*)=4 and bool_and(not has_function_privilege('anon',p.oid,'EXECUTE')) and bool_and(not p.prosecdef),jsonb_build_object('funcoes',count(*)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('salvar_fonte_normativa_v107','registrar_versao_fonte_v107','aprovar_versao_fonte_v107','definir_aplicabilidade_fonte_v107');
select set_config('request.jwt.claim.sub','c7070707-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"c7070707-0000-4000-8000-000000000001","role":"authenticated","session_id":"c7070707-0000-4000-9000-000000000001"}',true);
set local role authenticated;
insert into v107_resultados select '22 aplicabilidade CAS obsoleto negado',j->>'codigo'='PT409',j from(select pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),false,'Não aplicar',null,'aplicar-stale')$q$)j)x;
insert into v107_resultados select '23 versão replay preserva resposta',coalesce(j=(select j from v107_valores where k='versao') and (j->>'ok')::boolean,false),j from(select pg_temp.v107_tentar($q$select public.registrar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'2026-01-01',null,null,'Texto oficial','{"pagina":1,"trecho":"Texto oficial"}','versao-1')$q$)j)x;
insert into v107_resultados select '24 aprovação replay preserva resposta',coalesce(j=(select j from v107_valores where k='aprovar') and (j->>'ok')::boolean,false),j from(select pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),(select j->'valor'->'versao'->>'hash' from v107_valores where k='versao'),'Revisão humana','aprovar-1')$q$)j)x;
insert into v107_resultados select '25 aplicação replay preserva resposta',coalesce(j=(select j from v107_valores where k='aplicar') and (j->>'ok')::boolean,false),j from(select pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao'),true,'Aplicável conforme objeto',null,'aplicar-1')$q$)j)x;
insert into v107_valores values('versao2',pg_temp.v107_tentar($q$select public.registrar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001',(select (j->'valor'->'fonte'->>'id')::uuid from v107_valores where k='criar'),'2027-01-01',null,null,'Outra versão','{}','versao-2')$q$));
insert into v107_resultados select '26 próxima versão preserva anterior',coalesce(j->'valor'->'versao'->>'versao'='2' and (select count(*)=1 from public.versoes_fontes_normativas where id=(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao') and conteudo_texto='Texto oficial' and aprovado_em is not null),false),j from v107_valores where k='versao2';
insert into v107_resultados select '27 versão aprovada não editável diretamente',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$with x as(update public.versoes_fontes_normativas set conteudo_texto='Adulterado' where id=(select (j->'valor'->'versao'->>'id')::uuid from v107_valores where k='versao')returning id)select to_jsonb(x) from x$q$)j)x;
reset role;
update public.vinculos_usuarios set ativo=false where id='c7070707-3000-4000-8000-000000000001';
set local role authenticated;
insert into v107_resultados select '28 acesso revogado impede replay de criação',j->>'codigo'='42501',j from(select pg_temp.v107_tentar($q$select public.salvar_fonte_normativa_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001',null,'lei','Lei teste','Origem formal',null,'rascunho',null,'criar-1')$q$)j)x;
reset role;
update public.vinculos_usuarios set ativo=true where id='c7070707-3000-4000-8000-000000000001';
-- As demais provas de contexto abaixo usam estado anterior sintético, sem contornar autorização em endpoints.
insert into public.fontes_normativas(id,id_organizacao,tipo,titulo,situacao) values('c7070707-4000-4000-8000-000000000001','c7070707-aaaa-4000-8000-000000000001','lei','Global sem aplicação','ativa');
insert into public.versoes_fontes_normativas(id,id_organizacao,id_fonte,versao,inicio_vigencia,conteudo_texto,hash) values
('c7070707-5000-4000-8000-000000000001','c7070707-aaaa-4000-8000-000000000001','c7070707-4000-4000-8000-000000000001',1,'2026-01-01','Global vigente',repeat('a',64)),
('c7070707-5000-4000-8000-000000000002','c7070707-aaaa-4000-8000-000000000001','c7070707-4000-4000-8000-000000000001',2,'2027-01-01','Global futura',repeat('b',64));
insert into public.competencias(id,id_organizacao,id_contrato,competencia_referencia,periodo_inicio,periodo_fim,situacao,percentual_conformidade,liberada_para_apresentacao_em) values
('c7070707-6000-4000-8000-000000000001','c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001','2026-01-01','2026-01-01','2026-01-31','pode_apresentar_contratante',100,now());
insert into v107_valores values('hash_antes',to_jsonb(privado.hash_contexto_competencia('c7070707-6000-4000-8000-000000000001')));
insert into v107_valores values('aprovar_global',pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-5000-4000-8000-000000000001',repeat('a',64),'Revisão formal','global-aprovacao')$q$));
insert into v107_resultados select '29 global sem aplicação não altera hash nem portão',coalesce((select (j->>'ok')::boolean from v107_valores where k='aprovar_global') and situacao='pode_apresentar_contratante' and to_jsonb(privado.hash_contexto_competencia(id))=(select j from v107_valores where k='hash_antes'),false),null from public.competencias where id='c7070707-6000-4000-8000-000000000001';
insert into v107_valores values('aplicar_global',pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001','c7070707-5000-4000-8000-000000000001',true,'Aplicabilidade formal',null,'global-aplicar')$q$));
insert into v107_resultados select '30 aplicação vigente altera hash e invalida portão',coalesce((select (j->>'ok')::boolean from v107_valores where k='aplicar_global') and situacao='em_reanalise' and liberada_para_apresentacao_em is null and to_jsonb(privado.hash_contexto_competencia(id))<>(select j from v107_valores where k='hash_antes'),false),null from public.competencias where id='c7070707-6000-4000-8000-000000000001';
update public.competencias set situacao='pode_apresentar_contratante',percentual_conformidade=100,liberada_para_apresentacao_em=now() where id='c7070707-6000-4000-8000-000000000001';
insert into v107_valores values('hash_futuro',to_jsonb(privado.hash_contexto_competencia('c7070707-6000-4000-8000-000000000001')));
insert into v107_valores values('aprovar_futura',pg_temp.v107_tentar($q$select public.aprovar_versao_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-5000-4000-8000-000000000002',repeat('b',64),'Vigência futura','futura-aprovacao')$q$));
insert into v107_valores values('aplicar_futura',pg_temp.v107_tentar($q$select public.definir_aplicabilidade_fonte_v107('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001','c7070707-5000-4000-8000-000000000002',true,'Aplicação futura',null,'futura-aplicar')$q$));
insert into v107_resultados select '31 vigência futura preserva hash e portão atual',coalesce((select (j->>'ok')::boolean from v107_valores where k='aplicar_futura') and situacao='pode_apresentar_contratante' and to_jsonb(privado.hash_contexto_competencia(id))=(select j from v107_valores where k='hash_futuro'),false),null from public.competencias where id='c7070707-6000-4000-8000-000000000001';
insert into v107_resultados select '32 captura inclui competência ainda em análise para coordenar liberação',
  privado.v107_capturar('c7070707-aaaa-4000-8000-000000000001','c7070707-2000-4000-8000-000000000001') ? 'c7070707-6000-4000-8000-000000000001',null;
select jsonb_build_object('total',count(*),'passou',count(*)filter(where passou),'falhas',coalesce(jsonb_agg(jsonb_build_object('teste',teste,'detalhe',detalhe)order by teste)filter(where not passou),'[]')) from v107_resultados;
select count(*) filter(where passou) as passou,count(*) as total from v107_resultados;
rollback;

