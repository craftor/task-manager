#!/usr/bin/env bash
# smoke_tablesdb.sh — verify all 6 TablesDB endpoints work against the
# self-hosted Appwrite instance. Used for pre-merge validation of the
# Databases → TablesDB migration.
#
# Two ways to authenticate:
#
#   A) Provide a session token directly (the opaque JWT-like value from
#      the `Set-Cookie: a_session_<projectId>=...` response of
#      POST /v1/account/sessions/email, NOT the session `$id` field):
#        APPWRITE_SESSION_TOKEN=... ./scripts/smoke_tablesdb.sh
#
#   B) Provide email + password; the script logs in and extracts the
#      cookie value automatically:
#        APPWRITE_EMAIL=... APPWRITE_PASSWORD=... ./scripts/smoke_tablesdb.sh
#
# Optional overrides: APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID,
#                     APPWRITE_DATABASE_ID.
#
# Exits 0 if every collection accepts upsertRow + getRow, and deletes the
# smoke row on exit (clean state). Exits 1 (with a per-endpoint report)
# if any endpoint fails.

# Disable errexit: we count failures and continue so one bad collection
# doesn't hide others.
set -u
set -o pipefail

ENDPOINT="${APPWRITE_ENDPOINT:-http://o.21up.cn:6080/v1}"
PROJECT_ID="${APPWRITE_PROJECT_ID:-6a20e0b10013cae75d20}"
DB_ID="${APPWRITE_DATABASE_ID:-6a20eeaa002f0f294ab9}"

# Appwrite 1.9+ requires the session via the `a_session_<projectId>` cookie.
# The cookie value is the JWT-like opaque session token, not the session
# `$id` from createSession. Appwrite SDKs set this on the client
# automatically; raw curl needs to do it by hand because the
# X-Appwrite-Session header alone is not honored on 1.9.
COOKIE_NAME="a_session_${PROJECT_ID}"

# Resolve SESSION: prefer explicit APPWRITE_SESSION_TOKEN; fall back to
# logging in with APPWRITE_EMAIL + APPWRITE_PASSWORD.
if [[ -z "${APPWRITE_SESSION_TOKEN:-}" ]]; then
  if [[ -n "${APPWRITE_EMAIL:-}" && -n "${APPWRITE_PASSWORD:-}" ]]; then
    echo "=== login: extracting session cookie from /account/sessions/email ==="
    raw=$(curl -sS -i -X POST "$ENDPOINT/account/sessions/email" \
      -H "X-Appwrite-Project: $PROJECT_ID" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$APPWRITE_EMAIL\",\"password\":\"$APPWRITE_PASSWORD\"}")
    status=$(printf '%s\n' "$raw" | head -1 | awk '{print $2}')
    if [[ "$status" != "201" ]]; then
      echo "login failed (HTTP $status):"
      printf '%s\n' "$raw" | head -20
      exit 2
    fi
    # Pull `a_session_<projectId>=<value>` out of the Set-Cookie header.
    # curl's -i output puts headers above a blank line; the cookie value
    # may be URL-encoded (contains %3D at the end). `cut -d= -f2-` keeps
    # any further `=` characters intact.
    SESSION=$(printf '%s\n' "$raw" \
      | tr -d '\r' \
      | grep -i "^set-cookie: $COOKIE_NAME=" \
      | head -1 \
      | sed -e "s/^[Ss]et-[Cc]ookie: $COOKIE_NAME=//" \
            -e 's/;.*$//')
    if [[ -z "$SESSION" ]]; then
      echo "login succeeded but no $COOKIE_NAME cookie in response"
      printf '%s\n' "$raw" | head -20
      exit 2
    fi
    echo "  got session (length=${#SESSION})"
  else
    echo "error: provide either APPWRITE_SESSION_TOKEN, or APPWRITE_EMAIL + APPWRITE_PASSWORD" >&2
    exit 2
  fi
else
  SESSION="$APPWRITE_SESSION_TOKEN"
fi

COOKIE_HEADER="Cookie: ${COOKIE_NAME}=${SESSION}"

# Synthetic user_id so the smoke row is invisible to the real user's
# user-scoped queries (every fetch filters by user_id; this row never
# matches). Appwrite's user_id column is a free-form string, not a
# foreign key, so any value is accepted.
SMOKE_USER_ID="smoke-$(date +%s)"
ROW_ID="smoke-$(date +%s)-$$"

COLLECTIONS=(projects tasks time_entries special_days moods journal_entries)

pass=0
fail=0
declare -a FAILED_COLLECTIONS=()

# Minimal payload per collection. Only the columns actually used by the
# app are set. Anything more is just noise for a smoke test.
payload_for() {
  case "$1" in
    projects)        printf '{"user_id":"%s","name":"smoke","color":"#fff","icon":"o"}' "$SMOKE_USER_ID" ;;
    tasks)           printf '{"user_id":"%s","project_id":"00000000-0000-0000-0000-000000000001","title":"smoke","priority":2,"status":0}' "$SMOKE_USER_ID" ;;
    time_entries)    printf '{"user_id":"%s","task_id":"%s","start_time":"2026-01-01T00:00:00Z"}' "$SMOKE_USER_ID" "$ROW_ID" ;;
    special_days)    printf '{"user_id":"%s","date_key":"2026-01-01","data":"{}"}' "$SMOKE_USER_ID" ;;
    moods)           printf '{"user_id":"%s","date_key":"2026-01-01","data":"[]"}' "$SMOKE_USER_ID" ;;
    journal_entries) printf '{"user_id":"%s","date_key":"2026-01-01","content":"smoke"}' "$SMOKE_USER_ID" ;;
  esac
}

cleanup() {
  echo
  echo "=== cleanup ==="
  for c in "${COLLECTIONS[@]}"; do
    code=$(curl -sS -o /dev/null -w "%{http_code}" \
      -X DELETE "$ENDPOINT/tablesdb/$DB_ID/tables/$c/rows/$ROW_ID" \
      -H "X-Appwrite-Project: $PROJECT_ID" \
      -H "$COOKIE_HEADER" || echo "ERR")
    if [[ "$code" =~ ^2 || "$code" == "404" ]]; then
      echo "  $c: deleted (HTTP $code)"
    else
      echo "  $c: cleanup failed (HTTP $code) — row $ROW_ID may remain"
    fi
  done
}
trap cleanup EXIT

check_endpoint() {
  local c=$1 method=$2
  local tmpf="/tmp/smoke-${c}.json"
  local http

  case "$method" in
    POST)
      http=$(curl -sS -o "$tmpf" -w "%{http_code}" \
        -X POST "$ENDPOINT/tablesdb/$DB_ID/tables/$c/rows" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "$COOKIE_HEADER" \
        -H "Content-Type: application/json" \
        -d "{\"rowId\":\"$ROW_ID\",\"data\":$(payload_for "$c")}")
      ;;
    GET)
      http=$(curl -sS -o "$tmpf" -w "%{http_code}" \
        "$ENDPOINT/tablesdb/$DB_ID/tables/$c/rows/$ROW_ID" \
        -H "X-Appwrite-Project: $PROJECT_ID" \
        -H "$COOKIE_HEADER")
      ;;
  esac

  if [[ "$http" =~ ^2 ]]; then
    echo "    $method: HTTP $http ✓"
    return 0
  else
    echo "    $method: HTTP $http ✗"
    echo "    body: $(head -c 200 "$tmpf")"
    return 1
  fi
}

echo "=== smoke_tablesdb ==="
echo "endpoint:   $ENDPOINT"
echo "project:    $PROJECT_ID"
echo "database:   $DB_ID"
echo "row_id:     $ROW_ID"
echo

for c in "${COLLECTIONS[@]}"; do
  echo "[$c]"
  ok=true
  check_endpoint "$c" POST || ok=false
  check_endpoint "$c" GET  || ok=false
  if $ok; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    FAILED_COLLECTIONS+=("$c")
  fi
  echo
done

echo "=== summary ==="
echo "passed: $pass / $((pass + fail))"
if [[ $fail -gt 0 ]]; then
  echo "failed: ${FAILED_COLLECTIONS[*]}"
  exit 1
fi
exit 0
