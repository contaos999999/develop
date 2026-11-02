# ContaOS 4.1 — Manual de Ambiente, HML e Promoção

Consolidação operacional de `Manual_ContaOS_v6_0_ZERO_CONHECIMENTO_Lovable_Supabase.docx`.

## 1. Ambientes

Existem dois projetos Supabase independentes:
- ContaOS HML: desenvolvimento, homologação, testes e frontend Lovable antes da produção;
- ContaOS PROD: ambiente real, preparado somente após homologação.

Nunca “transformar” HML em PROD. Promover artefatos versionados, não o banco com dados de teste.

## 2. Git

No arranjo atual:
- `contaos9999/develop`: repositório oficial do HML;
- `contaos9999/prod`: produção, intocada enquanto o HML não estiver aprovado.

Mudança deve ocorrer em tarefa/branch apropriada quando fluxo de branch estiver ativo. O estado atual do repositório deve ser conferido antes do Build.

## 3. Secrets

Nunca colocar em Git, Markdown operacional público, frontend ou log de usuário:
- senha PostgreSQL;
- service role/secret key;
- OpenAI API key;
- token interno entre workers;
- segredo de webhook;
- credencial SMTP/integração.

Segredos pertencem ao Supabase Secrets/Vault/configuração segura do ambiente.

## 4. Lovable

Antes de gerar frontend:
- confirmar Supabase conectado é HML;
- colar/incluir instruções permanentes de arquitetura e Zero-Drift;
- ler os documentos canônicos da raiz;
- usar Plan Mode antes do Build;
- não aceitar migration ou backend gerado “por conveniência” se backend já existe;
- não deixar Lovable criar backend paralelo;
- não permitir secret no React;
- não permitir lógica crítica de status no cliente.

## 5. Migrations

Regra operacional:
1. verificar migration/history atual;
2. migration aplicada é imutável;
3. correção gera nova migration;
4. evitar `DROP`, `TRUNCATE`, delete em massa ou mudança destrutiva sem plano específico;
5. validar RLS/grants/funções após DDL;
6. executar teste;
7. reconstruir banco limpo quando a mudança afetar reprodutibilidade;
8. manter GitHub e HML sincronizados.

## 6. Plan → Build → Test → Audit

Cada tarefa deve seguir:
1. reancorar contexto;
2. definir escopo e arquivos permitidos;
3. Plan Mode/planejamento sem editar;
4. revisar impacto em banco/RLS/RPC/Edge/Auth/Storage;
5. aprovar plano;
6. Build mínimo;
7. testes separados;
8. não “corrigir automaticamente” falhas fora do escopo;
9. revisar diff;
10. scan de segurança;
11. CI/Zero-Drift;
12. só então concluir.

## 7. Publicação HML

Antes de publicar frontend HML:
- branch/repositório corretos;
- Git sync sem divergência;
- Supabase HML confirmado;
- rotas privadas bloqueadas sem login;
- RLS testada;
- smoke test da jornada;
- erros em PT-BR;
- sem secrets no bundle;
- nenhum Critical em scan.

## 8. Preparação PROD

Somente depois de frontend + backend homologados:
- criar/configurar secrets PROD separadamente;
- revisar Auth redirect URLs e domínio;
- aplicar migrations homologadas em ordem;
- publicar Edge Functions homologadas;
- configurar Storage/policies;
- configurar Cron/Queues quando aplicável;
- revisar SMTP/integrações;
- revisar backup/PITR/RPO/RTO;
- executar restore test no contexto de produção;
- seed apenas de referência, nunca dados sintéticos de HML;
- smoke test PROD com usuário autorizado;
- rollback/reversão definidos.

## 9. Sinais de parada imediata

- Lovable conectado a PROD durante desenvolvimento;
- migration destrutiva inesperada;
- tabela sem RLS;
- usuário A vendo organização B;
- bucket tornado público;
- secret aparecendo no React/Git/log;
- Edge 401 “resolvido” desligando autenticação;
- update direto de status crítico;
- Git divergido;
- IA propondo tabela/status fora do PRD;
- Security Advisor/Critical não resolvido.
