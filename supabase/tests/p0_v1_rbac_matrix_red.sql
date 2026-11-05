-- P0-V1-RBAC TDD RED. Execute APENAS em HML, read-only, nunca como teste de CI verde.
-- Falha esperada (SQLSTATE P0001) até a implementação da matriz.
-- Não simula JWT e não concede autorização.
DO $red$
DECLARE missing text[];
BEGIN
  SELECT array_agg(obj) INTO missing FROM (
    SELECT 'privado.' || x AS obj
    FROM unnest(ARRAY['rbac_catalogo_acoes','rbac_permissoes_perfis','rbac_versoes']) x
    WHERE to_regclass('privado.' || x) IS NULL
    UNION ALL
    SELECT x FROM unnest(ARRAY[
      'public.consultar_permissoes_efetivas',
      'public.atualizar_matriz_rbac_master',
      'privado.rbac_permite'
    ]) x
    WHERE NOT EXISTS (
      SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname=split_part(x,'.',1) AND p.proname=split_part(x,'.',2)
    )
  ) missing_objects;
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE='RED esperado: objetos RBAC ausentes', DETAIL=array_to_string(missing,', ');
  END IF;
END $red$;
