#!/bin/sh
# Railway wrapper for OxiCloud.
# 1. Sets Railway-friendly defaults (port, bind address, public URL, small
#    thread and connection pools so it fits a 0.5 GB service).
# 2. Waits for PostgreSQL, then starts the upstream entrypoint (which fixes
#    volume ownership and drops to the unprivileged "oxicloud" user).
# 3. On the very first boot, creates the admin account from
#    OXICLOUD_ADMIN_USERNAME / OXICLOUD_ADMIN_EMAIL / OXICLOUD_ADMIN_PASSWORD,
#    so no visitor can claim the instance through the setup page.
# 4. Exits non-zero whenever OxiCloud stops unexpectedly, so Railway's
#    ON_FAILURE restart policy brings it back.
set -u

log() { echo "[railway-start] $*"; }

# --- Defaults (any of these can be overridden with a Railway variable) ------
export OXICLOUD_SERVER_HOST="${OXICLOUD_SERVER_HOST:-0.0.0.0}"
export OXICLOUD_SERVER_PORT="${PORT:-${OXICLOUD_SERVER_PORT:-8086}}"
export OXICLOUD_STORAGE_PATH="${OXICLOUD_STORAGE_PATH:-/app/storage}"
if [ -z "${OXICLOUD_BASE_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export OXICLOUD_BASE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
export OXICLOUD_DISABLE_REGISTRATION="${OXICLOUD_DISABLE_REGISTRATION:-true}"
# Railway shows every host CPU inside a small service: size pools explicitly.
export OXICLOUD_WORKER_THREADS="${OXICLOUD_WORKER_THREADS:-2}"
export OXICLOUD_MAX_BLOCKING_THREADS="${OXICLOUD_MAX_BLOCKING_THREADS:-8}"
export OXICLOUD_THUMBNAIL_DECODE_CONCURRENCY="${OXICLOUD_THUMBNAIL_DECODE_CONCURRENCY:-2}"
export OXICLOUD_FFMPEG_PATH="${OXICLOUD_FFMPEG_PATH:-/opt/railway/bin/ffmpeg}"
export OXICLOUD_VIDEO_THUMBNAIL_CONCURRENCY="${OXICLOUD_VIDEO_THUMBNAIL_CONCURRENCY:-1}"
export OXICLOUD_DB_MAX_CONNECTIONS="${OXICLOUD_DB_MAX_CONNECTIONS:-8}"
export OXICLOUD_DB_MIN_CONNECTIONS="${OXICLOUD_DB_MIN_CONNECTIONS:-1}"
export OXICLOUD_DB_MAINTENANCE_MAX_CONNECTIONS="${OXICLOUD_DB_MAINTENANCE_MAX_CONNECTIONS:-2}"
export OXICLOUD_DB_MAINTENANCE_MIN_CONNECTIONS="${OXICLOUD_DB_MAINTENANCE_MIN_CONNECTIONS:-1}"
export MIMALLOC_PURGE_DELAY="${MIMALLOC_PURGE_DELAY:-0}"
export MIMALLOC_ALLOW_LARGE_OS_PAGES="${MIMALLOC_ALLOW_LARGE_OS_PAGES:-0}"
export RUST_LOG="${RUST_LOG:-info}"

if [ -z "${OXICLOUD_DB_CONNECTION_STRING:-}" ]; then
  log "ERROR: OXICLOUD_DB_CONNECTION_STRING is not set (expected \${{Postgres.DATABASE_URL}})."
  exit 1
fi

# --- Wait for PostgreSQL (private DNS can lag for the first minute) --------
hostport=$(printf '%s' "$OXICLOUD_DB_CONNECTION_STRING" | sed -E 's#^[a-z]+://##; s#^[^@]*@##; s#[/?].*$##')
dbhost=${hostport%:*}
dbport=${hostport##*:}
[ "$dbport" = "$hostport" ] && dbport=5432
i=0
until nc -z -w 3 "$dbhost" "$dbport" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    log "PostgreSQL at $dbhost:$dbport is still not reachable after 3 minutes; starting anyway."
    break
  fi
  [ $((i % 5)) -eq 1 ] && log "waiting for PostgreSQL at $dbhost:$dbport ..."
  sleep 3
done

# --- Video-thumbnail temp folder (upstream 0.10.1 bug) ----------------------
# ffmpeg thumbnails write their temp file into <storage>/.thumbnails, but a
# fresh install has no such folder and the startup job thumb_derived_import
# deletes it whenever it is empty, so every video thumbnail fails with
# "temp file: No such file or directory". Remove it while empty before boot
# (keeps the legacy-sidecar fallback off) and recreate it once OxiCloud runs.
thumbs="$OXICLOUD_STORAGE_PATH/.thumbnails"
rmdir "$thumbs" 2>/dev/null || true
ensure_thumbs() {
  [ -d "$thumbs" ] && return 0
  mkdir -p "$thumbs" 2>/dev/null && chown "$(id -u oxicloud):$(id -g oxicloud)" "$thumbs" 2>/dev/null
  return 0
}

# --- Start OxiCloud ---------------------------------------------------------
stopping=0
child=0
on_term() {
  stopping=1
  [ "$child" -gt 0 ] && kill -TERM "$child" 2>/dev/null
}
trap on_term TERM INT

entrypoint.sh oxicloud &
child=$!
log "OxiCloud started (pid $child) on $OXICLOUD_SERVER_HOST:$OXICLOUD_SERVER_PORT"

base="http://127.0.0.1:${OXICLOUD_SERVER_PORT}"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

bootstrap_admin() {
  # Wait until the server answers.
  n=0
  until wget -q -T 5 -O /dev/null "$base/health" 2>/dev/null; do
    kill -0 "$child" 2>/dev/null || return 0
    n=$((n + 1))
    [ "$n" -ge 150 ] && { log "health endpoint never answered; skipping admin setup"; return 0; }
    sleep 2
  done
  cfg=$(wget -q -T 10 -O - "$base/api/config" 2>/dev/null || true)
  case "$cfg" in
    *'"initialized":true'*) log "instance already initialised; admin setup skipped"; return 0 ;;
    *'"initialized":false'*) ;;
    *) log "could not read /api/config; admin setup skipped"; return 0 ;;
  esac
  user="${OXICLOUD_ADMIN_USERNAME:-admin}"
  email="${OXICLOUD_ADMIN_EMAIL:-admin@example.com}"
  pass="${OXICLOUD_ADMIN_PASSWORD:-}"
  if [ "${#pass}" -lt 8 ]; then
    log "ERROR: OXICLOUD_ADMIN_PASSWORD must be set (8+ characters) for the first boot."
    return 1
  fi
  body=$(printf '{"username":"%s","email":"%s","password":"%s"}' \
    "$(json_escape "$user")" "$(json_escape "$email")" "$(json_escape "$pass")")
  out=$(wget -S -T 60 -O - --header 'Content-Type: application/json' \
    --post-data "$body" "$base/api/setup" 2>&1)
  case "$out" in
    *" 201 "*|*" 200 "*) log "admin account '$user' created" ; return 0 ;;
    *" 403 "*) log "instance was already initialised; admin setup skipped"; return 0 ;;
  esac
  log "ERROR: admin setup failed: $(printf '%s' "$out" | grep -E 'HTTP/|message|error' | head -3 | tr '\n' ' ')"
  return 1
}

if ! bootstrap_admin; then
  log "stopping: the instance must not stay open without an admin account"
  kill -TERM "$child" 2>/dev/null
  wait "$child" 2>/dev/null
  exit 1
fi

# --- Supervise: poll (BusyBox wait returns early on signals) ---------------
sleep 5
while kill -0 "$child" 2>/dev/null; do
  ensure_thumbs
  sleep 2
done
wait "$child"
code=$?
if [ "$stopping" -eq 1 ]; then
  log "stopped on request (exit $code)"
  exit 0
fi
[ "$code" -eq 0 ] && code=1
log "OxiCloud exited unexpectedly; exiting $code so Railway restarts it"
exit "$code"
