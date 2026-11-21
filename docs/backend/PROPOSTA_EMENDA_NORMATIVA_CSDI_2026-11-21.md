# Emenda normativa CSDI — submissão para aprovação protegida

**Estado: PROPOSTA, NÃO VIGENTE.** Esta submissão não modifica o gate atual nem autoriza ativação. A vigência depende de revisão formal, aprovação, merge protegido e regressão.

## Objeto
Substituir exclusivamente a exigência de parecer externo no gate de certificação semântica pela Certificação Semântica Definitiva Interna (CSDI). A aprovação interna requer provas substanciais executadas e autenticadas, não uma declaração textual ou um recibo de BUILD.

## Critérios cumulativos
1. Congelar commit e SHA-256 de todas as fontes canônicas vigentes, preservar a hierarquia normativa e inventariar exaustivamente cláusulas, subcláusulas, regras, exceções e pares de interação, com reconciliação automatizada contra o corpus original.
2. Executar testes positivos, negativos, adversariais, de mutação, revogação e regressão, com cobertura rastreável de cada item nos sete eixos: literal, sistemático, teleológico, temporal, segurança, operacional e adversarial.
3. Produzir artefatos de CI vinculados a HEAD/base, job, run, tentativa, commit, manifesto, assertivas, logs sanitizados e hashes de conteúdo. Consumidor LIVE deve verificar proveniência e integridade sem confiar em valores autodeclarados.
4. Exigir segunda leitura crítica de todas as divergências e evidências no HEAD final; revisão autenticada, distinta da elaboração inicial, sem aprovação automática.
5. Somente emitir SEMANTIC_COMPLETENESS=PASS quando todos os itens estiverem comprovados e nenhum veto ou ambiguidade permanecer. Toda mudança material invalida o resultado até nova verificação.

## Limites preservados
A CSDI não substitui os gates específicos de N17(c), App privilegiado, fila real, HML/RLS, PROD, branch protection, revisão de PR, CI, Zero-Drift ou autorização de merge. Todos permanecem NO-GO sem prova própria. A ausência de auditor externo não pode ser usada para contornar revisão nativa protegida.

## Plano de integração
Esta PR documental é a primeira etapa da migração. Antes de vigência: confrontar integralmente os documentos canônicos 00–20 e suas referências, concluir declaração de leitura e fingerprint, mapear referências normativas conflitantes, implementar os consumidores e produtores de provas, executar regressões e obter aprovação protegida. Não alterar docs/tasks/active-task.json pertencente a tarefa alheia nem migrations/RLS/Auth/PROD.
