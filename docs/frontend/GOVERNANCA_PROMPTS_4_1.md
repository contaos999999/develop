# Governança de Prompts — ContaOS 4.1

Data: 02/11/2026
Fonte primária: `ContaOS_Pacote_Mestre_Arquitetura_4_1_100_PRD_Lovable_Supabase_FINAL.zip`

## Conjuntos obrigatórios

O ContaOS 4.1 possui dois conjuntos de prompts obrigatórios e cumulativos:

1. **100 prompts regulares**, numerados de **PROMPT 00 a PROMPT 99**. Como a numeração começa em zero, são 100 blocos.
2. **96 prompts atômicos**, numerados de **001 a 096**, vinculados à matriz de 96 requisitos do PRD.

## Regra de execução

Para cada tela/feature:
- identificar o prompt regular correspondente;
- identificar todos os prompts atômicos aplicáveis;
- executar Plan → aprovação → Build → Teste → Audit;
- não avançar quando houver FAIL obrigatório;
- não considerar a tela concluída apenas porque o prompt regular passou se houver prompt atômico aplicável pendente;
- quando nenhum prompt atômico for aplicável, registrar essa conclusão de rastreabilidade sem inventar associação artificial.

## Rastreabilidade mínima

Cada implementação deve permitir reconstruir:

`PRD → requisito(s) 001–096 → prompt(s) atômico(s) → PROMPT regular 00–99 → plano → build → teste → evidência → commit/PR → aceite`.

## Regra de autoridade

Os 100 prompts regulares e os 96 prompts atômicos não competem entre si. Eles se complementam. Em caso de divergência, prevalecem a decisão funcional mais recente aprovada, o PRD/Premissas 4.1, a Arquitetura Oficial, o Zero-Drift e o estado real certificado do HML, conforme a cadeia de autoridade do pacote.

PROD permanece fora de escopo durante a fase atual.