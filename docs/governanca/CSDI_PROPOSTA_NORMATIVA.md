# Emenda proposta ao protocolo ContaOS 4.1 — Certificação Semântica Definitiva Interna (CSDI)

**Estado:** proposta em PR, não integrada, não vigente. Vinculada ao manifesto `docs/tasks/CSDI_PROTOCOL_CONTEXT_20261121.json` e à PR frontend #692.

## Artigo 1º — Substituição do requisito de auditoria externa

Por determinação expressa do responsável pelo produto, o parecer obrigatório do auditor independente, como requisito para a **certificação semântica**, será substituído pela Certificação Semântica Definitiva Interna (CSDI). A revisão externa poderá ser realizada facultativamente, mas não será condição necessária para o PASS semântico **após a integração e entrada em vigor desta emenda**.

A alteração não dispensa comprovação técnica, contraditório interno, controles de integridade, revisão formal humana que seja exigida por outros gates nem autorizações de ativação.

## Artigo 2º — Etapas não intercambiáveis

1. **Pré-auditoria adversarial:** 12 critérios BUILD V2, 12 lentes, 10 camadas, testes RED/GREEN, mutações, regressões, segurança, proveniência e revogação, com relatórios fundamentados.
2. **Pré-certificação BUILD autenticada:** recibo versionado, emitido para HEAD/base/manifesto imutáveis, validado por consumidor LIVE. O retorno `PRE_CERTIFICATION_ONLY` **não** é certificação semântica.
3. **Certificação Semântica Definitiva Interna:** avaliação exaustiva das cláusulas, subcláusulas, regras, ambiguidades e interações, nos sete eixos semânticos, com provas executadas e segunda leitura crítica interna distinta da elaboração.

## Artigo 3º — Condições cumulativas de PASS semântico

O veredito `SEMANTIC_COMPLETENESS=PASS` exige, no mesmo HEAD/base e versão normativa:
- inventário fechado de todas as cláusulas, regras e átomos normativos;
- cobertura integral com testemunhas de execução, positivas e negativas, para cada regra aplicável;
- todas as interações entre regras adjudicadas ou descartadas com justificativa verificável;
- ambiguidades explicitamente resolvidas e decisões normativas versionadas;
- sete eixos com parecer substantivo e contraprovas;
- vínculo cláusula → interpretação → teste → run/job/attempt → evidência → digest;
- segunda leitura crítica interna com confronto dos resultados, sem autoconcessão;
- recibo `CONTAOS_SEMANTIC_CERTIFICATION_V1`, schema `contaos.semantic-certification.v1`, validado por consumidor LIVE;
- ausência de veto, drift, prova ausente, erro de hash, revogação ou modificação material posterior não revalidada.

Sem qualquer condição acima, o resultado será `INCONCLUSIVE`, `BLOCKED` ou `CHANGES_REQUESTED`, jamais PASS presumido.

## Artigo 4º — Revogação e proveniência

Toda certificação vincula commit HEAD, base, hash do PLAN e das emendas, versão do validador, manifesto, checks, revisões, artefatos, runs, tentativas e digest. Alteração material, expiração de evidência, check inválido ou veto posterior revoga a certificação até nova avaliação. Nenhum PASS histórico migra automaticamente para novo escopo.

## Artigo 5º — Gates preservados

O PASS da CSDI **não autoriza** merge, alteração de branch protection, N17(c), App privilegiado, fila real, HML/RLS, PROD, nem qualquer ativação. Esses gates exigem suas próprias provas e decisões. `ativacao_autorizada=false` permanece até autorização própria.

## Artigo 6º — Transição

Antes da vigência: localizar e identificar por caminho e Git SHA a fonte canônica protegida do PLAN e emendas; confrontar todas as referências ao auditor externo; integrar esta emenda na autoridade normativa correta; implementar o consumidor CSDI e seus testes de aceitação, revogação, segurança e regressão; executar CI e readback. Até então, a regra antiga continua aplicável.

**Estado atual:** `BUILD_V2_PRECERT=PASS_AUTHENTICATED`; `SEMANTIC_COMPLETENESS=INCONCLUSIVE`; `CSDI_CONSUMER=NOT_IMPLEMENTED`; `ACTIVATION=NO_GO`.
