-- ContaOS HML 4.1 - hardening de privilégio do trigger de onboarding Auth
-- A função privado.criar_usuario_auth() é executada exclusivamente pelo trigger em auth.users.
-- Usuários autenticados não precisam de EXECUTE direto nessa trigger function.

revoke execute on function privado.criar_usuario_auth() from authenticated;
