-- ContaOS 4.1 — V1-CON-002/V1-CON-005
begin;
drop trigger if exists v111_validar_fonte_vigencia_regra_assistida on public.regras_conformidade;
create trigger v111_validar_fonte_vigencia_regra_assistida
before insert or update on public.regras_conformidade
for each row execute function privado.v111_validar_fonte_vigencia_regra_assistida();
comment on function public.definir_vigencia_sugestao_extracao(uuid,date,date)
  is 'V1-CON-002: define e audita a vigência temporal da sugestão antes da revisão humana.';
commit;
