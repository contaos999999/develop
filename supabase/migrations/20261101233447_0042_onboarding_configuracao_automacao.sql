begin;

create or replace function privado.criar_configuracao_automacao_padrao()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  insert into public.configuracoes_automacao(
    id_organizacao,
    provedor_ia,
    modelo_ia,
    provedor_ocr,
    modelo_ocr,
    modo_ia,
    modo_ocr,
    configuracao_publica,
    ativo
  )
  values(
    new.id,
    'openai',
    'gpt-6.1-sol',
    'openai',
    'gpt-6-luna',
    'assistido',
    'assistido',
    jsonb_build_object(
      'idioma','pt-BR',
      'timezone','America/Sao_Paulo',
      'aprovacao_humana_obrigatoria',true
    ),
    true
  )
  on conflict(id_organizacao) do nothing;
  return new;
end;
$$;

revoke all on function privado.criar_configuracao_automacao_padrao() from public,anon,authenticated;

drop trigger if exists contaos_organizacao_config_automacao on public.organizacoes;
create trigger contaos_organizacao_config_automacao
after insert on public.organizacoes
for each row execute function privado.criar_configuracao_automacao_padrao();

insert into public.configuracoes_automacao(
  id_organizacao,
  provedor_ia,
  modelo_ia,
  provedor_ocr,
  modelo_ocr,
  modo_ia,
  modo_ocr,
  configuracao_publica,
  ativo
)
select
  o.id,
  'openai',
  'gpt-6.1-sol',
  'openai',
  'gpt-6-luna',
  'assistido',
  'assistido',
  jsonb_build_object(
    'idioma','pt-BR',
    'timezone','America/Sao_Paulo',
    'aprovacao_humana_obrigatoria',true
  ),
  true
from public.organizacoes o
on conflict(id_organizacao) do nothing;

commit;
