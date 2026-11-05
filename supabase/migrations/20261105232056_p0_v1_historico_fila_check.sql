-- Supabase CLI 2.81.3 migration new p0_v1_historico_fila_check
-- Generated filename confirmed by Actions run 42128916139, artifact 13462327441.
-- HML only. No RLS, grants, Auth, or function changes.
DO $guard$
DECLARE
  existing_definition text;
BEGIN
  SELECT pg_get_constraintdef(c.oid) INTO existing_definition
  FROM pg_constraint c
  WHERE c.conrelid = 'public.execucoes_assincronas'::regclass
    AND c.conname = 'execucoes_assincronas_fila_check'
    AND c.contype = 'c';
  IF existing_definition IS DISTINCT FROM
    'CHECK ((fila = ANY (ARRAY[''documents''::text, ''ocr''::text, ''ai''::text, ''embeddings''::text, ''finance_imports''::text, ''reports''::text, ''integrations''::text, ''webhooks''::text])))'
  THEN
    RAISE EXCEPTION 'PRECONDITION FAILED: fila CHECK drift or missing';
  END IF;
END
$guard$;

ALTER TABLE public.execucoes_assincronas
  DROP CONSTRAINT execucoes_assincronas_fila_check;

ALTER TABLE public.execucoes_assincronas
  ADD CONSTRAINT execucoes_assincronas_fila_check
  CHECK (fila = ANY (ARRAY[
    'documents'::text, 'ocr'::text, 'ai'::text, 'embeddings'::text,
    'finance_imports'::text, 'reports'::text, 'integrations'::text,
    'webhooks'::text, 'historico'::text
  ]));
-- Rollback only if no rows with fila='historico'; otherwise retain constraint.
