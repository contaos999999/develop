# Protocolo Lovable Zero-Drift — ContaOS 4.1

## Contexto obrigatório antes de qualquer Build

Lovable e qualquer outra IA devem começar por `00_AI_LEIA_ANTES_DE_ALTERAR.md` e ler integralmente os 23 documentos canônicos da raiz, incluindo `08A`–`08D`. Depois devem validar `AI_CONTEXT_MANIFEST.md`, `AGENTS.md` e `docs/tasks/active-task.json`.

Uma tarefa de implementação só pode prosseguir quando `active-task.json` estiver ativo e declarar:
- `context_pack_version = 4.1`;
- `context_read_acknowledged = true`;
- todos os documentos obrigatórios em `context_documents_read`;
- fingerprint igual ao manifesto vigente;
- requisitos/telas/arquivos e permissões explícitos.

O CI executa `Context Gate` antes do Zero-Drift tradicional.

## Regras absolutas
1. Uma tarefa por branch quando o fluxo de branch estiver em uso.
2. Uma mudança conceitual por Build.
3. Database change exige autorização explícita no manifesto.
4. RLS change exige autorização explícita no manifesto.
5. Edge/Auth change exige autorização explícita no manifesto.
6. Auth, cliente Supabase e arquivos de governança são proibidos em tarefa comum.
7. Nenhum prompt funcional pode afrouxar o Zero-Drift.
8. Lovable apresenta/coleta/chama o Supabase. Não é autoridade de segurança.
9. Nenhum secret no navegador.
10. Nenhum portão crítico calculado em React.
11. Nenhum update genérico de status crítico.
12. Documentos/evidências permanecem em Storage privado.
13. O backend HML certificado deve ser reutilizado; não criar backend paralelo.
14. Migration aplicada nunca é reescrita.

## Architecture Guard
Bloquear secret no frontend; tabela de negócio nova sem RLS; status crítico local; update direto de status; backend paralelo; alteração dos textos oficiais; bucket público; mudanças fora de `allowed_paths`; alterações em `forbidden_paths`.

## Sinais de drift
Tabela não pedida; policy afrouxada para facilitar teste; secret no cliente; botão mudando status por update; arquivo fora do manifesto; correção de bug não autorizada; criação de schema/serviço duplicado; alteração de migration aplicada; uso de alerta transversal como bloqueio do contrato atual.

## Regra de parada
Se qualquer documento obrigatório não puder ser lido ou se o fingerprint do contexto divergir, o Build é **NO-GO** até nova leitura e atualização do manifesto da tarefa.
