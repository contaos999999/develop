begin;
alter table public.configuracoes_automacao alter column provedor_ia set default 'openai';
alter table public.configuracoes_automacao alter column provedor_ocr set default 'openai';
update public.configuracoes_automacao set provedor_ia='openai',provedor_ocr='openai',configuracao_publica=coalesce(configuracao_publica,'{}'::jsonb)||jsonb_build_object('base_url','https://api.openai.com/v1','ocr_modo','visao_multimodal','segredo_api','OPENAI_API_KEY') where ativo=true;
commit;
