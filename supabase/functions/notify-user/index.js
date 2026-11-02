import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'

const URL = Deno.env.get('SUPABASE_URL')
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const sb = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } })

class AppError extends Error { constructor(codigo, mensagem) { super(mensagem); this.codigo = codigo } }
function respostaErro(codigo, mensagem, orientacao = null) { return { ok: false, codigo, titulo: 'Não foi possível concluir', mensagem, orientacao } }
function dataBrasilia(d = new Date()) { return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d) }
function somarDias(dataIso, dias) { const d = new Date(`${dataIso}T12:00:00-03:00`); d.setDate(d.getDate() + dias); return dataBrasilia(d) }
function uuidSeguro(valor, campo = 'identificador') {
  const texto = String(valor ?? '').trim().toLowerCase()
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(texto)) throw new AppError('DADOS_INVALIDOS', `O ${campo} informado não possui um formato válido.`)
  return texto
}
function dataIsoSegura(valor) {
  const texto = String(valor ?? '').trim()
  if (!/^\d{4}-\d{2}-\d{2}$/.test(texto)) throw new AppError('DADOS_INVALIDOS', 'A data de referência informada não possui um formato válido.')
  const data = new Date(`${texto}T12:00:00-03:00`)
  if (Number.isNaN(data.getTime()) || dataBrasilia(data) !== texto) throw new AppError('DADOS_INVALIDOS', 'A data de referência informada não é válida.')
  return texto
}
const ordemCriticidade = { baixa: 1, media: 2, alta: 3, critica: 4 }

async function processarNotificacao(payload) {
  const idUsuario = payload.id_usuario ?? payload.entidade_id
  if (!idUsuario) return { enviadas: 0, falhas: 0 }
  const { data: notas, error } = await sb.from('notificacoes').select('*').eq('id_usuario', idUsuario).eq('status', 'pendente').order('criado_em').limit(50)
  if (error) throw new AppError('NOTIFICACAO_FALHOU', error.message)
  let enviadas = 0, falhas = 0
  for (const nota of notas ?? []) {
    if (nota.canal === 'in_app') {
      await sb.from('notificacoes').update({ status: 'enviada', enviada_em: new Date().toISOString(), erro: null }).eq('id', nota.id); enviadas++
    } else {
      await sb.from('notificacoes').update({ status: 'falhou', erro: 'O envio por e-mail ainda não está configurado neste ambiente. A notificação permanece disponível dentro do ContaOS.' }).eq('id', nota.id); falhas++
    }
  }
  return { enviadas, falhas }
}

async function obterCompetencia(idContrato, dataRef) {
  const { data } = await sb.from('competencias').select('id').eq('id_contrato', idContrato).lte('periodo_inicio', dataRef).gte('periodo_fim', dataRef).not('situacao', 'in', '(encerrada,cancelada)').order('competencia_referencia', { ascending: false }).limit(1).maybeSingle()
  return data?.id ?? null
}

async function versaoControleAtual(idControle, dataRef) {
  const dataReferencia = dataIsoSegura(dataRef)
  const { data, error } = await sb.from('versoes_controle').select('*').eq('id_controle', idControle).eq('status', 'publicada').order('versao', { ascending: false })
  if (error) throw new AppError('CONTROLE_FALHOU', error.message)
  return (data ?? []).find((versao) => {
    const inicio = versao.vigencia_inicio ? String(versao.vigencia_inicio).slice(0, 10) : null
    const fim = versao.vigencia_fim ? String(versao.vigencia_fim).slice(0, 10) : null
    return (!inicio || inicio <= dataReferencia) && (!fim || fim >= dataReferencia)
  }) ?? null
}

async function excecaoAtiva(idControle, idContrato, dataRef) {
  const { data } = await sb.from('excecoes_controle').select('id,escopo,motivo').eq('id_controle', idControle).eq('status', 'aprovada').lte('inicio', dataRef).gte('fim', dataRef)
  for (const ex of data ?? []) {
    const escopo = ex.escopo ?? {}
    if (!escopo.id_contrato || escopo.id_contrato === idContrato) return ex
  }
  return null
}

async function contarTransacoes(idContrato, dataFim, dias, filtros = {}) {
  const d = new Date(`${dataFim}T12:00:00-03:00`); d.setDate(d.getDate() - Math.max(dias - 1, 0)); const inicio = dataBrasilia(d)
  let q = sb.from('transacoes_financeiras').select('id', { count: 'exact', head: true }).eq('id_contrato', idContrato).gte('data', inicio).lte('data', dataFim)
  if (filtros.tipo) q = q.eq('tipo', filtros.tipo)
  const { count, error } = await q
  if (error) throw new AppError('CONTROLE_FALHOU', error.message)
  return { count: count ?? 0, inicio }
}

async function avaliarAplicabilidade(aplicabilidade, controle, versao, transacao, idContrato, dataRef, eventoId) {
  const cfg = { ...(versao.criterios ?? {}), ...(aplicabilidade.configuracao ?? {}) }
  const excecao = await excecaoAtiva(controle.id, idContrato, dataRef)
  let resultado = 'conforme'
  const motivos = []
  const evidencias = []

  if (excecao) {
    resultado = 'nao_aplicavel'
    motivos.push(`Existe uma exceção aprovada e vigente: ${excecao.motivo}`)
    evidencias.push({ tipo: 'excecao_controle', id: excecao.id })
  } else {
    if (transacao) {
      const valorAbs = Math.abs(Number(transacao.valor ?? 0))
      if (cfg.valor_maximo != null && valorAbs > Number(cfg.valor_maximo)) motivos.push(`O valor de R$ ${valorAbs.toLocaleString('pt-BR', { minimumFractionDigits: 2 })} ultrapassa o limite configurado de R$ ${Number(cfg.valor_maximo).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}.`)
      if (cfg.valor_minimo != null && valorAbs < Number(cfg.valor_minimo)) motivos.push(`O valor está abaixo do mínimo configurado para este controle.`)
      const tiposBloqueados = Array.isArray(cfg.tipos_despesa_bloqueados) ? cfg.tipos_despesa_bloqueados.map(String) : []
      if (tiposBloqueados.includes(String(transacao.tipo))) motivos.push(`O tipo de despesa “${transacao.tipo}” está configurado para revisão obrigatória.`)
      evidencias.push({ tipo: 'transacao_financeira', id: transacao.id, data: transacao.data, valor: transacao.valor, descricao: transacao.descricao })
    }
    if (cfg.frequencia_maxima != null) {
      const janela = await contarTransacoes(idContrato, dataRef, Number(cfg.dias_periodo ?? 30), { tipo: cfg.tipo_despesa ?? undefined })
      if (janela.count > Number(cfg.frequencia_maxima)) motivos.push(`Foram identificadas ${janela.count} ocorrências no período, acima do limite de ${cfg.frequencia_maxima}.`)
      evidencias.push({ tipo: 'frequencia', quantidade: janela.count, periodo_inicio: janela.inicio, periodo_fim: dataRef })
    }
    if (cfg.criticidade_minima) {
      const { data: contrato } = await sb.from('contratos').select('criticidade').eq('id', idContrato).single()
      if ((ordemCriticidade[contrato?.criticidade] ?? 0) >= (ordemCriticidade[cfg.criticidade_minima] ?? 99)) motivos.push(`A criticidade do contrato (${contrato?.criticidade}) exige tratamento por este controle.`)
      evidencias.push({ tipo: 'criticidade_contrato', valor: contrato?.criticidade ?? null })
    }
    if (motivos.length) resultado = 'nao_conforme'
  }

  const idCompetencia = await obterCompetencia(idContrato, dataRef)
  const chave = `controle:${controle.id}:${idContrato}:${eventoId ?? dataRef}`
  const { data: existente } = await sb.from('execucoes_controle').select('id').eq('id_organizacao', controle.id_organizacao).eq('chave_idempotencia', chave).maybeSingle()
  if (existente) return { controle: controle.codigo, resultado: 'ja_executado', id_execucao: existente.id }

  const { data: exec, error: erroExec } = await sb.from('execucoes_controle').insert({
    id_organizacao: controle.id_organizacao, id_contrato: idContrato, id_competencia: idCompetencia,
    id_controle_versao: versao.id, escopo: { id_contrato: idContrato }, periodo_inicio: dataRef, periodo_fim: dataRef,
    resultado, evidencias, executado_por: null, evento: transacao ? 'transacao_financeira' : 'cron_diario', evento_id: eventoId ?? null,
    chave_idempotencia: chave,
  }).select('id').single()
  if (erroExec || !exec) throw new AppError('CONTROLE_FALHOU', erroExec?.message ?? 'Falha ao registrar execução do controle.')

  let idNaoConformidade = null
  if (resultado === 'nao_conforme') {
    const responsavel = aplicabilidade.responsavel ?? controle.responsavel_padrao ?? null
    const prazoDias = Math.max(Number(cfg.prazo_dias ?? 5), 1)
    const { data: nc, error: erroNc } = await sb.from('nao_conformidades').insert({
      id_organizacao: controle.id_organizacao, id_controle: controle.id, id_execucao_controle: exec.id,
      id_contrato: idContrato, id_competencia: idCompetencia,
      descricao: `Falha no controle ${controle.codigo} - ${controle.nome}. ${motivos.join(' ')}`,
      risco: motivos.join(' '), severidade: controle.criticidade, status: 'aberta', responsavel,
      prazo: somarDias(dataRef, prazoDias), criado_por: null,
      origem_evento: transacao ? 'transacao_financeira' : 'cron_diario', origem_evento_id: eventoId ?? null,
    }).select('id').single()
    if (erroNc && !String(erroNc.message).includes('duplicate key')) throw new AppError('CONTROLE_FALHOU', erroNc.message)
    idNaoConformidade = nc?.id ?? null
    if (responsavel) {
      await sb.from('notificacoes').insert({ id_organizacao: controle.id_organizacao, id_usuario: responsavel, evento: 'nao_conformidade_aberta', titulo: 'Nova não conformidade para análise', mensagem: `O controle ${controle.codigo} identificou um ponto que precisa de tratamento.`, canal: 'in_app', status: 'enviada', entidade_tipo: 'nao_conformidade', entidade_id: idNaoConformidade, enviada_em: new Date().toISOString() })
    }
  }
  return { controle: controle.codigo, resultado, motivos, id_execucao: exec.id, id_nao_conformidade: idNaoConformidade }
}

async function processarControles(payload) {
  const idTransacao = payload.id_transacao ?? (payload.entidade_tipo === 'avaliar_controles' ? payload.entidade_id : null)
  let transacao = null, idContrato = payload.id_contrato ?? null, dataRef = payload.data_referencia ?? dataBrasilia(), eventoId = null
  if (idTransacao) {
    const { data, error } = await sb.from('transacoes_financeiras').select('*').eq('id', idTransacao).single()
    if (error || !data) throw new AppError('CONTROLE_FALHOU', 'A transação financeira não foi encontrada para avaliação.')
    transacao = data; idContrato = data.id_contrato; dataRef = data.data; eventoId = data.id
  }
  if (!idContrato) throw new AppError('CONTROLE_FALHOU', 'Contrato não informado para avaliação dos controles.')
  idContrato = uuidSeguro(idContrato, 'contrato')
  dataRef = dataIsoSegura(dataRef)

  let qEspecifica = sb.from('aplicabilidades_controle').select('*').eq('ativo', true).eq('id_contrato', idContrato)
  let qGlobal = sb.from('aplicabilidades_controle').select('*').eq('ativo', true).is('id_contrato', null)
  if (payload.id_controle) {
    const idControle = uuidSeguro(payload.id_controle, 'controle')
    qEspecifica = qEspecifica.eq('id_controle', idControle)
    qGlobal = qGlobal.eq('id_controle', idControle)
  }
  const [especificas, globais] = await Promise.all([qEspecifica, qGlobal])
  if (especificas.error || globais.error) throw new AppError('CONTROLE_FALHOU', especificas.error?.message ?? globais.error?.message ?? 'Falha ao consultar aplicabilidades de controle.')
  const aplicabilidades = [...(especificas.data ?? []), ...(globais.data ?? [])]
  const resultados = []
  for (const app of aplicabilidades) {
    const { data: controle } = await sb.from('controles_conformidade').select('*').eq('id', app.id_controle).eq('situacao', 'ativo').maybeSingle()
    if (!controle) continue
    const versao = await versaoControleAtual(controle.id, dataRef); if (!versao) continue
    const gatilhos = versao.eventos_gatilho ?? []
    const gatilhoAtual = transacao ? 'transacao_financeira' : 'cron_diario'
    if (gatilhos.length && !gatilhos.includes(gatilhoAtual)) continue
    resultados.push(await avaliarAplicabilidade(app, controle, versao, transacao, idContrato, dataRef, eventoId))
  }
  return { contrato: idContrato, data_referencia: dataRef, controles_avaliados: resultados.length, resultados }
}

async function processarImpactoNormativo(payload) {
  const idAlteracao = payload.id_alteracao ?? payload.entidade_id
  const { data: alteracao, error } = await sb.from('alteracoes_normativas').select('*').eq('id', idAlteracao).single()
  if (error || !alteracao) throw new AppError('IMPACTO_NORMATIVO_FALHOU', 'A alteração normativa não foi encontrada.')
  const { data: existente } = await sb.from('avaliacoes_impacto').select('id').eq('id_alteracao', idAlteracao).eq('status', 'pendente_aprovacao').maybeSingle()
  if (existente) return { id_avaliacao: existente.id, mensagem: 'Já existe uma avaliação de impacto aguardando revisão humana.' }

  let contratos = []
  if (alteracao.id_versao_nova) {
    const { data: apps } = await sb.from('aplicabilidades_fonte').select('id_contrato').eq('id_fonte_versao', alteracao.id_versao_nova).eq('aplicavel', true)
    contratos = [...new Set((apps ?? []).map((x) => x.id_contrato).filter(Boolean))]
  }
  if (!contratos.length && alteracao.id_fonte) {
    const { data: fonte } = await sb.from('fontes_normativas').select('id_contrato').eq('id', alteracao.id_fonte).maybeSingle()
    if (fonte?.id_contrato) contratos = [fonte.id_contrato]
  }

  const { data: controles } = await sb.from('controles_conformidade').select('id,codigo,nome').eq('id_organizacao', alteracao.id_organizacao).eq('situacao', 'ativo')
  const controlesAfetados = []
  for (const controle of controles ?? []) {
    const versao = await versaoControleAtual(controle.id, dataBrasilia())
    const fontes = Array.isArray(versao?.criterios?.fontes_normativas) ? versao.criterios.fontes_normativas.map(String) : []
    if (alteracao.id_fonte && fontes.includes(String(alteracao.id_fonte))) controlesAfetados.push(controle.id)
  }

  const impacto = contratos.length || controlesAfetados.length
    ? `A alteração pode afetar ${contratos.length} contrato(s) e ${controlesAfetados.length} controle(s). A confirmação exige revisão humana antes de qualquer publicação.`
    : 'Não foram identificadas vinculações diretas suficientes para concluir o impacto automaticamente. A alteração permanece pendente de revisão humana.'
  const { data: avaliacao, error: erroAvaliacao } = await sb.from('avaliacoes_impacto').insert({
    id_organizacao: alteracao.id_organizacao, id_alteracao: alteracao.id, contratos_afetados: contratos,
    controles_afetados: controlesAfetados, impacto, decisao: 'aguarda_revisao_humana', status: 'pendente_aprovacao',
    criado_por: null, metadados: { origem: 'comparacao_automatica', idioma: 'pt-BR', conclusao_automatica: false, data_referencia: dataBrasilia() },
  }).select('id').single()
  if (erroAvaliacao || !avaliacao) throw new AppError('IMPACTO_NORMATIVO_FALHOU', erroAvaliacao?.message ?? 'Falha ao registrar avaliação de impacto.')
  return { id_avaliacao: avaliacao.id, contratos_afetados: contratos.length, controles_afetados: controlesAfetados.length, mensagem: impacto }
}

async function executar(payload) {
  const tipo = payload.entidade_tipo
  if (tipo === 'notificacao' || payload.id_usuario) return await processarNotificacao(payload)
  if (tipo === 'avaliar_controles' || tipo === 'avaliar_controles_periodicos' || payload.id_transacao || payload.id_controle) return await processarControles(payload)
  if (tipo === 'avaliacao_impacto_normativo' || payload.id_alteracao) return await processarImpactoNormativo(payload)
  return { mensagem: 'Nenhuma ação de integração foi necessária para este evento.' }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, codigo: 'METODO_INVALIDO', titulo: 'Ação não permitida', mensagem: 'Este processador aceita somente chamadas internas do ContaOS.' }, { status: 405 })
  const token = req.headers.get('x-contaos-internal-token') ?? ''; const { data: valido } = await sb.rpc('validar_token_interno', { p_token: token })
  if (valido !== true) return Response.json({ ok: false, codigo: 'AUTH_ACESSO_NEGADO', titulo: 'Acesso não permitido', mensagem: 'Esta operação interna não está autorizada.' }, { status: 401 })
  let body = {}; try { body = await req.json() } catch {}
  const maxJobs = Math.min(Math.max(Number(body.max_jobs ?? 5), 1), 10); const resultados = []
  for (let i = 0; i < maxJobs; i++) {
    const { data: job, error } = await sb.rpc('worker_pull_job', { p_fila: 'integrations', p_visibility_seconds: 180 })
    if (error) return Response.json(respostaErro('INTEGRACAO_INDISPONIVEL', 'O processamento de integrações está temporariamente indisponível.', 'O ContaOS tentará novamente automaticamente.'), { status: 500 })
    if (!job) break
    try {
      const resultado = await executar(job.payload ?? {}); await sb.rpc('worker_finalizar_job', { p_fila: 'integrations', p_msg_id: Number(job.msg_id), p_sucesso: true, p_erro_codigo: null, p_erro_detalhe: null, p_max_tentativas: 5 }); resultados.push({ ok: true, msg_id: job.msg_id, resultado })
    } catch (erro) {
      const app = erro instanceof AppError ? erro : new AppError('INTEGRACAO_INDISPONIVEL', String(erro)); await sb.rpc('worker_finalizar_job', { p_fila: 'integrations', p_msg_id: Number(job.msg_id), p_sucesso: false, p_erro_codigo: app.codigo, p_erro_detalhe: app.message, p_max_tentativas: 5 }); resultados.push({ ok: false, msg_id: job.msg_id, codigo: app.codigo, titulo: 'Processamento não concluído', mensagem: 'Esta tarefa não foi concluída nesta tentativa.', orientacao: 'O ContaOS fará nova tentativa automaticamente.' })
    }
  }
  return Response.json({ ok: true, fila: 'integrations', processados: resultados.length, resultados }, { headers: { 'content-type': 'application/json; charset=utf-8' } })
})