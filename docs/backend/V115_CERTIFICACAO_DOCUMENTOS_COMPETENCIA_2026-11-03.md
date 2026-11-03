# Certificação Backend — V1-15 Competência: Documentos

Data: 03/11/2026
Ambiente: HML
Prompt: 36 / V1-15
Status: CERTIFICADO
PROD: intocado

## Escopo

Autoridade backend para a tela `/competencias/:id/documentos`, cobrindo leitura paginada de documentos e requisitos documentais do snapshot, criação idempotente, nova versão idempotente, processamento, isolamento tenant, versionamento imutável e exigência de motivo após início de análise.

## Migration

Repositório: `contaos9999/develop`

- Commit Git: `14ce84f463f6e5b3ef194d4e64525bd7536c6165`
- Arquivo: `supabase/migrations/20261103103000_v115_documentos_competencia_autoridade.sql`
- Aplicada no HML como migration `20261103101542 v115_documentos_competencia_autoridade`.

Nenhuma alteração foi feita em PROD.

## RED registrado antes da implementação

Antes da migration:

- `public.obter_documentos_competencia_v115` não existia.
- `public.criar_documento_competencia_v115` não existia.
- `public.adicionar_versao_documento_competencia_v115` não existia.
- A RPC antiga de nova versão não consultava `execucoes_analise` e aceitava motivo nulo após início de análise.

## Contrato explícito de requisito documental

O backend considera requisito documental somente quando o snapshot contém:

```json
{
  "documento": {
    "obrigatorio": true,
    "tipos": ["tipo_1", "tipo_2"]
  }
}
```

A interpretação é feita por `privado.v115_requisito_exige_documento(jsonb)`. Ausência, valor inválido ou outra regra de validação não é transformada por heurística em requisito documental.

O snapshot de `requisitos_competencia` já preserva `regra_validacao` por meio do trigger existente `requisitos_snapshot_item_lista` / `privado.preencher_snapshot_item_lista`; portanto não foi necessária correção adicional de snapshot.

## RPCs públicas V1-15

### `public.obter_documentos_competencia_v115`

Leitura `STABLE`, paginada e autoritativa. Retorna:

- competência e contrato;
- `estado_documental`: `missing_docs`, `processing`, `error` ou `complete`;
- resumo de documentos e requisitos documentais;
- documentos com vínculo ao requisito, versão atual, arquivo, hash, metadados extraídos e processamento atual;
- requisitos documentais explícitos do snapshot e `tipos_esperados`;
- paginação server-side separada para documentos e requisitos;
- capacidades de enviar/nova versão;
- `motivo_nova_versao_obrigatorio` quando já existe qualquer `execucoes_analise` da competência.

O frontend não precisa, nem deve, recalcular pendência ou estado documental.

### `public.criar_documento_competencia_v115`

- sessão, tenant e perfil validados;
- requisito, quando informado, deve pertencer à mesma competência;
- arquivo validado pelo helper certificado `privado.v110_validar_arquivo_contrato`;
- comando idempotente por `privado.v110_iniciar_comando`;
- cria documento + versão 1;
- enfileira processamento e cria `processamentos_documento`;
- registra auditoria/correlação V1-15;
- replay da mesma chave devolve o mesmo resultado sem duplicar efeitos.

### `public.adicionar_versao_documento_competencia_v115`

- sessão, tenant e perfil validados;
- idempotência por chave;
- lock `FOR UPDATE` no documento;
- histórico preservado e nova versão incremental;
- arquivo validado antes da gravação;
- motivo opcional antes de qualquer análise;
- motivo obrigatório quando já existe `execucoes_analise` da competência;
- processamento e auditoria criados para a nova versão.

As RPCs antigas permanecem inalteradas para compatibilidade. O frontend V1-15 deve usar somente as RPCs `*_v115`.

## Integridade do contexto de análise

`privado.snapshot_contexto_competencia` já inclui a versão atual/hash dos documentos da competência. Assim, criar documento ou nova versão altera naturalmente `privado.hash_contexto_competencia`, tornando análise/aprovação anterior incompatível com o novo contexto sem lógica paralela de invalidação.

## Segurança e grants

- wrappers públicos V1-15 são `SECURITY DEFINER` e expostos somente a `authenticated` e `service_role`;
- `anon` e `public` não possuem `EXECUTE`;
- funções privadas V1-15 não são executáveis por `authenticated`, `anon`, `public` ou `service_role`;
- autorização interna exige sessão ativa e acesso ao contrato;
- perfis de escrita são validados no backend.

RLS existente foi preservado. Não houve alteração de políticas.

## Storage

O fluxo certificado V1-10 foi reutilizado:

- bucket `contaos-documentos` permanece privado;
- upload/download continuam por URLs assinadas e autorização server-side;
- leitura de objeto depende do status de segurança e do acesso ao contrato;
- arquivos em quarentena/bloqueados não são disponibilizados para download;
- limites e MIME continuam vindos de `configuracao_upload`.

Nenhuma alteração de Storage, Edge Functions, Auth ou bucket foi necessária.

## Teste transacional HML

Foi usada uma sessão HML real, com todas as fixtures dentro de `BEGIN ... ROLLBACK`. A bateria passou sem exceção e provou:

1. requisito só é documental quando `regra_validacao.documento.obrigatorio=true`;
2. estado inicial `missing_docs` e tipos esperados vindos do snapshot;
3. criação idempotente, sem duplicar documento ou versão inicial;
4. após criação, estado `processing`;
5. após conclusão do processamento, estado `complete`;
6. paginação server-side preserva totais;
7. antes de análise, nova versão sem motivo é permitida;
8. replay idempotente não duplica versão;
9. histórico permanece imutável;
10. o hash do contexto muda após nova versão;
11. após existir `execucoes_analise`, o backend expõe `motivo_nova_versao_obrigatorio=true`;
12. nova versão sem motivo após análise retorna `PT400`;
13. nova versão com motivo persiste o motivo e cria a versão seguinte;
14. processamento falho da versão atual produz `estado_documental=error`;
15. outro tenant sem vínculo recebe `42501`;
16. requisito de outra competência é rejeitado com `PT400`.

Após o rollback, consulta de controle confirmou zero organizações, competências e arquivos de fixture persistidos.

## Gates canônicos GitHub

Todos no commit `14ce84f463f6e5b3ef194d4e64525bd7536c6165`:

- `Verificar histórico HML`: run `41617653396` — **SUCCESS**.
- `ContaOS Zero-Drift`: run `41617653591` — **SUCCESS**.
- `ContaOS Restore Isolado`: run `41617653453` — **SUCCESS**.

## Conclusão

**BACKEND V1-15 CERTIFICADO PARA CONSUMO DO FRONTEND.**

A partir deste ponto o banco fica congelado para o BUILD frontend do Prompt 36. Novas alterações de schema/RPC/RLS/Edge/Auth/Storage exigem reabertura formal da tarefa.