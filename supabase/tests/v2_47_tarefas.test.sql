\set QUIET on
begin;
set local role authenticated;
select set_config('contaos.fixture.ator','47000000-0000-4000-8000-000000000001',true);
do $$
begin
  perform public.salvar_tarefa_diligencia_v2(
    '47000000-0000-4000-8000-000000000101'::uuid,
    '47000000-0000-4000-8000-000000000201'::uuid,
    null::uuid, null::bigint,
    '{"descricao":"Conferir comprovante","responsavel":"47000000-0000-4000-8000-000000000002","prazo":"2026-12-05","tipo_acao":"corrigir_documento","prioridade":"alta","depende_de":[]}'::jsonb,
    'red-diligencia-47'::text
  );
exception
  when undefined_function then
    raise exception 'V2_47_RED: falta a operação autenticada que vincula tarefa, apontamento e rodada';
end
$$;
rollback;
