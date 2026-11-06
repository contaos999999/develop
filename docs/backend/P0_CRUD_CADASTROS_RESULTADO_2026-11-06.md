# P0 CRUD cadastros: evidência em execução

PLAN #90 integrado em 67970334cd78e668b4fbbb91c5ef416f898a8c77; emenda #92 integrada em 5ef564636fdc4baab25557bf6e316dd99511e989 após guard SUCCESS. BUILD #91 não certifica CRUD global/V1.

## Implementação
Cinco APIs públicas invoker e quatro funções privadas; sessão, RBAC e papel, escopo exato, allowlist de campos, estados conservadores, motivo, versão esperada, idempotência, snapshots e auditoria. Touch dedicado não incrementa a versão e bloqueia UPDATE authenticated direto. Não altera RLS/grants de tabelas, Auth configuração, Edge, Storage ou PROD.

## RED e correções preservadas
- HML antes do BUILD: ausência das cinco APIs, RED esperado P0001; sem DDL/dados.
- Primeiro restore42311520049: migrations e comparação histórica PASS; nova suíte FAIL por qualificação inválida da variável de namespace. Corrigido para v_comando.
- Segundo restore42311874727: nova suíte FAIL porque tentativa direta sem versao_registro correta encontrou primeiro o trigger de concorrência40001. Teste corrigido para versão2, alcançando a proibição42501; não relaxou a negativa.
- Restore42312271436, job128216379096: reconstrução completa e suíte CRUD PASS no head2c6a595d56666489d08ca1fec9205661555f8604. Demais jobs e HEAD final requerem evidência própria antes de merge.
- Revisão independente detectou autorização revogada durante lock, corrida main/dispatch e perda do manifesto de fixtures caso cleanup falhasse. Corrigidos: reautorização antes do replay e após lock; SHA/hash/checks no canônico antes de DDL; IDs sanitizados persistidos antes de seed e segunda quarentena always.

## Limites e próximos gates
CI guard, verify, restore integral e duas instâncias no mesmo HEAD final são obrigatórios. Deploy canônico deve confirmar uma migration pendente, hash exato e paridade completa. JWT real e HTTP concorrente só após deploy, exclusivamente fixtures próprias, sem matriz global, com quarentena verificada e relatório sanitizado.
Ainda não comprovados neste registro: deploy HML, JWT, UI privada, CRUD global e certificação V1. Funções e arquivos aplicados não serão reescritos depois do deploy. Risco preexistente fora deste delta: INSERT direto em versoes_contrato permite snapshots arbitrários com escopo autorizado; requer tarefa própria antes de alegar integridade global da cadeia.
