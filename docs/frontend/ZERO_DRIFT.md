# Protocolo Lovable Zero-Drift — ContaOS 4.1

## Regras absolutas
1. Uma tarefa por branch.
2. Uma mudança conceitual por Build.
3. Database change exige autorização explícita no manifesto.
4. RLS change exige autorização explícita no manifesto.
5. Auth, cliente Supabase e arquivos de governança são proibidos em tarefa comum.
6. Nenhum prompt funcional pode afrouxar o Zero-Drift.
7. Lovable apresenta/coleta/chama o Supabase. Não é autoridade de segurança.
8. Nenhum secret no navegador.
9. Nenhum portão crítico calculado em React.
10. Nenhum update genérico de status crítico.
11. Documentos/evidências permanecem em Storage privado.

## Architecture Guard
Bloquear secret no frontend; tabela de negócio nova sem RLS; status crítico local; update direto de status; backend paralelo; alteração dos textos oficiais; bucket público; mudanças fora de `allowed_paths`; alterações em `forbidden_paths`.

## Sinais de drift
Tabela não pedida; policy afrouxada para facilitar teste; secret no cliente; botão mudando status por update; arquivo fora do manifesto; correção de bug não autorizada.
