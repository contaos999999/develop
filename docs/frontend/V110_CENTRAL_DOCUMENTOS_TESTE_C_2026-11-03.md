# V1-10 — Central de Documentos — Certificação final / Teste C

Data: 03/11/2026
Pacote canônico: ContaOS 4.1
Frontend: `contaos9999/contaos-hml-control`
Backend HML: `gklhhhyosgasnyoxlrui`
PROD: intocado

## Objeto certificado

SHA funcional certificado: `e2551e5ce3c82c63da61340eeb895d173f55f18f`.

Após o Teste C, o Lovable regenerou automaticamente apenas `src/integrations/supabase/types.ts`. O drift foi removido externamente e o branch `main` foi restaurado para uma árvore idêntica ao SHA funcional certificado, preservando Zero-Drift de tipos contra `e10f7973260df0c455bb66baa091e5c9b3124efe`.

## Escopo certificado

- rota `/contratos/:id/documentos`;
- gate sessão → organização → contrato antes de consultas de negócio;
- cadastro de documentos-base com tipo, título, categoria, vigência, observações e versão;
- upload múltiplo direto ao Storage privado;
- configuração de formatos/MIME/limites lida de `configuracao_upload`;
- upload resumível TUS para arquivos acima do limiar configurado;
- confirmação de upload com SHA-256;
- criação atômica/idempotente do documento;
- nova versão sem apagar anterior, com motivo e idempotência;
- download somente por URL assinada temporária quando segurança permitir;
- quarentena/bloqueio com metadados visíveis e download indisponível;
- classificação automática exibindo categoria, confiança e item sugerido real via `requisitos_competencia`;
- indicadores somente leitura de IA/metadados/vigência;
- paginação server-side de documentos;
- sugestões e processamentos agregados sem N+1 por versão;
- `processamentos_documento` paginado em lotes de 1000 até esgotar, preservando o processamento mais recente por versão pela ordenação `criado_em DESC, id DESC`;
- PT-BR, BRAND-01, responsividade e acessibilidade preservados;
- V1-11 e V1-12 não antecipados.

## TDD e Teste C final

Delta final de robustez:
- RED: 1 falha / 32 aprovados antes da constante dedicada e do teste multi-versão;
- GREEN: teste focado 33/33;
- suíte completa: 466/466 em 20 arquivos;
- `npx tsc --noEmit`: exit 0;
- `npm run build`: exit 0;
- lint dos arquivos alterados: 0 erros;
- lint global: 8.962 erros / 9 avisos, igual ao baseline;
- varredura estática: sem `service_role`, secrets, `as any`, escrita direta Supabase, bucket público, `getPublicUrl`, `revisar_sugestao_extracao`, `definir_vigencia_sugestao_extracao` ou `console.log` no código de produção V1-10;
- `types.ts`: diff 0 contra o baseline certificado no objeto testado;
- identidade visual: nenhuma alteração visual no delta final; permanece válida a certificação 1440/1280/768/390 claro/escuro do SHA `8bb14e81e71e307973eb8403c6109531b54f2d41`.

## Resultado

**TESTE C FINAL: PASS**.

Nenhum gate obrigatório ficou em FAIL ou LIMITADO no Teste C final. O Prompt 31 / V1-10 está encerrado tecnicamente e apto a servir de baseline para o Prompt 32 / V1-11.
