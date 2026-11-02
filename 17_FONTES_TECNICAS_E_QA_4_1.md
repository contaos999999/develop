# ContaOS 4.1 — Fontes Técnicas, QA e Certificações do Pacote

Consolidação dos arquivos de `09_AUDITORIA_E_FONTES`.

## 1. Objetivo

Distinguir três coisas:
1. regra funcional do ContaOS;
2. decisão arquitetural do projeto;
3. fato técnico externo sobre Lovable/Supabase/OpenAI/GitHub.

Fato técnico externo que possa ter mudado deve ser revalidado na documentação oficial antes de nova implementação sensível.

## 2. Fontes técnicas do pacote

O pacote 4.1 foi montado com referência a documentação oficial das plataformas adotadas, especialmente:
- Supabase: banco, Auth, Storage, RLS, Edge Functions, Queues, Cron, vetores e segurança;
- Lovable: integração Supabase, Git, instruções e fluxo de construção;
- GitHub: versionamento e revisão;
- OpenAI: uso de IA/OCR no backend.

## 3. Relatório de transição arquitetural

A transição para Arquitetura 4.0 preservou regras funcionais e substituiu decisões tecnológicas incompatíveis pelo desenho Lovable + Supabase. Regra funcional não pode mudar apenas porque a stack mudou.

## 4. QA de conteúdo

A revisão 4.1 explicitou lacunas de cobertura e fechou a rastreabilidade para:
- 96/96 requisitos;
- 28/28 épicos;
- catálogo de telas completo;
- prompts e testes correspondentes;
- RNF;
- custos por etapa.

## 5. Certificação da especificação versus implementação

A certificação original do pacote significa **especificação coberta**. Depois, o backend HML passou por certificação executada independente. Não confundir os dois níveis:
- especificação: o que deve existir;
- implementação certificada: o que foi provado no HML.

## 6. Manifestos SHA

O pacote possui manifestos de integridade. O certificado do backend registra o SHA-256 do pacote utilizado e a verificação dos hashes não autorreferentes. A autorreferência do próprio manifesto é exceção documental conhecida.

## 7. Changelog

Qualquer revisão futura da raiz canônica deve registrar:
- o que mudou;
- qual requisito/decisão autorizou;
- impacto em PRD/Premissas/Arquitetura;
- se o fingerprint de contexto mudou;
- quais testes foram repetidos.

## 8. Regra de atualização de conhecimento técnico

Se uma IA estiver prestes a usar recurso de plataforma cuja API/configuração possa ter mudado, deve consultar documentação oficial atual antes da alteração, sem reinterpretar o PRD com base em novidade da plataforma.
