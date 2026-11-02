-- ContaOS 4.1 — hardening detectado durante PROMPT 27 / V1-06
-- Corrige BOLA em RPC SECURITY DEFINER: perfil na organização não substitui
-- o escopo contratual explícito do usuário.

create or replace function privado.aprovar_parecer_interno(
  p_id_parecer uuid,
  p_aprovar boolean,
  p_fundamento text default null::text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.pareceres_internos%rowtype;
begin
  select *
    into v
  from public.pareceres_internos
  where id = p_id_parecer
  for update;

  if v.id is null then
    raise exception 'Não encontramos o parecer informado.';
  end if;

  if auth.uid() is null
     or not privado.usuario_tem_acesso_contrato(v.id_contrato)
     or not privado.usuario_possui_perfil(
       v.id_organizacao,
       array['administrador','direcao_aprovador','gestor_contrato','juridico_conformidade']::text[]
     ) then
    raise sqlstate '42501' using
      message = 'Você não tem permissão para aprovar este parecer.',
      detail = 'A operação exige acesso ao contrato e perfil autorizado na organização.',
      hint = 'Selecione um contrato ao qual seu usuário tenha acesso ou procure um administrador autorizado.';
  end if;

  if v.autor = auth.uid() then
    raise exception 'O parecer deve ser aprovado por uma pessoa diferente de quem o elaborou.';
  end if;

  update public.pareceres_internos
     set status = case when p_aprovar then 'aprovado' else 'rejeitado' end,
         aprovado_por = auth.uid(),
         aprovado_em = now()
   where id = v.id;

  perform privado.registrar_evento_auditoria(
    v.id_organizacao,
    'ParecerInternoRevisado',
    'pareceres_internos',
    v.id,
    null,
    jsonb_build_object('aprovado',p_aprovar,'fundamento',p_fundamento)
  );
end;
$$;
