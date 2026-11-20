# shellcheck shell=bash
admin=$1
url=http://127.0.0.1:$PORT/api/setup
fail() { echo "zipline admin bootstrap: $1" >&2; exit 1; }

# Nothing from an answer may reach the journal, not even jq's errors about it.
request() {
  body=$(curl --silent --noproxy '*' --max-time 5 --write-out '%{http_code}' "$@" "$url") || return
  status=${body: -3}
  body=${body%"$status"}
}

until request && [[ $status != 5* ]]; do
  ((SECONDS < 60)) || fail "Zipline not ready after 60 seconds"
  sleep 0.5
done

# Zipline refuses setup once it has an admin: every start but the first.
if [[ $status == 403 ]] && jq -e '.code == 9001' <<<"$body" &>/dev/null; then exit 0; fi
if [[ $status != 200 ]] || ! jq -e '.firstSetup == true' <<<"$body" &>/dev/null; then
  fail "unexpected answer to GET /api/setup (HTTP $status)"
fi
request --json @"$admin" || fail "no answer to POST /api/setup"
[[ $status == 200 ]] || fail "setup refused (HTTP $status)"
jq -e --slurpfile admin "$admin" '.firstSetup == false and .user.username == $admin[0].username and .user.role == "SUPERADMIN"' \
  <<<"$body" &>/dev/null || fail "setup returned an unexpected admin"
