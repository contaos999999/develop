# Certificação Frontend — V1-15 Competência: Documentos

Data: 03/11/2026
Ambiente: HML
Prompt: 36 / V1-15
Status: CERTIFICADO
PROD: intocado

## Escopo certificado

Tela `/competencias/:id/documentos` para documentos vinculados à competência e requisitos documentais do snapshot, com resumo documental, paginação server-side, envio, nova versão, processamento e download autorizado.

O frontend não decide requisito documental, tipos permitidos, estado documental, capacidades ou obrigatoriedade do motivo. Essas decisões permanecem no backend HML certificado.

## Backend utilizado

RPCs oficiais certificadas:

- `public.obter_documentos_competencia_v115`
- `public.criar_documento_competencia_v115`
- `public.adicionar_versao_documento_competencia_v115`
- `public.confirmar_upload_arquivo`
- `storage-sign-upload`
- `storage-sign-download`

Certificação backend relacionada:

- `docs/backend/V115_CERTIFICACAO_DOCUMENTOS_COMPETENCIA_2026-11-03.md`
- migration base `20261103103000_v115_documentos_competencia_autoridade.sql`
- patch `20261103110500_v115_validar_requisito_tipo_documental.sql`
- Histórico HML `41624992277`: SUCCESS
- Zero-Drift backend `41624992207`: SUCCESS
- Restore Isolado `41624992252`: SUCCESS

Contrato autoritativo: somente `regra_validacao.documento.obrigatorio=true` declara requisito documental. Quando `documento.tipos` é lista não vazia, o backend exige que `p_tipo` pertença à lista.

## Frontend auditado

Repositório: `contaos9999/contaos-hml-control`

- Base operacional do PLAN: `78cdd23ce72558fc59161ed2a2ed5059cd1f190b`.
- SHA funcional auditado no Teste C: `87d5905dcbaec61f0fd7c8aad6dcc90999e7a286`.
- SHA final atual da `main` após neutralização do drift automático do turno read-only: `cdfbc59be69007b844391d63f32f28894b56d2b1`.
- Comparação `87d5905d… -> cdfbc59b…`: zero arquivos diferentes. A árvore final da `main` é byte a byte equivalente à árvore auditada.
- `src/integrations/supabase/types.ts`: blob certificado `8ea7750b75fd9d76b29c36ce7613392e3ab65e19`.

## Evidências funcionais

- Rota `/competencias/:id/documentos`, `ssr:false`, head PT-BR.
- UUID inválido encerra antes de `getUser`, preferência de organização e RPC da feature.
- Sessão e preferência de organização funcionam como gate/contexto; autorização efetiva permanece no backend/RLS.
- 401/403/42501, PT404 e transporte possuem tratamentos distintos e mensagens sanitizadas em PT-BR.
- Paginação server-side de 25 documentos e 25 requisitos, com offsets independentes e vinculados ao UUID da competência.
- Troca de competência A -> B começa obrigatoriamente com offsets 0; paginação visual também reinicia.
- Estado da tela, autorização e dados carregados ficam vinculados ao recurso atual; respostas tardias são descartadas via AbortController/controle de ciclo de vida.
- Parser fail-closed: campos autoritativos numéricos e booleanos inválidos/ausentes rejeitam o payload em vez de gerar 0/false artificiais.
- `estado_documental`, resumo, `atendido`, capacidades e motivo obrigatório são exibidos conforme backend, sem recalcular heurísticas no React.
- `RequiredDocumentsSummary`, `DocumentTable`, `UploadDropzone` e `ProcessingStatus` implementados.
- `tipos_esperados` não vazio usa exatamente os valores do backend; labels conhecidas usam `ROTULO_TIPO` e valores desconhecidos usam fallback literal. Sem requisito/lista vazia reutiliza `TIPOS_DOCUMENTO` V1-10.
- Ao requisito selecionado sair da página atual, vínculo, tipo e tentativa lógica/idempotência são resetados; nunca ocorre degradação silenciosa para `idRequisito=null`.
- Pipeline de upload V1-10 é único e compartilhado via `enviarArquivoCertificado`; não existe segundo TUS/storage-sign/MIME/hash no V1-15.
- Testes possuem spies diretos em `enviarArquivoCertificado` e `baixarDocumento`.
- Upload privado: configuração dinâmica -> validação -> assinatura -> simples/TUS -> SHA-256 -> confirmar arquivo -> criar documento V1-15.
- Idempotência permanece estável na mesma tentativa lógica e é renovada quando o usuário altera arquivo/metadados relevantes.
- Nova versão respeita capability do backend, motivo condicional e histórico imutável.
- Download usa `storage-sign-download`; quarentena, bloqueado e pendente não abrem arquivo.
- Polling ocorre somente em `processing`, reutiliza `atrasoPolling` e termina em estado terminal, erro, unmount ou troca de recurso.
- V1-14 `Documentos` passou a link real; Análise/Parecer/Apresentação permanecem staged/Em breve.

## TDD e correções incorporadas

Foram mantidos REDs permanentes e GREEN para:

- parser fail-closed dos campos autoritativos;
- requisito selecionado que sai da página;
- vínculo do estado/autorização ao recurso atual;
- paginação vinculada ao recurso, incluindo A página 2 -> B primeira leitura offsets 0.

## Testes

Teste C final no SHA `87d5905d…`:

- V1-15: **69/69**.
- Suíte completa serial `--maxWorkers=1`: **645/645**, 25 arquivos.
- Regressão V1-14/V1-13/V1-12/V1-11/V1-10 incluída na suíte; evidência focada anterior: **165/165**.
- Lint dos arquivos alterados: exit 0.
- Static scan: sem `service_role`, secrets, `getPublicUrl`, `dangerouslySetInnerHTML`, REST manual, escrita direta em tabela ou uploader paralelo.
- Security Scan: 0 Critical, 0 High, 0 Medium e 0 Low; 1 Info preexistente sobre proteção contra senhas vazadas. Wiz não configurado.
- Teste C: **PASS**, sem desvio concreto.

Gate externo independente no GitHub Actions sobre branch temporária criada a partir do SHA auditado:

- Run `41646123057` — `Verify V1-15`.
- Job `125951796555` — SUCCESS.
- TypeScript `bunx tsc --noEmit`: SUCCESS.
- Build `bun run build`: SUCCESS.

## Visual, acessibilidade e Brand

- BRAND-01 preservada; `ContaOSMarca` e tokens existentes reutilizados.
- Sem segunda paleta, sem alteração de shared UI ou estilos globais.
- Browser no Teste C: 1440 / 1280 / 768 / 390 px, claro e escuro, sem overflow de página no cenário de UUID inválido; um H1 e zero chamadas ao Supabase.
- Tabela possui rolagem horizontal controlada quando necessária.
- Labels, `aria-live`, roles e alvos interativos foram cobertos por testes automatizados/inspeção.

## Zero-Drift

Diff protegido = zero na árvore certificada para:

- `supabase/**`
- package/lock
- `src/integrations/supabase/client.ts`
- `src/integrations/supabase/types.ts`
- `src/components/ui/**`
- `src/styles.css`
- `public/brand/**`
- AGENTS
- PROD

O turno read-only do Teste C regenerou automaticamente somente `types.ts` (+235 linhas). O efeito foi neutralizado em commit de restauração, e a `main` final voltou à árvore exata do SHA auditado.

## Limitação registrada

Não houve sessão HML real no navegador para os fluxos autenticados. Upload, nova versão, troca entre competências, estados, foco e alvos de interação foram validados com fixtures/mocks e testes automatizados. Backend, RPCs, isolamento, grants, migrations e contratos foram certificados diretamente no HML em etapa própria.

## Conclusão

**PROMPT 36 / V1-15 — APROVADO / TESTE C PASS / TYPESCRIPT PASS / BUILD PASS / ZERO-DRIFT CONFIRMADO.**
