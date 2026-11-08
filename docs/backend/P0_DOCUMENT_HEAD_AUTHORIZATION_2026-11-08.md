# Retomada documental vinculada ao HEAD

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A; nenhum frontend, Lovable ou PROD.

Base integrada: 2d01d87654ce580f6f8fdd3446ea4aa78ac7752a, correção da fence no PR166. Fontes canônicas conferidas sem mudança em relação à leitura integral anterior.

O runner documental estava suspenso pela fase BUILD_FENCE_DOCUMENT_BARRIER. O workflow histórico de cadastros tem outro escopo e não executa o lote documental; seu skip não comprova falha do produto nem justifica reaplicar migrations antigas.

A autorização material passa a exigir manifesto explícito para tarefa, fase, projeto HML, nonce próprio e lista exata de checks. O SHA vem do Restore push de main, precisa coincidir com checkout, main vivo e checks guard/restore/backup SUCCESS. Não há SHA histórico fixado nem dispensa de checks. A paridade de versões compara todos os arquivos de migrations com todas as linhas HML antes de criar Auth fixtures, rejeitando divergência e duplicatas. Isso comprova versões; permissões/catálogos continuam dependendo das provas SQL existentes e recibos efetivamente executados.

Sequência: revisão independente e CI deste HEAD; merge normal CAS; Restore no merge; runner com TXT publicado primeiro e quatro provas locais, cinco arquivos/três documentos/cinco versões; JWT/RLS, quarentena/cleanup e recibos independentes; inspeção dos artefatos e checkpoint. Falhas exigem correção e nova prova, sem converter skip em PASS. Nenhuma certificação CRUD/V1 antecipada, nenhuma V2.

RED observado: novo teste de autorização falhou por ausência da validação. GREEN protocolo75/75 antes da inclusão dos nove casos executáveis de autorização. Evidências finais de CI e lote ainda pendentes.
