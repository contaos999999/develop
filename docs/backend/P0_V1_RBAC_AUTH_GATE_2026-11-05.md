# GATE P0 V1: prova autenticada baseline

PLAN #50 integrado com Zero-Drift 42103701903 SUCCESS, HEAD 8bbaca4466557743aa960eea2615d676f1c2de55, merge 2eea1f137eec33e4b006ca544fa5c9a3856899dc.

Decisão técnica: PASS do escopo de teste, condicionado ao CI deste GATE. Autorização expressa do titular cobre provas reais HML. Somente identidades/organizações/contratos sintéticos próprios com prefixo p0rbac-. Nenhuma conta real, configuração Auth, DDL, RLS ou grant pode mudar. O SQL de fixtures não simula tokens: tokens devem vir de login HTTP real. Cleanup revoga sessões antes de excluir fixtures e preserva auditoria. Confirmação independente de zero usuários/organizações/contratos sintéticos restantes é obrigatória.

Provas: MASTER sem vínculo acessa A/B; cada um dos dez perfis acessa somente A; permissões administrativas e de auditoria conforme backend; cadastro contratante autorizado apenas para administrador/gestor/MASTER; escrita negada não pode produzir efeito. Organização B, UUID não autorizado, token inválido, usuário sem vínculo, user_metadata forjado, revogação de vínculo/sessão e remoção de escopo devem negar. Exibir apenas asserts e códigos sanitizados. Não registrar senha/JWT/refresh token/IDs de dados reais.

Esta etapa testa o baseline, não implementa nem certifica a matriz granular. O BUILD RBAC continua sujeito a manifesto dedicado, RED/GREEN, restore e gates.

## ZERO-DRIFT — IDENTIDADE VISUAL + ECONOMIA LOVABLE
Impacto visual N/A: teste backend sem UI/assets. ContaOS Brand v1.0 preservada. GitHub/Supabase diretos e script Python padrão sem novo SaaS ou BUILD Lovable. Manter TDD, segurança, CI e evidência; PROD proibida; V1 não certificada.
