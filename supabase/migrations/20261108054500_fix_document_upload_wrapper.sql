-- Delegate through the existing authenticated entry; private RPC authorization remains unchanged.
ALTER FUNCTION public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) SECURITY DEFINER;
