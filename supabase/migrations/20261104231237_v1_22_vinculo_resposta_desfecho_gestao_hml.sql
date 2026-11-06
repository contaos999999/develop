CREATE OR REPLACE FUNCTION public.vincular_tratamento_historico_hml(p_id_apontamento uuid,p_resposta text DEFAULT NULL,p_desfecho text DEFAULT NULL,p_fundamento text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE a public.apontamentos_historicos%ROWTYPE; vr uuid; vd uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sessão necessária.'; END IF;
 SELECT * INTO a FROM public.apontamentos_historicos WHERE id=p_id_apontamento;
 IF a.id IS NULL THEN RAISE EXCEPTION 'Apontamento não encontrado.'; END IF;
 IF NOT privado.usuario_tem_acesso_contrato(a.id_contrato) OR NOT privado.usuario_possui_perfil(a.id_organizacao,ARRAY['administrador','gestor_contrato']::text[]) THEN RAISE EXCEPTION 'Perfil de gestão sem permissão.'; END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_resposta,'')),'') IS NULL AND nullif(pg_catalog.btrim(coalesce(p_desfecho,'')),'') IS NULL THEN RAISE EXCEPTION 'Informe resposta ou desfecho.'; END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_resposta,'')),'') IS NOT NULL THEN
 INSERT INTO public.respostas_historicas(id_organizacao,id_contrato,id_apontamento,texto) VALUES(a.id_organizacao,a.id_contrato,a.id,left(pg_catalog.btrim(p_resposta),12000)) RETURNING id INTO vr;
 END IF;
 IF nullif(pg_catalog.btrim(coalesce(p_desfecho,'')),'') IS NOT NULL THEN
 INSERT INTO public.desfechos_historicos(id_organizacao,id_contrato,id_apontamento,resultado,fundamento,data) VALUES(a.id_organizacao,a.id_contrato,a.id,left(pg_catalog.btrim(p_desfecho),5000),nullif(left(pg_catalog.btrim(coalesce(p_fundamento,'')),5000),''),CURRENT_DATE) RETURNING id INTO vd;
 END IF;
 PERFORM privado.registrar_evento_auditoria(a.id_organizacao,'TratamentoHistoricoVinculado','apontamentos_historicos',a.id,NULL,pg_catalog.jsonb_build_object('id_resposta',vr,'id_desfecho',vd));
 RETURN pg_catalog.jsonb_build_object('id_resposta',vr,'id_desfecho',vd);
END;$fn$;
REVOKE ALL ON FUNCTION public.vincular_tratamento_historico_hml(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.vincular_tratamento_historico_hml(uuid,text,text,text) TO authenticated;
