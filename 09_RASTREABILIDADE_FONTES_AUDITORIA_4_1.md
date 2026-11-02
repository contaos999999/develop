# ContaOS 4.1 — Rastreabilidade, Fontes e Auditoria

Este documento consolida a matriz de rastreabilidade, o relatório de análise documental, certificações QA e as regras de fontes do pacote 4.1.

## 1. Princípio

Nenhuma conclusão material deve existir “solta”. Deve ser possível reconstruir por que o sistema chegou àquele resultado e quais versões de dados/documentos/regras participaram.

## 2. Evidência de requisito/apontamento

Quando aplicável, preservar:
- requisito/regra;
- documento ou fonte;
- versão do documento;
- página;
- trecho;
- hash;
- competência;
- contrato;
- execução de análise;
- método (determinístico/semântico/IA);
- justificativa/fundamento;
- ator/revisor.

## 3. Fonte normativa

Fonte formal deve guardar identificação, vigência, versão e aplicabilidade. Regra automática/material não pode existir sem fonte identificável quando a obrigação deriva de norma/contrato/manual formal.

## 4. Precedente

Precedente histórico deve preservar:
- contratante;
- contrato de origem;
- competência;
- relatório/parecer de origem;
- item/apontamento;
- problema;
- resposta/solução;
- desfecho;
- força/confiança;
- revisão humana quando material.

## 5. Inteligência transversal

Resultado vindo de outro contrato deve carregar origem explícita e ser rotulado como transversal. Deve preservar pelo menos contrato, competência, relatório/unidade/item/desfecho, similaridade e evidências. Seu efeito no portão é falso até promoção formal baseada em fonte independente aplicável ao contrato atual.

## 6. Copiloto

Respostas relevantes precisam guardar fontes utilizadas, incluindo tipo/id/versão/página/trecho e score quando houver busca semântica. Baixa confiança ou conflito deve ser exibido, não escondido.

## 7. Auditoria operacional

Eventos de auditoria devem cobrir mudanças materiais como:
- criação/alteração de contrato e regra;
- aprovação/rejeição;
- liberação/apresentação/reapresentação;
- validação/remediação;
- alterações de permissões;
- ações de IA que produzam sugestão material;
- processamento/integridade de documento;
- integrações relevantes.

## 8. Snapshot/hash

Análises e pacotes materiais devem apontar para o contexto exato utilizado. O hash de contexto impede usar uma análise antiga depois de alteração material.

## 9. Auditoria de IA

Registrar quando aplicável:
- provedor/modelo;
- versão de prompt/motor;
- entrada/snapshot ou hash;
- saída estruturada;
- timestamp;
- status/erro sanitizado;
- revisão humana.

## 10. Cadeia de evidência de arquivo

Preservar SHA-256, bucket/path, nome original, MIME/tamanho, origem, versão, ator e estado de segurança/processamento. Correção não apaga a versão original.

## 11. QA do pacote 4.1

O pacote 4.1 corrigiu a lacuna de cobertura da arquitetura anterior e consolidou:
- 84/84 RF;
- 12/12 NFR;
- 96/96 total;
- 28/28 épicos;
- 38/38 telas do catálogo original;
- 14 superfícies adicionais especificadas;
- prompts de construção/teste e caderno atômico.

A certificação do pacote dizia “coberto pela especificação”, não “código executado”. Posteriormente, o backend HML foi executado e certificado; isso não elimina a necessidade de seguir a especificação ao construir o frontend.

## 12. Manifesto SHA do pacote

O pacote usado na certificação possui SHA-256 externo registrado no certificado do backend. Os hashes não autorreferentes do manifesto foram verificados. O hash autorreferente do próprio manifesto é uma exceção documental inerente e não altera regras do produto.

## 13. Rastreabilidade complementar da identidade visual

A Identidade Visual Oficial **ContaOS Brand v1.0** é uma fonte complementar versionada, destinada exclusivamente à camada visual.

A rastreabilidade dessa camada deve preservar:
- versão da marca;
- pacote oficial de assets;
- Manual de Identidade Visual;
- `PROMPT 000 / BRAND-01` integral;
- hash dos assets oficiais quando transportados entre pacotes/repositórios;
- arquivos frontend efetivamente alterados na implantação;
- evidências visuais 1440 / 1280 / 768 / 390;
- evidências de claro/escuro, favicon e PWA quando aplicável;
- resultado dos 72 itens do teste BRAND-01;
- diff GitHub comprovando ausência de backend/alteração funcional.

O BRAND-01 é **transversal e fora da contagem PRD 96/96**. A matriz original 001–096 permanece íntegra; a camada de marca deve ser registrada em matriz/anexo complementar, não pela criação de um requisito funcional 097.

Para a integração documental inicial da Brand v1.0, a prova exigida inclui preservação byte a byte dos assets oficiais no pacote mestre, preservação integral dos prompts 001–096 e ausência de alteração em Supabase/backend.
