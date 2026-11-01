begin;

create table public.catalogo_mensagens_sistema (
  codigo text primary key,
  categoria text not null,
  severidade text not null check (severidade in ('info','sucesso','aviso','erro')),
  titulo text not null,
  mensagem text not null,
  orientacao text,
  exibir_detalhe_tecnico boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.catalogo_mensagens_sistema enable row level security;
create policy catalogo_mensagens_leitura on public.catalogo_mensagens_sistema for select to anon,authenticated using(true);
grant select on public.catalogo_mensagens_sistema to anon,authenticated;

insert into public.catalogo_mensagens_sistema(codigo,categoria,severidade,titulo,mensagem,orientacao) values
('GERAL_SUCESSO','geral','sucesso','Tudo certo','A operação foi concluída com sucesso.',null),
('GERAL_PROCESSANDO','geral','info','Estamos processando','Seu pedido foi recebido e está sendo processado. Você pode continuar usando o sistema normalmente.','Acompanhe o status nesta tela.'),
('GERAL_ERRO_INESPERADO','geral','erro','Não foi possível concluir','Ocorreu um problema inesperado ao concluir esta ação. Nenhuma informação confirmada foi perdida.','Tente novamente. Se o problema continuar, informe o código exibido ao suporte.'),
('AUTH_NAO_AUTENTICADO','autenticacao','aviso','Sessão necessária','Para continuar, faça login novamente.','Entre novamente na sua conta e repita a ação.'),
('AUTH_SESSAO_EXPIRADA','autenticacao','aviso','Sua sessão expirou','Por segurança, sua sessão foi encerrada.','Faça login novamente para continuar de onde parou.'),
('AUTH_ACESSO_NEGADO','autorizacao','aviso','Acesso não permitido','Seu usuário não tem permissão para realizar esta ação.','Se você acredita que deveria ter acesso, fale com o administrador da sua organização.'),
('AUTH_PERFIL_SEM_PERMISSAO','autorizacao','aviso','Permissão insuficiente','Seu perfil atual não permite concluir esta operação.','Solicite ao administrador a revisão das suas permissões.'),
('REGISTRO_NAO_ENCONTRADO','dados','aviso','Item não encontrado','Não encontramos o item solicitado ou ele não está mais disponível.','Atualize a página e tente novamente.'),
('DADOS_INVALIDOS','validacao','aviso','Revise as informações','Alguns dados informados precisam ser corrigidos antes de continuar.','Confira os campos destacados e tente novamente.'),
('CAMPO_OBRIGATORIO','validacao','aviso','Informação obrigatória','Preencha todas as informações obrigatórias para continuar.','Confira os campos marcados como obrigatórios.'),
('REGISTRO_DUPLICADO','validacao','aviso','Registro já existente','Já existe um registro com essas mesmas informações.','Abra o registro existente ou altere os dados antes de salvar.'),
('CONFLITO_ATUALIZACAO','concorrencia','aviso','Informação atualizada por outra pessoa','Este registro foi alterado enquanto você estava trabalhando nele.','Atualize a tela, confira a versão mais recente e tente novamente.'),
('EVIDENCIA_OBRIGATORIA','conformidade','aviso','Evidência necessária','Esta etapa só pode ser concluída após anexar uma evidência válida.','Anexe o documento ou evidência solicitada e tente novamente.'),
('PORTAO_CONFORMIDADE_100','conformidade','aviso','Ainda não pode ser apresentado','A prestação de contas ainda possui requisitos pendentes ou não conformes.','Conclua 100% dos requisitos obrigatórios antes de liberar a apresentação ao contratante.'),
('PORTAO_REAPRESENTACAO_100','diligencia','aviso','Ainda não pode ser reapresentado','Ainda existem apontamentos da rodada que precisam ser tratados.','Conclua todos os apontamentos obrigatórios antes de liberar a reapresentação.'),
('APROVACAO_HUMANA_OBRIGATORIA','conformidade','aviso','Aprovação necessária','Esta ação exige uma aprovação humana antes de prosseguir.','Encaminhe para o responsável aprovador.'),
('ARQUIVO_UPLOAD_FALHOU','documentos','erro','Não foi possível enviar o arquivo','O arquivo não foi enviado com sucesso.','Verifique sua conexão e tente novamente. O arquivo original não foi alterado.'),
('ARQUIVO_TIPO_NAO_SUPORTADO','documentos','aviso','Formato de arquivo não aceito','Este tipo de arquivo não pode ser processado pelo ContaOS.','Envie o documento em um dos formatos aceitos nesta etapa.'),
('ARQUIVO_MUITO_GRANDE','documentos','aviso','Arquivo acima do limite','O arquivo enviado ultrapassa o tamanho permitido.','Reduza o tamanho do arquivo ou divida o conteúdo em arquivos menores.'),
('DOCUMENTO_PROCESSAMENTO_FALHOU','documentos','erro','Não foi possível analisar o documento','O documento foi recebido, mas ocorreu um problema durante o processamento.','Tente processar novamente. Se o erro continuar, mantenha o arquivo e acione o suporte.'),
('ANALISE_EM_PROCESSAMENTO','analise','info','Análise em andamento','O ContaOS está analisando os documentos e requisitos desta competência.','Você será informado quando a análise estiver concluída.'),
('ANALISE_FALHOU','analise','erro','A análise não foi concluída','Ocorreu um problema durante a análise automática. Nenhuma decisão foi tomada automaticamente.','Tente executar a análise novamente ou encaminhe para revisão humana.'),
('IA_INDISPONIVEL','ia','aviso','Assistente temporariamente indisponível','O recurso de inteligência artificial não conseguiu responder neste momento.','Tente novamente mais tarde. As demais funções do ContaOS continuam disponíveis.'),
('FONTE_INSUFICIENTE','ia','aviso','Informações insuficientes','Não encontramos evidências suficientes para responder com segurança.','Revise os documentos disponíveis ou inclua novas fontes antes de concluir.'),
('IMPORTACAO_FINANCEIRA_FALHOU','financeiro','erro','Importação não concluída','Não foi possível concluir a importação dos dados financeiros.','Confira o arquivo de origem e tente novamente. Nenhum lançamento foi confirmado parcialmente.'),
('CONCILIACAO_COM_DIFERENCA','financeiro','aviso','Diferença encontrada na conciliação','Os valores conciliados apresentam diferença e precisam de revisão.','Confira os lançamentos e documentos relacionados antes de concluir a competência.'),
('ALERTA_PREVENTIVO_ABERTO','financeiro','aviso','Atenção necessária','Foi identificado um ponto que merece revisão antes da prestação de contas.','Analise o alerta, registre o tratamento e anexe a evidência quando aplicável.'),
('WEBHOOK_FALHOU','integracao','aviso','Integração não confirmada','O ContaOS não conseguiu confirmar o envio da informação para o sistema integrado.','O sistema tentará novamente automaticamente. Você pode acompanhar o status da integração.'),
('INTEGRACAO_INDISPONIVEL','integracao','aviso','Integração temporariamente indisponível','O serviço integrado não respondeu neste momento.','O ContaOS tentará novamente quando possível.'),
('FILA_RETRY','processamento','info','Nova tentativa programada','O processamento não foi concluído nesta tentativa e será repetido automaticamente.','Nenhuma ação é necessária agora.'),
('FILA_DLQ','processamento','erro','Processamento precisa de atenção','Após várias tentativas, o processamento ainda não foi concluído.','O registro foi preservado para análise técnica sem perda dos dados originais.'),
('REDE_INDISPONIVEL','conectividade','aviso','Sem conexão com o serviço','Não foi possível se comunicar com o serviço neste momento.','Verifique sua conexão e tente novamente.'),
('LIMITE_REQUISICOES','conectividade','aviso','Muitas solicitações em pouco tempo','Recebemos várias solicitações seguidas e precisamos aguardar alguns instantes.','Aguarde um pouco e tente novamente.'),
('MANUTENCAO','geral','info','Serviço em manutenção','Este recurso está temporariamente em manutenção.','Tente novamente mais tarde.')
on conflict(codigo) do update set categoria=excluded.categoria,severidade=excluded.severidade,titulo=excluded.titulo,mensagem=excluded.mensagem,orientacao=excluded.orientacao,atualizado_em=now();

create table public.catalogo_status_ui (
  dominio text not null,
  codigo text not null,
  rotulo text not null,
  descricao text,
  tom text not null default 'neutro' check(tom in ('neutro','info','sucesso','aviso','erro')),
  ordem integer not null default 0,
  criado_em timestamptz not null default now(),
  primary key(dominio,codigo)
);
alter table public.catalogo_status_ui enable row level security;
create policy catalogo_status_leitura on public.catalogo_status_ui for select to anon,authenticated using(true);
grant select on public.catalogo_status_ui to anon,authenticated;

insert into public.catalogo_status_ui(dominio,codigo,rotulo,descricao,tom,ordem) values
('competencia','rascunho','Rascunho','Competência criada e ainda em preparação.','neutro',10),
('competencia','preparando','Em preparação','Documentos e requisitos estão sendo organizados.','info',20),
('competencia','em_analise','Em análise','A competência está sendo analisada.','info',30),
('competencia','pendente_correcao','Correções pendentes','Existem pontos que precisam ser corrigidos.','aviso',40),
('competencia','em_reanalise','Em reanálise','As correções estão sendo verificadas novamente.','info',50),
('competencia','pode_apresentar_contratante','PODE APRESENTAR AO CONTRATANTE','A competência atingiu os requisitos necessários e foi aprovada para apresentação.','sucesso',60),
('competencia','apresentado','Apresentado','A prestação de contas foi apresentada ao contratante.','info',70),
('competencia','aguardando_contratante','Aguardando contratante','Aguardando análise ou retorno do contratante.','info',80),
('competencia','com_apontamentos','Com apontamentos','O contratante apresentou pontos que precisam ser tratados.','aviso',90),
('competencia','pode_reapresentar_contratante','PODE REAPRESENTAR AO CONTRATANTE','Todos os apontamentos obrigatórios da rodada foram tratados e aprovados.','sucesso',100),
('competencia','reapresentado','Reapresentado','A resposta aos apontamentos foi reapresentada ao contratante.','info',110),
('competencia','validada','Validada','A competência foi validada pelo contratante.','sucesso',120),
('competencia','encerrada','Encerrada','O ciclo desta competência foi encerrado.','sucesso',130),
('competencia','cancelada','Cancelada','Esta competência foi cancelada.','erro',140),
('job','enfileirado','Aguardando processamento','A solicitação entrou na fila de processamento.','info',10),
('job','processando','Processando','O ContaOS está executando esta tarefa.','info',20),
('job','concluido','Concluído','O processamento foi concluído com sucesso.','sucesso',30),
('job','falhou','Falha temporária','A tarefa não foi concluída nesta tentativa.','aviso',40),
('job','cancelado','Interrompido','O processamento foi interrompido e precisa de revisão.','erro',50),
('alerta','aberto','Aberto','O alerta precisa ser analisado.','aviso',10),
('alerta','em_tratamento','Em tratamento','O alerta está sendo tratado.','info',20),
('alerta','resolvido','Resolvido','O alerta foi tratado e encerrado.','sucesso',30),
('alerta','descartado','Descartado','O alerta foi avaliado e descartado com justificativa.','neutro',40)
on conflict(dominio,codigo) do update set rotulo=excluded.rotulo,descricao=excluded.descricao,tom=excluded.tom,ordem=excluded.ordem;

create or replace function public.obter_mensagem_sistema(p_codigo text)
returns jsonb language sql stable security invoker set search_path='' as $$
  select coalesce(
    (select jsonb_build_object('codigo',m.codigo,'categoria',m.categoria,'severidade',m.severidade,'titulo',m.titulo,'mensagem',m.mensagem,'orientacao',m.orientacao) from public.catalogo_mensagens_sistema m where m.codigo=p_codigo),
    (select jsonb_build_object('codigo',m.codigo,'categoria',m.categoria,'severidade',m.severidade,'titulo',m.titulo,'mensagem',m.mensagem,'orientacao',m.orientacao) from public.catalogo_mensagens_sistema m where m.codigo='GERAL_ERRO_INESPERADO')
  )
$$;
revoke all on function public.obter_mensagem_sistema(text) from public;
grant execute on function public.obter_mensagem_sistema(text) to anon,authenticated;

create or replace function public.normalizar_erro_backend(p_codigo_sql text,p_mensagem_tecnica text default null)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_codigo text:='GERAL_ERRO_INESPERADO'; v_msg text:=lower(coalesce(p_mensagem_tecnica,''));
begin
  if p_codigo_sql in ('23505') then v_codigo:='REGISTRO_DUPLICADO';
  elsif p_codigo_sql in ('23502','23514','22P02') then v_codigo:='DADOS_INVALIDOS';
  elsif p_codigo_sql in ('42501') or v_msg like '%row-level security%' or v_msg like '%permission denied%' then v_codigo:='AUTH_ACESSO_NEGADO';
  elsif p_codigo_sql in ('P0001') and (v_msg like '%não autenticado%' or v_msg like '%sessão%') then v_codigo:='AUTH_NAO_AUTENTICADO';
  elsif v_msg like '%100% de conformidade%' or v_msg like '%100,00%' then v_codigo:='PORTAO_CONFORMIDADE_100';
  elsif v_msg like '%100% tratada%' or v_msg like '%reapresentação não liberada%' then v_codigo:='PORTAO_REAPRESENTACAO_100';
  elsif v_msg like '%evidência%obrigatória%' then v_codigo:='EVIDENCIA_OBRIGATORIA';
  elsif v_msg like '%não encontrada%' or v_msg like '%não encontrado%' then v_codigo:='REGISTRO_NAO_ENCONTRADO';
  elsif v_msg like '%perfil sem permissão%' or v_msg like '%permissão%' then v_codigo:='AUTH_PERFIL_SEM_PERMISSAO';
  elsif v_msg like '%acesso negado%' then v_codigo:='AUTH_ACESSO_NEGADO';
  end if;
  return public.obter_mensagem_sistema(v_codigo);
end;$$;
revoke all on function public.normalizar_erro_backend(text,text) from public;
grant execute on function public.normalizar_erro_backend(text,text) to anon,authenticated;

-- Reforço de mensagens amigáveis nas notificações internas.
comment on table public.catalogo_mensagens_sistema is 'Catálogo oficial de mensagens de interface do ContaOS em português do Brasil. Não exibir mensagens técnicas cruas ao usuário final.';
comment on table public.catalogo_status_ui is 'Rótulos e descrições oficiais de status do ContaOS em português do Brasil para uso pelo frontend.';

commit;
