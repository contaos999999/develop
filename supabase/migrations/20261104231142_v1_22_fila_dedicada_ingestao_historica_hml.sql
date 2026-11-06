SELECT pgmq.create('historico');
CREATE OR REPLACE FUNCTION public.enfileirar_ingestao_historica_hml(p_id_relatorio uuid,p_id_versao_documento uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE r public.relatorios_historicos_contratante%ROWTYPE; v public.versoes_documento%ROWTYPE; e uuid; m bigint;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO r FROM public.relatorios_historicos_contratante WHERE id=p_id_relatorio FOR UPDATE;
 SELECT * INTO v FROM public.versoes_documento WHERE id=p_id_versao_documento;
 IF r.id IS NULL OR v.id IS NULL THEN RAISE EXCEPTION 'Relatório ou versão documental não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(r.id_contrato) OR NOT privado.usuario_possui_perfil(r.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão.'; END IF;
 IF r.id_arquivo<>v.id_arquivo OR r.id_organizacao<>v.id_organizacao OR r.id_contrato<>v.id_contrato THEN RAISE EXCEPTION 'Versão não pertence ao relatório deste contrato.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.processamentos_documento WHERE id_versao_documento=v.id AND status='concluido') THEN RAISE EXCEPTION 'Aguarde a conclusão da leitura documental.'; END IF;
 SELECT id INTO e FROM public.execucoes_assincronas WHERE fila='historico' AND id_organizacao=r.id_organizacao AND chave_idempotencia='historico:'||r.id::text;
 IF e IS NOT NULL THEN RETURN e; END IF;
 SELECT pgmq.send('historico',pg_catalog.jsonb_build_object('id_relatorio',r.id,'id_versao_documento',v.id,'id_organizacao',r.id_organizacao,'id_contrato',r.id_contrato)) INTO m;
 INSERT INTO public.execucoes_assincronas(id_organizacao,id_contrato,fila,entidade_tipo,entidade_id,chave_idempotencia,message_id) VALUES(r.id_organizacao,r.id_contrato,'historico','relatorio_historico',r.id,'historico:'||r.id::text,m) RETURNING id INTO e;
 PERFORM privado.registrar_evento_auditoria(r.id_organizacao,'IngestaoHistoricaEnfileirada','relatorios_historicos_contratante',r.id,NULL,pg_catalog.jsonb_build_object('id_execucao',e,'id_versao_documento',v.id));
 RETURN e;
END;$fn$;
REVOKE ALL ON FUNCTION public.enfileirar_ingestao_historica_hml(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.enfileirar_ingestao_historica_hml(uuid,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.worker_pull_historico_hml() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE m record; e uuid;
BEGIN
 IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Acesso negado ao worker.'; END IF;
 SELECT * INTO m FROM pgmq.read('historico',120,1) LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 SELECT id INTO e FROM public.execucoes_assincronas WHERE fila='historico' AND message_id=m.msg_id;
 UPDATE public.execucoes_assincronas SET status='processando',tentativas=m.read_ct,iniciado_em=coalesce(iniciado_em,now()) WHERE id=e;
 RETURN pg_catalog.jsonb_build_object('msg_id',m.msg_id,'read_ct',m.read_ct,'payload',m.message,'id_execucao',e);
END;$fn$;
REVOKE ALL ON FUNCTION public.worker_pull_historico_hml() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.worker_pull_historico_hml() TO service_role;
CREATE OR REPLACE FUNCTION public.worker_finalizar_historico_hml(p_msg_id bigint,p_sucesso boolean,p_erro text DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE e public.execucoes_assincronas%ROWTYPE; v_removed boolean;
BEGIN
 IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Acesso negado ao worker.'; END IF;
 SELECT * INTO e FROM public.execucoes_assincronas WHERE fila='historico' AND message_id=p_msg_id FOR UPDATE;
 IF e.id IS NULL THEN RAISE EXCEPTION 'Execução não encontrada.'; END IF;
 IF p_sucesso OR e.tentativas>=5 THEN SELECT pgmq.delete('historico',p_msg_id) INTO v_removed; END IF;
 UPDATE public.execucoes_assincronas SET status=CASE WHEN p_sucesso THEN 'concluido' WHEN e.tentativas>=5 THEN 'cancelado' ELSE 'falhou' END,erro_codigo=CASE WHEN p_sucesso THEN NULL ELSE 'HISTORICO_PROCESSAMENTO_FALHOU' END,erro_detalhe=left(p_erro,4000),concluido_em=CASE WHEN p_sucesso OR e.tentativas>=5 THEN now() ELSE NULL END WHERE id=e.id;
END;$fn$;
REVOKE ALL ON FUNCTION public.worker_finalizar_historico_hml(bigint,boolean,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.worker_finalizar_historico_hml(bigint,boolean,text) TO service_role;
