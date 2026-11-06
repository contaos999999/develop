begin;

-- A criação de documento de competência precisa passar pela RPC oficial para
-- criar simultaneamente cabeçalho, versão, hash, processamento e auditoria.
revoke insert on table public.documentos_competencia from authenticated;
drop policy if exists documentos_competencia_insert on public.documentos_competencia;

-- Metadados continuam editáveis conforme a policy UPDATE existente, mas o
-- ponteiro versao_atual é propriedade da cadeia de versionamento e não pode
-- ser manipulado diretamente pelo cliente.
create or replace function privado.bloquear_mutacao_versao_atual_documento()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated'
     and new.versao_atual is distinct from old.versao_atual then
    raise exception using
      errcode = '42501',
      message = 'A versão atual do documento é gerenciada automaticamente pelo ContaOS.',
      detail = 'O ponteiro de versão deve corresponder a uma versão criada com arquivo, hash, processamento e auditoria.',
      hint = 'Use a operação oficial de adicionar nova versão do documento.';
  end if;
  return new;
end;
$$;

revoke all on function privado.bloquear_mutacao_versao_atual_documento() from public, anon, authenticated;
grant execute on function privado.bloquear_mutacao_versao_atual_documento() to service_role;

drop trigger if exists trg_bopla_documentos_competencia_versao on public.documentos_competencia;
create trigger trg_bopla_documentos_competencia_versao
before update on public.documentos_competencia
for each row execute function privado.bloquear_mutacao_versao_atual_documento();

commit;
