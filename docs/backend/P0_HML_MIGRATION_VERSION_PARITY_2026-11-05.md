# Regra canônica P0: paridade de migrações GitHub ↔ Supabase HML

## Problema
A aplicação via API Supabase `apply_migration` atribuiu a versão `20261106003138` à migração cujo arquivo versionado e gerado por Supabase CLI 2.81.3 no GitHub é `20261105232056_p0_v1_historico_fila_check.sql`. A execução do DDL foi bem-sucedida, mas o histórico ficou divergente.

## Regra definitiva
1. Criar **sempre** o arquivo com Supabase CLI fixada e registrar o arquivo SQL no GitHub por PR.
2. Nunca usar `apply_migration` para implantar uma migração versionada do repositório. Essa API pode criar versão própria.
3. Implantar em HML **somente** pelo workflow `.github/workflows/p0-hml-migration-version-parity.yml`, operação `deploy_one`, indicando exatamente os 14 dígitos do arquivo.
4. O workflow valida segredo e project ref HML, compara versões locais e remotas, exige **uma única migração pendente**, executa `supabase db push --db-url` via CLI fixada, confere o registro do banco e testa a igualdade global. Qualquer divergência interrompe a implantação; jamais aplica várias migrações silenciosamente.
5. A operação excepcional `repair_68` reconcilia o registro legado **sem reaplicar o DDL**, somente se o CHECK existente corresponder exatamente ao aprovado e o histórico antigo estiver no estado esperado.
6. Não habilitar PROD neste workflow. Não executar reparo genérico ou `migration repair` para outros casos sem diagnóstico e autorização específicos. Preservar Zero-Drift e os gates canônicos.

## Evidências
- CLI gerou o arquivo no run 42128916139; PR #72 integrou o SQL.
- Supabase aplicou o SQL, mas registrou a versão 20261106003138.
- PR #73 regularizou a autorização do manifesto.
- O workflow de paridade só pode ser considerado operacional após execução verde, confirmação SQL e comparação completa de versões.

## Atenção
A versão de histórico não prova que o conteúdo do SQL aplicado corresponde ao arquivo; para o reparo legado, o workflow compara o CHECK efetivo antes de alterar o histórico. Outras migrações exigem gates e evidências próprios.
