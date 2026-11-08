# Delegação da nova versão documental: plano e GATE

**Objetivo:** corrigir a RPC pública de nova versão sem abrir execução direta da rotina privada.

**Arquitetura:** manter frontend, Auth/sessão, RBAC/tenant, RPCs e duas Edges existentes. A entrada pública deve executar como seu owner e a rotina privada mantém todas as verificações do usuário real. PostgreSQL/Supabase, migration aditiva CLI2.81.3, testes Node e Restore SQL real.

**Especificação:** continuidade autorizada Trilha B/GATE138, padrão de delegação já aplicado150 e prova material148 no HEADce30d485518b2b077575fc967746ea2000a9da92.

## Evidência e limite

Run42479943135/job128729514650FAILURE. Artifact13616839267/SHA2561119397b14c337aacf5add6bf011f256c113a7f006ef1d97d4a85fa49196e9b9 baixado e conferido. PublicadoTXT1 PASS_SMOKE comworker/download/GETintegridade e114módulos com SHA dos bytes carregados/fencefailedfalse; frontend_headnull/paridadeNAO_VERIFICADA. LocalTXT1 concluiu; TXT2assinatura/storage/confirmação200, registro403. PDFnãoexecutado, sem5/3/5PASS. Quarentena4users/2org/3uploadspreservados/0jobsativos; SQLreadonly próprio confirmou Authbantrue/3files/0active. Não reutilizar esse nonce949b267631c24181b8edb34b8563f9fa nem fixtures152/160 alheias.

Catálogo real: public.adicionar_versao_documento_contrato(uuid,uuid,text,text) INVOKER,ownerpostgres/search_pathvazio, ACLpostgres/service_role/authenticatedEXECUTE/anonfalse, corpoMD56d0c5926f4b25fd0e9562b0c010174ef. Chama privado.adicionar_versao_documento_contrato_v110, DEFINER/corpo10698cb96e7de1de5a88b25960b341e5/ACLpostgresapenas. INVOKER não pode executar essa rotina. Ela já exige permissão documentos_contrato/editar, sessão ativa, tenant/contrato/perfil e motivo, preservados integralmente.

## Limites deste GATE

Somente plano/manifesto nesta etapa. Autoriza BUILD subsequente com migrationCLI20261108122815_fix_document_version_wrapper.sql gerada vazia, precondições de corpos/owner/ACL/search_path exatos e uma única alteração de atributo SECURITYDEFINER da assinatura pública. Não alterar corpo, owner, grants, rotina privada, schema, RLS, Edge, frontend317, segredos, Authconfig, plano/cobrança ou PROD. Senha vazada excluída pelo titular. Nenhuma certificaçãoCRUD/V1/V2.

## Implementação e provas

- [ ] RED Node exige a migration aditiva e delta de catálogo exato; não editar migrations aplicadas.
- [ ] Migration transacional recusa drift antes do ALTER exato. Comparação de catálogo aceita somente definerfalse→true da assinatura/config/ACL únicas, mantendo os demais registros visíveis e entradas imutáveis. Casos de campo alterado, ausência e duplicata devem recusar.
- [ ] Aceitação SQL real com sessão autenticada: criação e nova versão positivas próprias; negar semsessão/sessão inválida/leitor/outrotenant e arquivo de outrocontrato, preservando contagens/versões/idempotência. Teste de motivo obrigatório PT400, preservando regras atuais.
- [ ] Preflight material só permite Auth/fixtures quando catálogo confirma esse wrapper pronto e privada fechada; simular metadata ausente/falsa para RED→GREEN antes de Auth.
- [ ] Suíte completa, dez guards, revisão independente, guard/public-probe/Restore/rebuild/backup SUCCESS no MESMO HEAD antes ready/merge normal CAS. Falha nunca vira PASS por remover teste.
- [ ] Deploy canônico deploy_one somente HML, expected_source_sha e SHA256 fixos, uma migration pendente/paridade global. Verificar atributo modificado e corpos/owner/ACL/search_path preservados. Só depois reativar lote novo1publicado+4locais e comprovar5/3/5/recibos/worker/cleanup, sem reutilizar fixture parcial.

Arquivos BUILD são os oito caminhos exatos em version_wrapper_guard.planned_build_paths no manifesto. Neste GATE somente este documento e active-task.json são editáveis. Revisão do escopo e guard obrigatórios antes integração.

ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE: visualN/A, backend existente, semLovable/frontend/PROD.
