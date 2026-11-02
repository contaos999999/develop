create or replace function privado.auditar_contratante_criado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform privado.registrar_evento_auditoria(
    new.id_organizacao,
    'ContratanteCriado',
    'contratantes',
    new.id,
    null,
    jsonb_build_object(
      'tipo_pessoa', new.tipo_pessoa,
      'razao_social', new.razao_social,
      'nome_fantasia', new.nome_fantasia,
      'situacao', new.situacao
    ),
    jsonb_build_object('versao_registro', new.versao_registro)
  );
  return new;
end;
$$;

revoke all on function privado.auditar_contratante_criado() from public, anon, authenticated;

create trigger contratantes_auditoria_insert
after insert on public.contratantes
for each row execute function privado.auditar_contratante_criado();
