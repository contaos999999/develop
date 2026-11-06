# Recuperação das fontes históricas efetivamente aplicadas no HML
Escopo: pré-requisito do plano único V1 autorizado pelo titular. Nenhuma DDL HML, reparo de histórico ou PROD nesta recuperação.
## Falha real e causa
Deploy RBAC run42147436000/job127662230436 abortou ANTES de db push:50 versões locais pendentes. A regra funcionou em modo fechado.
Consulta HML encontrou125 versões, enquanto a árvore antiga tinha122 arquivos:49 aliases locais divergentes e52 registros remotos sem arquivo com o timestamp real.
O PR74 regularizou somente o caso histórico68; não era prova de paridade global de todos os legados.
## Correção concreta sem reaplicação
-49 arquivos aliases arquivados em supabase/legacy-migrations com bytes e hashes preservados.
-52 arquivos recuperados com version/name/statements originais do HML. Não são migrações novas, timestamps inventados ou reescrita do SQL aplicado.
-73 versões já coincidentes preservadas byte a byte.72 têm tokens idênticos;20261102125242 difere apenas por booleanos equivalentes (ativo NOT NULL) e AS opcional de alias. Nenhum conteúdo desses73 foi substituído.
-Os aliases14510/14520 nunca tiveram registro aplicado; permanecem somente no arquivo histórico, sem marcação falsa de aplicação.
-O V105 de campos PRD e quatro históricos V1-22 antes ausentes são recuperados do histórico real.
-Checkpoint materialize passa a representar125 versões reais; RBAC20261106014102 permanece a única versão nova pretendida.
-Manifesto fechado: supabase/applied-history/hml-source-recovery-20261106.json, hashes individuais da origem e dos arquivos.
Origem local hml-history.json SHA256128370ec501ff78b5c376c7b12cf2c997391a82a67b2bb51398d046c4eaf4aae, sem padrões de segredo;125 versões únicas.
## Gates
Revisão independente da recuperação concluída: preservar SQL literal HML, inclusive coalesce(b.codigo,'') da V116 e diferenças históricas.
SQL dinâmico recuperado somente nos3 hashes exatos revisados:50438,51019,54126. DDL guiado por catálogo, schema delimitado e identificadores %I; nenhuma entrada de usuário. Guard rejeita alteração desses bytes; nenhuma exceção por pasta ou regex.
Gate de integridade verifica125 versões e49 originais arquivados. Quatro testes locais PASS: íntegro, SQL adulterado rejeitado, arquivo perdido rejeitado, alias reintroduzido rejeitado.
Restore do zero e13 suítes devem passar antes do merge. Comparação adicional com baseline real HML:120 tabelas,1520 colunas,284 contratos/ACLs de funções,186 políticas originais. Exclui somente os novos objetos/políticas RBAC explícitos.
Este comparador é estrutural, não prova igualdade integral dos corpos nem substitui JWT real.
## Próxima ação
Somente após CI/restore/comparação de catálogo verdes e merge, reexecutar o job de deploy canônico falho. Ele deve encontrar APENAS20261106014102 pendente. Qualquer divergência mantém bloqueio.
Não executar migration repair, INSERT no histórico, apply_migration ou reaplicar DDL legado.
Depois: pós-verificação/advisors, JWT real RBAC, Edge upload, frontend e demais etapas do plano único. V1 NÃO certificada.
## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Sem UI ou mudança de marca. Ferramentas diretas; preservar gates, fontes, testes e tipos. Sem novo serviço pago.
