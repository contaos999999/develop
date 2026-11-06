begin;

-- Defesa em profundidade contra Mass Assignment/BOPLA em estados de workflow.
-- RLS controla as linhas, mas não impede que um cliente autorizado altere
-- diretamente propriedades críticas da mesma linha. Transições protegidas
-- devem ocorrer pelas RPCs oficiais, que aplicam evidências, segregação,
-- versionamento, fundamento e auditoria.

create or replace function privado.bloquear_mutacao_workflow_critico()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_antigo jsonb := to_jsonb(old);
  v_novo jsonb := to_jsonb(new);
  v_campo text;
begin
  -- Workers, service_role e funções SECURITY DEFINER continuam aptos a executar
  -- as transições oficiais. A barreira é voltada ao Data API do usuário final.
  if current_user <> 'authenticated' then
    return new;
  end if;

  case tg_table_name
    when 'planos_remediacao' then
      -- concluir_plano_remediacao() e validar_remediacao() são os únicos
      -- caminhos autorizados para entrada/saída dos estados protegidos.
      if (v_novo ->> 'status') is distinct from (v_antigo ->> 'status')
         and (
           (v_novo ->> 'status') in ('concluido', 'validado')
           or (v_antigo ->> 'status') in ('concluido', 'validado')
         ) then
        raise exception using
          errcode = '42501',
          message = 'Esta mudança de status precisa ser feita pela operação oficial de remediação.',
          detail = 'Estados concluído e validado exigem as verificações de evidência, perfil e segregação de funções do ContaOS.',
          hint = 'Use as ações Concluir remediação ou Validar remediação.';
      end if;

      foreach v_campo in array array['concluido_por','concluido_em','validado_por','validado_em']::text[]
      loop
        if (v_novo -> v_campo) is distinct from (v_antigo -> v_campo) then
          raise exception using
            errcode = '42501',
            message = 'Os dados de conclusão e validação são preenchidos automaticamente pelo ContaOS.',
            detail = format('O campo %s não pode ser alterado diretamente.', v_campo),
            hint = 'Use a operação oficial correspondente.';
        end if;
      end loop;

      -- Evidências de uma remediação já concluída/validada não podem ser
      -- reescritas diretamente após a decisão auditável.
      if (v_antigo ->> 'status') in ('concluido', 'validado')
         and (v_novo -> 'evidencias') is distinct from (v_antigo -> 'evidencias') then
        raise exception using
          errcode = '42501',
          message = 'As evidências desta remediação já estão vinculadas a uma etapa concluída.',
          detail = 'Não é permitido reescrever evidências após conclusão ou validação por atualização direta.',
          hint = 'Use o fluxo oficial de remediação para qualquer nova decisão.';
      end if;

    when 'nao_conformidades' then
      -- Estes estados são derivados das RPCs de remediação/encerramento.
      if (v_novo ->> 'status') is distinct from (v_antigo ->> 'status')
         and (
           (v_novo ->> 'status') in ('em_remediacao', 'resolvida', 'encerrada')
           or (v_antigo ->> 'status') in ('em_remediacao', 'resolvida', 'encerrada')
         ) then
        raise exception using
          errcode = '42501',
          message = 'Esta mudança de status da não conformidade precisa seguir o fluxo oficial.',
          detail = 'Remediação, resolução e encerramento dependem das validações e evidências previstas pelo ContaOS.',
          hint = 'Use as operações oficiais de remediação, validação ou encerramento.';
      end if;

    when 'controles_conformidade' then
      -- publicar_controle() cria versão, hash, aprovador e auditoria antes de ativar.
      if (v_novo -> 'versao_atual') is distinct from (v_antigo -> 'versao_atual') then
        raise exception using
          errcode = '42501',
          message = 'A versão atual do controle é gerenciada automaticamente pelo ContaOS.',
          detail = 'versao_atual não pode ser alterada diretamente.',
          hint = 'Use a operação Publicar controle.';
      end if;

      if (v_novo ->> 'situacao') is distinct from (v_antigo ->> 'situacao')
         and (v_novo ->> 'situacao') = 'ativo' then
        raise exception using
          errcode = '42501',
          message = 'Um controle só pode ser ativado por meio da publicação oficial.',
          detail = 'A publicação cria a versão imutável, o hash, o aprovador e o registro de auditoria.',
          hint = 'Use a operação Publicar controle.';
      end if;

    when 'usuarios' then
      -- A policy de perfil permite ao usuário editar a própria linha. A situação
      -- da conta não é dado de perfil e não pode ser autoalterada pelo cliente.
      if (v_novo ->> 'situacao') is distinct from (v_antigo ->> 'situacao') then
        raise exception using
          errcode = '42501',
          message = 'A situação da conta não pode ser alterada pelo próprio usuário.',
          detail = 'Ativação e inativação são operações administrativas do ContaOS.',
          hint = 'Solicite a alteração a um administrador autorizado.';
      end if;
  end case;

  return new;
end;
$$;

revoke all on function privado.bloquear_mutacao_workflow_critico() from public, anon, authenticated;
grant execute on function privado.bloquear_mutacao_workflow_critico() to service_role;

-- Triggers explícitos, independentes do frontend.
drop trigger if exists trg_bopla_workflow_planos_remediacao on public.planos_remediacao;
create trigger trg_bopla_workflow_planos_remediacao
before update on public.planos_remediacao
for each row execute function privado.bloquear_mutacao_workflow_critico();

drop trigger if exists trg_bopla_workflow_nao_conformidades on public.nao_conformidades;
create trigger trg_bopla_workflow_nao_conformidades
before update on public.nao_conformidades
for each row execute function privado.bloquear_mutacao_workflow_critico();

drop trigger if exists trg_bopla_workflow_controles_conformidade on public.controles_conformidade;
create trigger trg_bopla_workflow_controles_conformidade
before update on public.controles_conformidade
for each row execute function privado.bloquear_mutacao_workflow_critico();

drop trigger if exists trg_bopla_workflow_usuarios on public.usuarios;
create trigger trg_bopla_workflow_usuarios
before update on public.usuarios
for each row execute function privado.bloquear_mutacao_workflow_critico();

commit;
