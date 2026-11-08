# Fence: barreira entre prova documental e scripts concorrentes

Base: `87c18599fc72d658dabcf1b07a534b42b08691fd`. Autorização expressa do titular: diagnosticar e corrigir a fence antes de repetir as cinco provas.

Run anterior `42482714141`, artifact `13618595331`, SHA256 `6411d21d820d9eac37bf2fda57c4e302504e5d7c0fc5d359cb18385218492103`: FAIL após login, Script/OWN/200, sem hash divergente ou erro CDP registrado. Preservar falha e quarentena do nonce c9a64d65f92d435aa2c102a220e25ffc. Não reutilizar fixtures anteriores.

## Plano delimitado

Investigar o handler assíncrono real. Reproduzir, sem credenciais, Script recebido enquanto uma nova prova Document está pendente. Distinguir defeito reproduzido de causa do incidente ainda não classificada. TDD deve exigir retenção da resposta Script até prova completa e recusa em falha, fechamento, hash divergente e script não inspecionado. Nenhum continue antes da prova, nenhuma alteração de bytes ou CORS. Incluir caso Chromium no public-probe existente, sem workflow novo.

Somente quatro caminhos declarados no manifesto: tarefa, este documento, browser harness e protocolo. Material suspenso por fase própria, sem Auth/fixtures/HML/DDL/Edges/frontend317/PROD. Após implementação: suíte Node completa, dez guards, revisão independente, CI guard/public-probe/Restore/rebuild/backup no mesmo HEAD. Não liberar as cinco provas por testes VM; nova retomada normativa após esses gates.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: impacto_visual N/A, somente harness técnico sem frontend; ferramentas GitHub e testes existentes, menor delta, sem Lovable. Preservar SDK real, hashes, barreiras preventivas, redirects/popups/workers, cleanup e recibos separados. Nenhum PASS CRUD/V1/V2.

## Evidência local desta execução

O novo teste executa o handler `paused` extraído literalmente do harness. RED: Script válido foi abortado durante prova Document pendente (1 chamada terminal onde deveria haver zero). GREEN: seis cenários, mantendo script retido até conclusão: válido, prova rejeitada, bytes alterados, módulo não inspecionado, falha tardia e fechamento tardio. Suíte completa Node: 344/344, zero skip; dez guards e diff PASS.

Correção: substituir flag de inspeção por promessa de barreira; Script aguarda a mesma prova antes de validar hash/continuar. Falha de prova rejeita ambos; latch é conferido antes de contar script validado. Assertions Node agora recebem código FENCE sanitizado em vez de desaparecerem no código genérico ERR_ASSERTION. Sobreposição de documentos continua negada. Nenhum header/body do produto é modificado.

Esse mecanismo de concorrência está reproduzido; o artefato anterior não permite atribuir definitivamente a causa do incidente a ele. Foram acrescentados três casos Chromium sem credenciais no probe existente (válido, alterado, prova rejeitada), com documento iframe pausado e script concorrente. Chromium local falhou antes do teste por socket EPERM do ambiente; nenhuma prova nativa local declarada. CI e revisão independente ainda pendentes.

Revisão técnica independente reexecutou 74/74 testes do protocolo, sem Critical/Important. Minor de evidência corrigido: fixture agora registra efeito HTTP realmente observado em /concurrent-executed, exige 1 positivo e 0 negativos após fechar contexto/drenar TCP, e exige códigos FENCE exatos nas duas negativas. Leitura normativa independente e CI nativo continuam pendentes; parecer técnico parcial não libera integração.
