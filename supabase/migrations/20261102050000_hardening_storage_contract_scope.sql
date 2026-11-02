begin;

-- Uploads de usuários passam exclusivamente por URL assinada gerada pela
-- Edge Function storage-sign-upload após validação de organização/contrato.
drop policy if exists contaos_storage_insert on storage.objects;

-- A leitura direta do Storage precisa corresponder a um arquivo catalogado
-- e respeitar o mesmo escopo organizacional/contratual da tabela public.arquivos.
drop policy if exists contaos_storage_select on storage.objects;
create policy contaos_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contaos-documentos'
  and exists (
    select 1
    from public.arquivos a
    where a.bucket = storage.objects.bucket_id
      and a.path = storage.objects.name
      and (
        (a.id_contrato is null and privado.usuario_tem_acesso_organizacao(a.id_organizacao))
        or
        (a.id_contrato is not null and privado.usuario_tem_acesso_contrato(a.id_contrato))
      )
  )
);

commit;
