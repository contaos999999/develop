# ContaOS 4.1 — Zero-Drift e Governança de Alterações

Consolidação de `ZeroDrift_v2_Lovable_Supabase.docx`, `README_ZERO_DRIFT.md` e controles instalados no repositório.

## 1. Objetivo

Impedir que uma tarefa localizada altere arquitetura, domínio, segurança ou comportamento fora do escopo. Quanto mais crítica a regra, menos ela deve depender da memória do chat.

## 2. Camadas de proteção

- documentos canônicos na raiz;
- `AGENTS.md` e instruções por agente;
- `docs/tasks/active-task.json`;
- allowed/forbidden paths;
- autorização explícita para banco/RLS/Edge/Auth;
- Plan Mode antes do Build;
- migrations versionadas e imutáveis;
- testes separados;
- revisão de diff;
- Architecture Guard;
- scan de secrets;
- CI Zero-Drift;
- restore/reprodutibilidade;
- revisão humana.

## 3. Regras absolutas

1. uma tarefa deve ter objetivo delimitado;
2. não refatorar fora do objetivo;
3. mudança de banco exige autorização explícita;
4. mudança de RLS exige autorização explícita;
5. Auth/cliente Supabase/governança não são alterados em tarefa comum;
6. prompt funcional não pode afrouxar Zero-Drift;
7. frontend não é autoridade de segurança;
8. nenhum secret no browser;
9. nenhum portão crítico em React;
10. nenhum update genérico de status crítico;
11. documentos/evidências em Storage privado;
12. migration aplicada não é reescrita;
13. falha de teste não autoriza corrigir componente não relacionado.

## 4. Ciclo obrigatório

1. ler integralmente o contexto raiz 00–18, incluindo as quatro partes 08A–08D da matriz 96/96;
2. ler `active-task.json`;
3. inspecionar código/banco relacionado;
4. elaborar plano mínimo;
5. verificar se banco/RLS/RPC/Edge/Auth serão tocados;
6. obter autorização conforme manifesto;
7. executar Build mínimo;
8. rodar testes sem autoexpansão de escopo;
9. auditar diff;
10. validar migrations;
11. scan de secrets/segurança;
12. CI;
13. evidência de aceite;
14. concluir tarefa.

## 5. Sinais clássicos de drift

- tabela não pedida;
- coluna/status “mais simples” inventado;
- policy afrouxada para teste passar;
- bucket tornado público;
- secret usado no frontend;
- botão React alterando status crítico;
- migration antiga editada;
- correção de bug diferente “aproveitando a oportunidade”;
- alteração em PROD durante HML;
- precedente transversal entrando no portão;
- texto oficial alterado;
- novo backend ou serviço de estado paralelo;
- remoção de auditoria/hash/versionamento para simplificar.

## 6. Manifesto de tarefa

Toda tarefa que altere implementação deve registrar no `active-task.json`, no mínimo:
- id/título/status;
- contexto 4.1 lido e fingerprint atual;
- arquivos permitidos/proibidos;
- flags de autorização de DB/RLS/Edge/Auth;
- objetos aprovados;
- critérios de aceite;
- testes obrigatórios.

## 7. Context Gate

O repositório deve manter um gate automatizado que:
- confirma presença de todos os documentos canônicos, incluindo 08A–08D;
- calcula fingerprint SHA-256 do conjunto;
- exige declaração de leitura do contexto em tarefa ativa quando houver alteração de implementação;
- bloqueia alteração de implementação usando manifesto desatualizado;
- permite atualização controlada dos próprios documentos de governança sem exigir falsa declaração de uma tarefa funcional.

O gate não prova biologicamente que uma IA “leu”, mas transforma a leitura em obrigação explícita, verificável e ligada ao hash da versão do contexto.

## 8. Critério final

O agente pode propor. O manifesto autoriza. RLS limita. RPC protege. O diff revela. O teste prova. O CI bloqueia. O humano decide.
