# ContaOS 4.1 — IA, OCR, RAG, Histórico e Precedentes

## 1. Papel da IA

A IA é assistente de análise, não autoridade normativa nem aprovador.

Pode:
- OCR/visão;
- extração de metadados;
- classificação documental;
- sugestão de cláusulas/regras;
- comparação de evidências;
- análise de procedência;
- minuta de contestação;
- recuperação/ranking de precedentes;
- geração de resumo/parecer sugerido;
- copiloto conversacional.

Não pode:
- inventar fonte;
- criar obrigação material sem fonte;
- liberar apresentação/reapresentação;
- validar competência;
- esconder divergência;
- transformar padrão estatístico em norma;
- atualizar regra impeditiva silenciosamente.

## 2. OCR/documentos

Fluxo esperado:
1. arquivo registrado e enviado ao Storage privado;
2. integridade/segurança;
3. job de processamento;
4. OCR/visão quando necessário;
5. classificação e extração;
6. páginas/fragmentos;
7. sugestão com confiança/origem;
8. revisão humana quando material;
9. disponibilização para análise somente no estado adequado.

## 3. RAG

Recuperação deve ser **scope-first**:
1. determinar organização/contrato/competência/vigência autorizados;
2. filtrar conjunto elegível;
3. só então calcular similaridade vetorial;
4. retornar fonte completa;
5. não misturar tenant;
6. separar precedente próprio de transversal.

## 4. Hierarquia histórica

- fonte formal vigente supera precedente incompatível;
- precedente do próprio contrato é mais forte do que histórico transversal;
- histórico de outro contrato é alerta, não obrigação;
- inferência estatística é sinal de risco;
- mudança de entendimento deve preservar os dois lados do histórico.

## 5. Regra preventiva

Regra candidata derivada de histórico pode ser sugerida. Para produzir efeito material/impeditivo precisa de governança e, quando aplicável, fonte formal independente válida para o contrato atual.

## 6. Copiloto

O copiloto deve:
- responder sobre contrato, obrigações, histórico e competências;
- usar contexto temporal correto;
- citar fontes e páginas/trechos;
- distinguir fato, regra formal, precedente e inferência;
- declarar baixa confiança/conflito;
- pedir revisão humana quando necessário.

## 7. Estado homologado OpenAI

No HML certificado:
- provedor OpenAI;
- segredo armazenado apenas no backend;
- modelo operacional `gpt-6-luna`;
- análise estruturada e OCR/visão testados com sucesso.

Troca futura de modelo/provedor não pode alterar regras do domínio. O backend deve permanecer desacoplado.

## 8. Erro/fallback

Falha de IA/OCR não deve derrubar o núcleo transacional. Job falha de forma rastreável, aplica retry/DLQ quando configurado e apresenta mensagem amigável sem expor stack/secret.
