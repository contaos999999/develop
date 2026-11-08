-- Preserve the private RBAC/session/tenant/status/date guards; change only delegation.
ALTER FUNCTION public.definir_vigencia_sugestao_extracao(uuid,date,date) SECURITY DEFINER;
