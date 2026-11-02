# ContaOS 4.1 — Custos e Planos de Referência

Consolida `PLANO_CUSTOS_POR_ETAPA_ContaOS_4_1.docx`, `FONTES_CUSTOS_01_11_2026.md` e a parte de custos da matriz 4.1.

## 1. Regra de engenharia

Custo não autoriza violar arquitetura. Não reduzir segurança, RLS, histórico, auditoria ou separação HML/PROD para economizar plano.

## 2. Estratégia de contratação

A documentação 4.1 foi desenhada para evolução de custos conforme etapa: usar recursos gratuitos/menores enquanto adequados à homologação e contratar planos/recursos de produção quando requisitos de capacidade, disponibilidade, backup, domínio e operação exigirem.

## 3. Componentes de custo esperados

- Lovable/plano de desenvolvimento e publicação;
- Supabase HML;
- Supabase PROD;
- armazenamento e tráfego;
- Edge Functions/compute;
- OpenAI/IA/OCR;
- e-mail/SMTP se contratado;
- domínio/DNS;
- observabilidade adicional quando necessária;
- backup/PITR conforme plano;
- integrações externas.

## 4. Regra para IA que altera o sistema

Antes de introduzir serviço pago adicional, nova dependência SaaS ou workload que aumente custo material:
- provar necessidade;
- verificar se capacidade oficial já existente resolve;
- estimar custo recorrente;
- verificar impacto HML/PROD;
- obter aprovação humana.

Não adicionar fornecedor externo por conveniência de implementação.

## 5. Atualidade

Preços do pacote foram levantados em 01/11/2026 e podem mudar. Antes de decisão financeira, consultar preço oficial atual. Os valores históricos do pacote são referência de planejamento, não preço garantido.
