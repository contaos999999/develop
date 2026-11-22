# MIGRAÇÃO ADMINISTRATIVA ÚNICA — P0-CERT-LIVE-001

## Decisão, causalidade e escopo
Autorização expressa do titular em 22/11/2026 para bootstrap excepcional e inclusão do workflow. A origem do impasse é que o Zero-Drift antigo rejeita a própria autorização necessária para substituir o controle antigo. O único veículo de integração é a PR #230; PRs #228 e #229 são fontes históricas, não dependências de merge.

## Arquivos e limites
Esta PR consolida, em uma única alteração, PLAN P0, norma de certificação, emenda de prioridade zero, autorização protegida para PR #228, guard, testes e workflow. Não modifica `docs/tasks/active-task.json` (C-CHAT-013), frontend, Supabase, PROD, migrations, credenciais ou dados. A autorização na branch não autoriza a própria PR: apenas o procedimento administrativo excepcional do titular, com revisão independente favorável, permite o merge inicial. O guard ordinário continua FAIL neste PR até a integração; nunca reclassificar esse FAIL como PASS.

## Verificações pré-integração
1. Context Gate PASS no HEAD e testes automatizados de autorização PASS, inclusive negativos.
2. Identificar exatamente os arquivos rejeitados pelo guard antigo e confirmar que correspondem somente ao bootstrap autorizado.
3. Revisão independente favorável de Edivan5002 sobre o HEAD integral consolidado, com confirmação expressa da exceção administrativa.
4. Comprovar que não houve alteração da tarefa ativa e que não existe bypass permanente.
5. Registrar SHA, workflow run, testes, parecer e resultado do merge na PR #230. Qualquer falha não prevista: NO-GO.

## Integração e pós-integração
Somente após o parecer independente favorável, executar uma única integração excepcional da PR #230. Não remover checks, não editar branch protection e não declarar CI antigo aprovado. Em seguida verificar readback dos arquivos na main, HEAD de merge, workflow pós-merge, testes, Context Gate, Zero-Drift e demais verificações. Falha pós-merge exige correção controlada; não liberar certificação nem PROD automaticamente. As PRs #228/#229 devem ser encerradas como substituídas apenas depois de confirmada a integração de seus conteúdos.

## Política de segurança
O manifesto de autorização só pode ser lido de `origin/main`, com SHA do PLAN protegido e ancestralidade; conteúdo presente apenas na branch do PR não constitui autorização. O guard falha fechado. A autorização de PR #228 é histórica e não representa aprovação de qualquer BUILD posterior. Certificações V1–V5 exigem CI e revisão, e LIVE permanece obrigatório no GATE PROD.

**Status inicial:** migração consolidada em PR #230; aguardando provas completas, parecer favorável e integração excepcional única. PROD NO-GO.
