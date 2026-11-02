# ContaOS Brand v1.0 — Fonte Oficial de Identidade Visual

Esta pasta registra a integração de governança da **Identidade Visual Oficial ContaOS Brand v1.0** ao projeto ContaOS Arquitetura 4.1.

## Autoridade

- **ContaOS Arquitetura 4.1** continua sendo a fonte de verdade para PRD, premissas, arquitetura, Design System estrutural, UX funcional, componentes funcionais, layout estrutural, navegação, comportamento, acessibilidade, responsividade, segurança, backend, banco e regras de negócio.
- **ContaOS Brand v1.0** é a fonte de verdade exclusivamente para identidade visual: logomarca, símbolo, favicon, PWA, variações horizontal/vertical, claro/escuro, monocromático, paleta, proporções, proteção e tamanhos mínimos.
- Em conflito entre estética e comportamento/arquitetura, **o pacote 4.1 prevalece**.

## PROMPT 000

A fonte canônica integral de execução é:

`/00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md`

O PROMPT 000 / BRAND-01 é transversal e exclusivamente visual. O caderno operacional passa de 001–096 para **000–096**, mas a certificação PRD continua **96/96**. O PROMPT 000 não é requisito funcional 097.

## Fonte dos assets

Arquivo oficial recebido:

`ContaOS_Marca_Oficial_v1.0_FINAL.zip`

SHA-256 do ZIP recebido nesta integração:

`f26337dd0c5a217f5e51c3920625fecab0a91d79fdad5ab876459401a2d8b371`

O manifesto de todos os 50 arquivos está em:

`docs/brand/MANIFEST_SHA256_ContaOS_Brand_v1_0.txt`

Os assets completos, Manual de Identidade Visual e arquivos de implementação Lovable são incorporados ao **Pacote Mestre 4.1 + Brand v1.0**, sob `12_MARCA_OFICIAL/ContaOS_Marca_Oficial_v1.0/`, preservados byte a byte em relação ao pacote oficial recebido.

## Regra para implementação frontend

Antes de qualquer tarefa visual:

1. ler `00_AI_LEIA_ANTES_DE_ALTERAR.md`;
2. ler `00_BRAND_01_IDENTIDADE_VISUAL_OFICIAL.md` integralmente;
3. ler o contexto 4.1 e o estado HML vigente;
4. analisar Design System/tokens/layout existentes;
5. executar PLAN do BRAND-01 sem editar arquivos;
6. somente após aprovação, executar BUILD visual mínimo;
7. executar a fase TESTE read-only com os 72 itens do PROMPT 000;
8. revisar Git diff e confirmar ausência de backend/alteração funcional.

## Proibições

BRAND-01 não autoriza alteração de:
- Supabase;
- tabelas;
- migrations;
- RLS;
- grants;
- RPCs/Database Functions;
- Edge Functions;
- Auth;
- cliente Supabase;
- variáveis de ambiente;
- integrações;
- rotas;
- RBAC/permissões;
- regras de negócio;
- status;
- cálculos;
- estrutura de dados;
- conteúdo funcional das telas.

Qualquer necessidade além da camada visual deve ser reportada como **LACUNA ou CONFLITO**.
