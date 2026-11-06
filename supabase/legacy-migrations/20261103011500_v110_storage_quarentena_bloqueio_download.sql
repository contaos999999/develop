-- ContaOS 4.1 — V1-10 / Prompt 31
-- Correção mínima de segurança: o catálogo de metadados continua visível sob RLS,
-- mas o objeto físico não pode ser lido/assinado quando estiver em quarentena ou bloqueado.
begin;

alter policy contaos_storage_select
on storage.objects
using (
  bucket_id = 'contaos-documentos'
  and exists (
    select 1
      from public.arquivos a
     where a.bucket = storage.objects.bucket_id
       and a.path = storage.objects.name
       and a.status_seguranca not in ('quarentena','bloqueado')
       and (
         (a.id_contrato is null and privado.usuario_tem_acesso_organizacao(a.id_organizacao))
         or
         (a.id_contrato is not null and privado.usuario_tem_acesso_contrato(a.id_contrato))
       )
  )
);

comment on policy contaos_storage_select on storage.objects is
'ContaOS V1-10: leitura privada somente para objetos autorizados e fora de quarentena/bloqueio; metadados permanecem visíveis em public.arquivos.';

commit;
