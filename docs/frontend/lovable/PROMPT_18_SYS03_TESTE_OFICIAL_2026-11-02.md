# PROMPT 18 — SYS-03 — C. TESTE OFICIAL

Fonte: `Manual_Mestre_Prompts_4_1_100_PRD.docx` do pacote 4.1 anexado em 02/11/2026.

```text
NÃO ALTERE CÓDIGO.
Teste SYS-03 - Redefinir senha.
PASS/FAIL:
1. rota abre;
2. perfil autorizado funciona;
3. perfil não autorizado é bloqueado pelo backend/RLS, não só pela UI;
4. loading/empty/error funcionam;
5. nenhuma request usa secret key;
6. nenhuma ação crítica é update direto;
7. desktop 1440 e 1280 ok;
8. tablet 768 ok;
9. mobile 390 preserva dados críticos;
10. teclado/foco/labels ok;
11. console sem erro e sem log sensível;
12. Security scan sem novo Critical.
Não corrija automaticamente; relate evidências.
PARE AQUI: Só avance ao próximo número se o teste responder PASS nos itens obrigatórios.
```

## Interpretação de acesso para SYS-03
Para esta tela sistêmica `público/token`, “perfil autorizado” significa sessão de recuperação válida originada do fluxo oficial de Auth (`PASSWORD_RECOVERY`) e “não autorizado” inclui ausência de token/link válido, link expirado ou sessão Auth comum sem recovery. Nenhuma associação com RF atômico foi inventada.
