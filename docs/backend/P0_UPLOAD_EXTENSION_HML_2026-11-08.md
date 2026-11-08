# Upload HML: PLAN/GATE da extração de extensão, 08/11/2026

Escopo autorizado pelo titular: resolver upload autenticado no HML, com preservação de evidências. Base b8003019fe937c8dad436fae3a0334aee23f2453. V1 continua NO-GO global; nenhuma promoção PROD.

## Evidência e causa

PR145 integrado após Node319/319, guard42449646955 e restore42449952690 (reconstrução e backup SUCCESS). Deploy HML upload8/download6 JWTtrue; fontes exatos do merge. SHA256 upload f1653f2de4e7300f3e75c3427819c721a6453bfdd6f83f41af9475c33774f97c, download538f3a014316e05f44ecd47f113080ee6ab00a2aaad1b2cf3bf6c76b7c1cda9a. OPTIONS Vercel204/ACAOexato; origem maliciosa403/semACAO; POSTsemJWT401 gateway. Gateway emite ACAO* na própria recusa401, sem alteração nossa.

Reteste autenticado 05:17UTC, contrato sintético be89ef7e-d839-46c0-9cfb-4da81edf8b74: assinatura200, objeto recebido no Storage, confirmar_upload_arquivo400/P0001. Log PostgreSQL linha25: Este formato de arquivo não é aceito pelo ContaOS. Configuração aceita txt/text/plain. Consulta sem mutação reproduziu extração atual como nome completo, em vez de txt. Expressão regexp tem escape excessivo; histórico permanece intacto.

## BUILD fechado

Somente nova migration 20261108053000_fix_upload_extension_extraction.sql substitui a expressão de extração por ponto literal em classe [.] na função privado.confirmar_upload_arquivo, preservando corpo restante, assinatura, SECURITY DEFINER/search_path, RBAC, sessão, organização/contrato, path, MIME/extensão, limites, SHA256, metadados reais, inserção, auditoria e grants. Não reescrever migrations antigas. Nenhuma alteração Edge/Auth/Storage/RLS/frontend/workflow/SDK/segredo/PROD. Manifesto mantém histórico e abre os cinco caminhos declarados apenas no BUILD separado após integração deste GATE.

## Provas e execução

TDD SQL real em transação descartável: extrair a expressão da função instalada e avaliar nomes TXT/PDF/múltiplos pontos/maiúsculas; rejeitar extensão ausente, executável e sufixo enganoso conforme configuração. Regressão Node compara corpo novo com baseline permitindo somente a linha de extração. Preservar testes atuais e acrescentar SQL em hml_acceptance antes do relatório, executado pelo restore existente. RED antes da migration; GREEN após ela, suíte Node completa, contexto/arquitetura/ZeroDrift/security, guard e restore/reconstrução/backup no mesmoHEAD, revisão independente sem Critical/Important, merge normal. Aplicar somente migration integrada ao projeto gklhhhyosgasnyoxlrui e conferir corpo/grants. Repetir exatamente o TXT já enviado pela UI, sem duplicar Storage, JWT ou sessão exportados, e comprovar persistência/listagem/detalhe.

Rollback por nova migration/PR restaurando a definição anterior da função, sem apagar evidências/objetos ou reescrever histórico. A correção não amplia formatos aceitos nem autoriza limpar dados. Qualquer falha mantém NÃO CONCLUÍDO e exige diagnóstico. Não alegar cobertura232/72, CRUDintegral ou certificaçãoV1 a partir deste caso.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visual N/A, função backend existente; sem turno Lovable; menor delta funcional com testes reais, sem reduzir segurança ou governança.
