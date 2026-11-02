alter table public.configuracoes_automacao alter column modelo_ia set default 'gpt-6-luna';
update public.configuracoes_automacao set modelo_ia='gpt-6-luna', atualizado_em=now(), versao_registro=versao_registro+1 where modelo_ia='gpt-6.1-sol';

create or replace function privado.criar_configuracao_automacao_padrao()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  insert into public.configuracoes_automacao(
    id_organizacao, provedor_ia, modelo_ia, provedor_ocr, modelo_ocr,
    modo_ia, modo_ocr, configuracao_publica, ativo
  ) values(
    new.id, 'openai', 'gpt-6-luna', 'openai', 'gpt-6-luna',
    'assistido', 'assistido',
    jsonb_build_object(
      'idioma','pt-BR',
      'timezone','America/Sao_Paulo',
      'aprovacao_humana_obrigatoria',true,
      'modelo_analise_preferencial_quando_disponivel','gpt-6.1-sol'
    ), true
  ) on conflict(id_organizacao) do nothing;
  return new;
end;
$function$;

comment on column public.configuracoes_automacao.modelo_ia is 'Modelo operacional de análise OpenAI. HML usa gpt-6-luna; modelo de maior capacidade pode ser configurado quando houver quota, sem alterar regras de negócio.';
