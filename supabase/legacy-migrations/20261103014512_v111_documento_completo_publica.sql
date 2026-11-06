-- ContaOS 4.1 — V1-CON-001
begin;
create or replace function public.criar_documento_contrato_completo(
  p_id_contrato uuid,p_tipo text,p_titulo text,p_categoria text,
  p_vigencia_inicio date,p_vigencia_fim date,p_observacoes text,
  p_id_arquivo uuid,p_chave_idempotencia text
) returns jsonb
language sql security invoker set search_path=''
as $$ select privado.criar_documento_contrato_v111($1,$2,$3,$4,$5,$6,$7,$8,$9) $$;
revoke all on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) from public,anon;
grant execute on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text) to authenticated;
comment on function public.criar_documento_contrato_completo(uuid,text,text,text,date,date,text,uuid,text)
  is 'V1-CON-001/V1-10: cria documento-base com categoria, vigência, observações, versão, processamento, auditoria e idempotência.';
commit;
