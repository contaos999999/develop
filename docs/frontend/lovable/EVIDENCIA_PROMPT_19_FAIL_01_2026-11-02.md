# PROMPT 19 / SYS-04 — Evidência de FAIL 01

Data: 02/11/2026
Ambiente: HML `gklhhhyosgasnyoxlrui`
Lovable: `b113dd59-6caf-4c92-8302-457a037a0c6f`

## Resultado

O primeiro TESTE oficial C foi interrompido em FAIL, sem correção automática no turno de teste.

### Falha

Sem sessão, `supabase.auth.getUser()` no cliente real devolveu `AuthSessionMissingError` (status 400). A implementação tratava qualquer `error` do `getUser()` como falha técnica, portanto `/selecionar-organizacao` permaneceu na própria rota mostrando erro genérico em vez de redirecionar para `/login`.

### Evidências que passaram antes da interrupção

- Suíte: 54/54 testes PASS.
- Typecheck: PASS.
- Build: PASS.
- 1440x900, 1280x720, 768x1024 e 390x844: sem overflow horizontal, dados críticos preservados e teclado validado em ambiente visual controlado.
- Estados loading, empty, erro 500 e denied 403/42501: comportamento correto em respostas controladas.
- RLS HML real: usuário autorizado enxerga 1 vínculo e a organização vinculada; organização ativa sem vínculo retorna 0 linhas.
- Rede/código do SYS-04: somente leitura + Auth; nenhuma operação crítica de escrita, RPC ou secret.
- Nenhum arquivo foi alterado durante o turno de TESTE.

### Security scan

Não executado neste turno porque o protocolo determina parar no primeiro FAIL.

### Correção autorizada pelo fluxo contínuo

A correção deverá ser mínima e TDD: tratar explicitamente `AuthSessionMissingError`/ausência de sessão como redirecionamento para `/login`, mantendo erros técnicos reais no estado genérico de erro. Depois, repetir o TESTE oficial completo desde o início.
