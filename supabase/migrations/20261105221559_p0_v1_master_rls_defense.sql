-- P0 V1 MASTER | migration criada via Supabase CLI v2.81.3, run 42119980043.
-- HML only. Defesa em profundidade na tabela privada, sem expor grants.
-- Não usar FORCE ROW LEVEL SECURITY: SECURITY DEFINER owner postgres depende de acesso.
DO $guard$
BEGIN
  IF to_regclass('privado.administradores_master') IS NULL THEN
    RAISE EXCEPTION 'Tabela MASTER ausente; impedir aplicação';
  END IF;
  IF (SELECT relrowsecurity FROM pg_class WHERE oid = 'privado.administradores_master'::regclass) THEN
    RAISE EXCEPTION 'RLS MASTER já ativo; investigar drift antes da migration';
  END IF;
  IF (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'privado.administradores_master'::regclass) <> 'postgres' THEN
    RAISE EXCEPTION 'Owner inesperado da tabela MASTER; interromper';
  END IF;
  IF has_table_privilege('anon', 'privado.administradores_master', 'SELECT')
     OR has_table_privilege('authenticated', 'privado.administradores_master', 'SELECT') THEN
    RAISE EXCEPTION 'Grants MASTER inesperados; interromper';
  END IF;
END
$guard$;

ALTER TABLE privado.administradores_master ENABLE ROW LEVEL SECURITY;

-- Sem policies: leitura direta de cliente continua DENY.
-- Proprietário postgres, executor das funções SECURITY DEFINER existentes,
-- não está sujeito a RLS ordinário enquanto FORCE RLS permanecer desabilitado.
DO $verify$
BEGIN
  IF NOT (SELECT relrowsecurity AND NOT relforcerowsecurity FROM pg_class WHERE oid = 'privado.administradores_master'::regclass) THEN
    RAISE EXCEPTION 'Verificação RLS MASTER falhou';
  END IF;
  IF has_table_privilege('anon','privado.administradores_master','SELECT')
     OR has_table_privilege('authenticated','privado.administradores_master','SELECT') THEN
    RAISE EXCEPTION 'Cliente recebeu SELECT na tabela MASTER';
  END IF;
END $verify$;
