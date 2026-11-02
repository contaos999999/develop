# PROMPT 16 — SYS-01 Login — Teste oficial

Fonte: `Manual_Mestre_Prompts_4_1_100_PRD.docx`, bloco C.TESTE do PROMPT 16.
Data de execução: 02/11/2026
Ambiente: HML

## Texto oficial enviado ao Lovable

NÃO ALTERE CÓDIGO.
Teste SYS-01 - Login.
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

## Regra adicional de auditoria
O resultado deve distinguir claramente PASS, FAIL e BLOQUEADO/PENDENTE quando a validação depender de credencial HML válida ou de ferramenta não disponível. Nenhum item pode ser marcado PASS por inferência.
