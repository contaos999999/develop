create table public.contratos (
  id uuid primary key,
  id_organizacao uuid not null,
  configuracao_diligencia jsonb not null
);

insert into public.contratos values
  (fixture_id(2),fixture_id(1),'{"prazo_padrao_dias":5,"tipo_contagem":"corridos"}'),
  (fixture_id(3),fixture_id(9),'{"prazo_padrao_dias":2,"tipo_contagem":"corridos"}'),
  (fixture_id(4),fixture_id(1),'{"prazo_padrao_dias":7,"tipo_contagem":"uteis"}'),
  (fixture_id(5),fixture_id(1),'{"prazo_padrao_dias":2.5,"tipo_contagem":"corridos"}');

insert into public.competencias
select fixture_id(30+n), id_organizacao, id, 'aguardando_contratante', null
from (values (0,2),(1,3),(2,4),(3,2),(4,2),(5,5)) as dados(n,contrato)
join public.contratos on id=fixture_id(contrato);

insert into public.apresentacoes_contratante
select fixture_id(n+100),id_organizacao,id_contrato,id,1
from generate_series(30,35) n join public.competencias on id=fixture_id(n);

insert into public.arquivos
select fixture_id(n+40),id_organizacao,id_contrato,'aprovado','application/pdf',repeat('a',64),'contaos-documentos'
from generate_series(30,35) n join public.competencias on id=fixture_id(n);
