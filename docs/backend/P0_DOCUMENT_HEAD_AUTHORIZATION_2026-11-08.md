# Retomada documental vinculada ao HEAD

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A; nenhum frontend, Lovable ou PROD.

Base integrada: 2d01d87654ce580f6f8fdd3446ea4aa78ac7752a, correção da fence no PR166. Fontes canônicas conferidas sem mudança em relação à leitura integral anterior.

O runner documental estava suspenso pela fase BUILD_FENCE_DOCUMENT_BARRIER. O workflow histórico de cadastros tem outro escopo e não executa o lote documental; seu skip não comprova falha do produto nem justifica reaplicar migrations antigas.

A autorização material passa a exigir manifesto explícito para tarefa, fase, projeto HML, nonce próprio e lista exata de checks. O SHA vem do Restore push de main, precisa coincidir com checkout, main vivo e checks guard/restore/backup SUCCESS. Não há SHA histórico fixado nem dispensa de checks. A paridade de versões compara todos os arquivos de migrations com todas as linhas HML antes de criar Auth fixtures, rejeitando divergência e duplicatas. Isso comprova versões; permissões/catálogos continuam dependendo das provas SQL existentes e recibos efetivamente executados.

Sequência: revisão independente e CI deste HEAD; merge normal CAS; Restore no merge; runner com TXT publicado primeiro e quatro provas locais, cinco arquivos/três documentos/cinco versões; JWT/RLS, quarentena/cleanup e recibos independentes; inspeção dos artefatos e checkpoint. Falhas exigem correção e nova prova, sem converter skip em PASS. Nenhuma certificação CRUD/V1 antecipada, nenhuma V2.

RED observado: novo teste de autorização falhou por ausência da validação. GREEN protocolo75/75 antes da inclusão dos nove casos executáveis de autorização. Evidências finais de CI e lote ainda pendentes.

## Falha material e correção do harness

Run42499476089 no merge9c35f6f6 falhou após cinco uploads. Artifact13624619281 baixado/conferido SHA2563c7eb23dafc7b5aca6dd6bc596a5857ad9c00cf5b892c3ff4a710d65bdf003be. Publicado PASS_SMOKE primeiro; quatro uploads/worker/downloads locais e hashes PASS. Isolamento final ainda não executado. Cleanup próprio nonce7a98911bd10743a09536af3cb684b86b:4contas/2organizações,5objetos/5arquivos preservados por retenção,0jobsativos,2cancelados.

A UI mantém rascunho e filtro aplicado separados e exige botão Aplicar filtros. O harness apenas preenchia o rascunho e esperava2linhas, mantendo3documentos visíveis. Correção apenas harness: preencher e submeter formulário exato, marcar etapas de reload/filtro/contagem/axe. Fixture Chromium pública sem credenciais reproduz3linhas antes da submissão e2depois. Teste unitário RED por helper inexistente, GREEN exigindo fill antes do submit. Nenhum ajuste de produto, filtro, expectativa, permissão ou timeout. Novo lote completo com nonce novo após revisão/CI obrigatório.

## Independência backend e auditoria visual

Run42500742625/HEAD6121798c/artifact13624574567 SHA256c52ddb36bccbdc435d9f46545759bef0251208d9e884feba828d278757ebe140: filtro corrigido,5uploads/3docs/5versões e5workersdocuments/AI/embeddings concluídos. FAIL visual1440dark: color-contrast serious3nodes. Light1440/1280/768/390 sem violações automatizadas. Não certificar temaescuro ou WCAG; frontend intocável nesta trilha.

O harness passa a registrar falhas visuais sem interromper as provas posteriores de JWT/RLS. Só admite recibo backend independente após todas as negativas, sessão revogada ainda autenticada, ausência de erros runtime e encerramento seguro. Python confirma SQL/5recibos antes de registrar backend_state específico. Qualquer falha de fence/prova material/incompletude impede esse estado. A falha visual continua explícita, relatório geral FAIL, saída1 e CIvermelho. Não há exclusão de regra axe, skip, tolerância ou conversão para PASS. Nova execução mantém5arquivos e nonce novo. Aprovação global continua tecnicamente bloqueada pela frente visual, sem falta de autorização humana.
