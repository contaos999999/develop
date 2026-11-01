begin;

alter table public.configuracoes_automacao
  add column if not exists modelo_ocr text;

alter table public.configuracoes_automacao
  alter column provedor_ia set default 'openai',
  alter column provedor_ocr set default 'openai',
  alter column modelo_ia set default 'gpt-6.1-sol',
  alter column modelo_ocr set default 'gpt-6-luna';

update public.configuracoes_automacao
set provedor_ia='openai',
    provedor_ocr='openai',
    modelo_ia=coalesce(modelo_ia,'gpt-6.1-sol'),
    modelo_ocr=coalesce(modelo_ocr,'gpt-6-luna'),
    configuracao_publica=coalesce(configuracao_publica,'{}'::jsonb) || jsonb_build_object(
      'idioma','pt-BR',
      'timezone','America/Sao_Paulo',
      'ocr_detalhe','high',
      'revisao_humana_obrigatoria',true,
      'segredos_no_frontend',false
    ),
    atualizado_em=now();

insert into public.catalogo_mensagens_sistema(codigo,categoria,severidade,titulo,mensagem,orientacao,exibir_detalhe_tecnico)
values
 ('OPENAI_OK','integracao','info','Inteligência artificial conectada','A integração com a OpenAI está disponível para o ContaOS.','Nenhuma ação é necessária.',false),
 ('OPENAI_INDISPONIVEL','integracao','aviso','Inteligência artificial temporariamente indisponível','Não foi possível usar a inteligência artificial neste momento. O ContaOS tentará novamente automaticamente.','Você pode continuar usando as demais funções do sistema.',false),
 ('OCR_CONCLUIDO','documento','info','Leitura concluída','O documento foi lido com sucesso e seguirá para análise.','Aguarde a conclusão da análise automática.',false),
 ('OCR_FALHOU','documento','aviso','Leitura não concluída','Não foi possível concluir a leitura automática do documento. O ContaOS tentará novamente automaticamente.','Se o aviso persistir, envie o arquivo novamente ou acione o suporte.',false)
on conflict (codigo) do update set categoria=excluded.categoria,severidade=excluded.severidade,titulo=excluded.titulo,mensagem=excluded.mensagem,orientacao=excluded.orientacao,exibir_detalhe_tecnico=false,atualizado_em=now();

commit;
