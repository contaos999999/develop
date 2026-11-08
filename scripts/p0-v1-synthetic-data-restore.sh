#!/usr/bin/env bash
# P0 V1 — restore LOCAL de uma linha sintética; não conectar HML/PROD.
set -Eeuo pipefail
umask 077

[[ "${GITHUB_ACTIONS:-}" == 'true' && "${GITHUB_REPOSITORY:-}" == 'contaos999999/develop' ]] || {
  echo '::error::Prova restrita ao runner canônico GitHub HML.' >&2; exit 2;
}
[[ -f supabase/config.toml && -f .github/workflows/restore-isolado.yml ]] || { echo '::error::Configuração local ausente.' >&2; exit 2; }
[[ -z "${DATABASE_URL:-}" && -z "${SUPABASE_DB_URL:-}" && -z "${SUPABASE_ACCESS_TOKEN:-}" ]] || { echo '::error::Variáveis remotas proibidas nesta prova.' >&2; exit 2; }
for bin in supabase docker psql sha256sum python3; do command -v "$bin" >/dev/null; done

readonly DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
readonly PROOF_DIR="$PWD/restore-proof-synthetic"
mkdir -p "$PROOF_DIR"
readonly TEMP_DIR="$(mktemp -d)"
started=0
complete=0

cleanup() {
  local result="$?"
  trap - EXIT
  if (( started )); then
    if bash scripts/isolated-db-network.sh run stop --no-backup > "$PROOF_DIR/cleanup.log" 2>&1; then
      started=0
    else
      echo '::error::Falha ao parar instância local; não limpar temporários.' >&2
      result=1
    fi
  fi
  # Artefatos publicados ficam somente com hashes e contagens, inclusive no FAIL.
  rm -f -- "$PROOF_DIR/row-source.txt" "$PROOF_DIR/row-destination.txt" "$PROOF_DIR/archive-toc.txt"
  if (( result == 0 && complete == 1 && started == 0 )); then
    printf 'status=PASS_LOCAL_SYNTHETIC_RESTORE\n' >> "$PROOF_DIR/result.txt"
    rm -rf -- "$TEMP_DIR"
  else
    printf 'status=FAIL_OR_INCOMPLETE\n' >> "$PROOF_DIR/result.txt"
    echo '::error::Backup/restore não certificado; relatório de diagnóstico registrado.' >&2
    [[ $result -ne 0 ]] || result=1
  fi
  exit "$result"
}
trap cleanup EXIT

container_id() {
  local -a ids=()
  mapfile -t ids < <(docker ps --format '{{.ID}} {{.Names}}' | awk '$2 ~ /^supabase_db_/ { print $1 }')
  if (( ${#ids[@]} != 1 )); then
    echo "::error::Esperado um único Postgres local, encontrados ${#ids[@]}." >&2
    return 1
  fi
  printf '%s' "${ids[0]}"
}
sql() { psql "$DB_URL" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
verify_base() {
  local label="$1" count
  count="$(sql 'select count(*) from public.organizacoes')"
  [[ "$count" =~ ^[0-9]+$ ]] || return 1
  sql 'select version from supabase_migrations.schema_migrations order by version' > "$PROOF_DIR/migrations-$label.txt"
  [[ "$(wc -l < "$PROOF_DIR/migrations-$label.txt")" -ge 120 ]] || { echo '::error::Migrations locais incompletas.' >&2; return 1; }
  sql "select relrowsecurity::text || ':' || relforcerowsecurity::text from pg_class where oid='public.organizacoes'::regclass" > "$PROOF_DIR/rls-$label.txt"
  grep -Fxq 'true:false' "$PROOF_DIR/rls-$label.txt" || grep -Fxq 't:f' "$PROOF_DIR/rls-$label.txt" || { echo '::error::RLS indisponível.' >&2; return 1; }
  printf '%s' "$count"
}

printf 'scope=LOCAL_GITHUB_ACTIONS_ONLY\nrepo=%s\nhead=%s\n' "$GITHUB_REPOSITORY" "${GITHUB_SHA:-unknown}" > "$PROOF_DIR/result.txt"

# Instância A: migrations canônicas e um registro próprio.
started=1
bash scripts/isolated-db-network.sh run db start
bash scripts/isolated-db-network.sh run db reset --local --no-seed
[[ "$(verify_base source)" == '0' ]] || { echo '::error::Origem deve estar vazia.' >&2; exit 1; }
first="$(container_id)"
probe_id="$(python3 -c 'import uuid;print(uuid.uuid4())')"
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -v probe_id="$probe_id" <<'SQL'
insert into public.organizacoes(id, razao_social)
values (:'probe_id'::uuid, 'P0 V1 BACKUP SINTETICO LOCAL SEM DADOS REAIS');
SQL
[[ "$(sql 'select count(*) from public.organizacoes')" == '1' ]] || { echo '::error::Origem não contém uma linha exata.' >&2; exit 1; }
sql "select id::text || '|' || razao_social from public.organizacoes order by id" > "$PROOF_DIR/row-source.txt"
grep -Fq "$probe_id" "$PROOF_DIR/row-source.txt" || exit 1
sha256sum "$PROOF_DIR/row-source.txt" | awk '{print $1}' > "$PROOF_DIR/row-source.sha256"

# pg_dump 17 dentro do container PostgreSQL local; archive não é publicado.
docker exec "$first" pg_dump -U postgres -d postgres -Fc --data-only --no-owner --no-acl --table=public.organizacoes > "$TEMP_DIR/synthetic.dump"
[[ -s "$TEMP_DIR/synthetic.dump" ]] || { echo '::error::Dump vazio.' >&2; exit 1; }
docker exec -i "$first" pg_restore --list < "$TEMP_DIR/synthetic.dump" > "$PROOF_DIR/archive-toc.txt"
grep -Eq 'TABLE DATA public organizacoes' "$PROOF_DIR/archive-toc.txt" || { echo '::error::Tabela inesperada no backup.' >&2; exit 1; }
[[ "$(grep -Ec 'TABLE DATA ' "$PROOF_DIR/archive-toc.txt")" == '1' ]] || { echo '::error::Backup contém mais de uma tabela.' >&2; exit 1; }
sha256sum "$TEMP_DIR/synthetic.dump" | awk '{print $1}' > "$PROOF_DIR/archive.sha256"

# Destruição real do container A e do volume local; nunca --remote/--linked.
bash scripts/isolated-db-network.sh run stop --no-backup
started=0
[[ -z "$(docker ps -q --no-trunc --filter "id=$first")" ]] || { echo '::error::Origem ainda ativa.' >&2; exit 1; }

# Instância B: container diferente, schema reconstruído do zero.
start_epoch="$(date +%s)"
started=1
bash scripts/isolated-db-network.sh run db start
bash scripts/isolated-db-network.sh run db reset --local --no-seed
# db reset pode recriar o container: resolver o ID somente DEPOIS do reset.
second="$(container_id)"
[[ "$second" != "$first" ]] || { echo '::error::Container antigo reutilizado.' >&2; exit 1; }
[[ "$(verify_base destination)" == '0' ]] || { echo '::error::Destino não está vazio.' >&2; exit 1; }
cmp -s "$PROOF_DIR/migrations-source.txt" "$PROOF_DIR/migrations-destination.txt" || { echo '::error::Migrations divergentes.' >&2; exit 1; }
cmp -s "$PROOF_DIR/rls-source.txt" "$PROOF_DIR/rls-destination.txt" || { echo '::error::RLS divergente.' >&2; exit 1; }
docker exec -i "$second" pg_restore -U postgres -d postgres --single-transaction --exit-on-error --no-owner --no-acl < "$TEMP_DIR/synthetic.dump"
[[ "$(sql 'select count(*) from public.organizacoes')" == '1' ]] || { echo '::error::Restore não retornou 1 linha.' >&2; exit 1; }
sql "select id::text || '|' || razao_social from public.organizacoes order by id" > "$PROOF_DIR/row-destination.txt"
sha256sum "$PROOF_DIR/row-destination.txt" | awk '{print $1}' > "$PROOF_DIR/row-destination.sha256"
cmp -s "$PROOF_DIR/row-source.sha256" "$PROOF_DIR/row-destination.sha256" || { echo '::error::Hash da linha mudou.' >&2; exit 1; }
[[ "$(sql "select count(*) from public.organizacoes where id='${probe_id}'::uuid")" == '1' ]] || { echo '::error::UUID divergente.' >&2; exit 1; }

printf 'rows_source=1\nrows_restored=1\nnew_container=yes\nmigrations_equal=yes\nrls_equal=yes\nrow_sha256_equal=yes\nseconds_recreate_and_restore=%s\nscope_not_RPO_RTO_PITR=1\n' "$(( $(date +%s) - start_epoch ))" >> "$PROOF_DIR/result.txt"
# Artefatos públicos contêm somente hashes/contagens; arquivo binário fica no TEMP_DIR.
rm -f "$PROOF_DIR/row-source.txt" "$PROOF_DIR/row-destination.txt" "$PROOF_DIR/archive-toc.txt"
complete=1
