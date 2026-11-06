CREATE OR REPLACE FUNCTION public.registrar_relatorio_historico_hml(p_id_arquivo uuid,p_competencia date,p_tipo text DEFAULT 'relatorio_contratante') RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v_arquivo public.arquivos%ROWTYPE; v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO v_arquivo FROM public.arquivos WHERE id=p_id_arquivo;
 IF NOT FOUND THEN RAISE EXCEPTION 'Arquivo não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(v_arquivo.id_contrato) OR NOT privado.usuario_possui_perfil(v_arquivo.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão para importar histórico.'; END IF;
 IF v_arquivo.status_seguranca <> 'aprovado' THEN RAISE EXCEPTION 'Arquivo ainda não aprovado pela validação de segurança.'; END IF;
 IF p_competencia IS NULL OR extract(day FROM p_competencia) <> 1 THEN RAISE EXCEPTION 'Informe o primeiro dia da competência.'; END IF;
 IF p_tipo NOT IN ('relatorio_contratante','parecer_contratante','resposta_contratante','outro') THEN RAISE EXCEPTION 'Tipo de relatório inválido.'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id_arquivo::text,0));
 SELECT id INTO v_id FROM public.relatorios_historicos_contratante WHERE id_arquivo=p_id_arquivo AND id_contrato=v_arquivo.id_contrato ORDER BY criado_em LIMIT 1;
 IF v_id IS NOT NULL THEN RETURN v_id; END IF;
 INSERT INTO public.relatorios_historicos_contratante(id_organizacao,id_contrato,id_arquivo,competencia_referencia,tipo,origem_temporal,status_processamento,criado_por)
 VALUES(v_arquivo.id_organizacao,v_arquivo.id_contrato,v_arquivo.id,p_competencia,p_tipo,'pre_implantacao','pendente',auth.uid()) RETURNING id INTO v_id;
 PERFORM privado.registrar_evento_auditoria(v_arquivo.id_organizacao,'HistoricoImportacaoRegistrada','relatorios_historicos_contratante',v_id,NULL,pg_catalog.jsonb_build_object('id_arquivo',p_id_arquivo,'competencia',p_competencia));
 RETURN v_id;
END;$fn$;
REVOKE ALL ON FUNCTION public.registrar_relatorio_historico_hml(uuid,date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.registrar_relatorio_historico_hml(uuid,date,text) TO authenticated;
