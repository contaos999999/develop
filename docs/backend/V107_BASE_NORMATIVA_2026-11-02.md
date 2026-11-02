# V107 backend — em implementação, não certificado

Autorização do usuário registrada na issue25. Branch exclusiva, PROD intocado.

RED anterior aDDL executado emHML com BEGIN/ROLLBACK:15 testes,1PASS/14FAIL. Falhas previstas:12 comandos ausentes (SQLSTATE42883), grants permitem bypass de DML e zero eventos normativos. A negativa deINSERT por leitor já passa porRLS. Fixtures integralmente revertidas. Não confundir esse RED com TesteC frontend.

CLI2.108.0 criou migration20261102213512_v107_base_normativa_autorizada.sql. Telemetria desativada por variável oficial SUPABASE_TELEMETRY_DISABLED=1, sem alterarHOME. Docker local indisponível; restore deverá ser comprovado pelo workflow isolado existente após integração, antes de certificação.

Plano: docs/superpowers/plans/2026-11-02-v107-base-normativa.md.
