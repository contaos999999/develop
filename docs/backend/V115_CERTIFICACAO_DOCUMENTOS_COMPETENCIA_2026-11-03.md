# Certificação Backend — V1-15 Competência: Documentos

Data: 03/11/2026
Ambiente: HML
Prompt: 36 / V1-15
Status: CERTIFICADO — PATCH DOCUMENTAL RECERTIFICADO
PROD: intocado

## Escopo

Autoridade backend para a tela `/competencias/:id/documentos`, cobrindo leitura paginada de documentos e requisitos documentais do snapshot, criação idempotente, nova versão idempotente, processamento, isolamento tenant, versionamento imutável e exigência de motivo após início de análise.

## Migrations

Repositório: `contaos9999/develop`.

Base V1-15:
- Commit Git: `14ce84f463f6e5b3ef194d4e64525bd7536c6165`.
- Arquivo: `supabase/migrations/20261103103000_v115_documentos_competencia_autoridade.sql`.
- HML: `20261103101542 v115_documentos_competencia_autoridade`.

Patch corretivo de autoridade documental:
- Commit Git: `42f4011c354f95d1acbf029520bf014f5d0f74f5`.
- Arquivo: `supabase/migrations/20261103110500_v115_validar_requisito_tipo_documental.sql`.
- HML: `20261103110821 v115_validar_requisito_tipo_documental`.

Nenhuma alteração foi feita em PROD.

## RED e lacuna encontrada na auditoria do PLAN frontend

Após a certificação inicial, a auditoria independente do Prompt 36 encontrou duas lacunas na RPC de criação:

1. `criar_documento_competencia_v115` verificava apenas que `p_id_requisito` pertencia à competência, mas não exigia que o requisito fosse documental segundo `regra_validacao.documento.obrigatorio=true`.
2. Quando `regra_validacao.documento.tipos` possuía valores, `p_tipo` não era validado contra essa lista.

Essas duas decisões pertencem ao backend. O frontend não pode ser a única barreira para requisito documental ou tipo aceito.

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

O snapshot de `requisitos_competencia` preserva `regra_validacao` por meio do trigger existente `requisitos_snapshot_item_lista` / `privado.preencher_snapshot_item_lista`.

Após o patch:
- requisito informado deve pertencer à mesma competência;
- requisito informado deve ser documental pelo contrato explícito acima;
- se `documento.tipos` for array não vazio, `p_tipo` deve pertencer à lista;
- se `documento.tipos=[]`, qualquer tipo não vazio continua aceito;
- `p_id_requisito=null` continua permitido para documento avulso.

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

O frontend não deve recalcular pendência, estado documental, requisito documental ou tipo permitido.

### `public.criar_documento_competencia_v115`

- sessão, tenant e perfil validados;
- requisito, quando informado, deve pertencer à mesma competência e ser requisito documental explícito;
- tipos esperados não vazios são validados novamente no backend;
- arquivo validado por `privado.v110_validar_arquivo_contrato`;
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

## Testes transacionais HML

### Certificação base

A bateria inicial, com sessão HML real e `BEGIN ... ROLLBACK`, provou leitura, isolamento tenant, marcador documental, estados, paginação, idempotência, versionamento, motivo pós-análise, histórico imutável e mudança de hash de contexto.

### Patch corretivo

Nova bateria transacional, também com sessão HML real e rollback, retornou `PASS_V115_PATCH_DOCUMENTAL` e provou:

1. requisito da mesma competência, mas não documental, retorna `PT400`;
2. requisito documental de outra competência retorna `PT400`;
3. tipo fora de `documento.tipos` não vazio retorna `PT400`;
4. tipo esperado válido cria documento;
5. replay da mesma chave idempotente retorna o mesmo `id_documento` e não duplica efeitos;
6. `documento.tipos=[]` aceita tipo não vazio livre;
7. `p_id_requisito=null` continua permitido;
8. respostas bem-sucedidas preservam `schema_versao='v115-v1'`;
9. contagem após replay permaneceu exatamente nos três documentos esperados.

Após `ROLLBACK`, consulta de controle confirmou:
- contratantes fixture: 0;
- contratos fixture: 0;
- arquivos fixture: 0.

## Gates canônicos GitHub

Certificação base no commit `14ce84f463f6e5b3ef194d4e64525bd7536c6165`:
- `Verificar histórico HML`: run `41617653396` — **SUCCESS**.
- `ContaOS Zero-Drift`: run `41617653591` — **SUCCESS**.
- `ContaOS Restore Isolado`: run `41617653453` — **SUCCESS**.

Patch no commit `42f4011c354f95d1acbf029520bf014f5d0f74f5`:
- `Verificar histórico HML`: run `41624992277` — **SUCCESS**.
- `ContaOS Zero-Drift`: run `41624992207` — **SUCCESS**.
- `ContaOS Restore Isolado`: run `41624992252` — **SUCCESS**.

## Conclusão

**BACKEND V1-15 RECERTIFICADO E LIBERADO PARA CONSUMO DO FRONTEND.**

A partir deste ponto o banco volta a ficar congelado durante PLAN/BUILD frontend do Prompt 36.