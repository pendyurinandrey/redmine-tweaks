#!/usr/bin/env bash
# HTTP check of the "start page" feature against any running Redmine (needs curl):
#
#   test/start_page_smoke.sh <base_url> <login> <password>
#
# Logs in with the given account (any user) and checks that `/` sends a logged-in user to "My page", while
# "My page" itself, robots.txt and the login page are not affected. Do not run it against an account you cannot type
# the password of on the command line (it ends up in the shell history): use a test account or `read -rs`.
set -uo pipefail
BASE="${1:?usage: start_page_smoke.sh <base_url> <login> <password>}"; BASE="${BASE%/}"
LOGIN="${2:?login}"; PASSWORD="${3:?password}"
fails=0; J=$(mktemp); trap 'rm -f "$J"' EXIT
check() { if [ "$2" = 1 ]; then echo "PASS  $1"; else echo "FAIL  $1${3:+  ($3)}"; fails=$((fails + 1)); fi; }
code_and_location() { curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' "$@"; }

echo "== anonymous"
r=$(code_and_location "$BASE/")
case "$r" in
  200*)     check "anonymous / -> ordinary home page (the site allows anonymous access)" 1 ;;
  302*login*) check "anonymous / -> login page (the site requires login)" 1 ;;
  *)        check "anonymous / -> home page or login page" 0 "$r" ;;
esac

echo "== logged-in user"
tok=$(curl -sk -c "$J" -b "$J" "$BASE/login" | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//')
r=$(code_and_location -c "$J" -b "$J" --data-urlencode "authenticity_token=$tok" --data-urlencode "username=$LOGIN" --data-urlencode "password=$PASSWORD" "$BASE/login")
check "login works and lands on My page (Redmine core)" $([ "${r%% *}" = 302 ] && [[ "$r" == *"/my/page" ]] && echo 1 || echo 0) "$r"
r=$(code_and_location -b "$J" "$BASE/")
check "GET / -> 302 to /my/page" $([ "${r%% *}" = 302 ] && [[ "$r" == *"/my/page" ]] && echo 1 || echo 0) "$r"
r=$(code_and_location -b "$J" "$BASE/my/page")
check "GET /my/page -> 200 (not redirected)" $([ "${r%% *}" = 200 ] && echo 1 || echo 0) "$r"
title=$(curl -skL -b "$J" "$BASE/" | grep -o '<title>[^<]*</title>' | head -1)
check "following the redirect from / shows the My page (title: $title)" $([[ "$title" == *"My page"* || "$title" == *"Моя страница"* ]] && echo 1 || echo 0) "$title"
r=$(code_and_location -b "$J" "$BASE/robots.txt")
check "robots.txt is not affected -> 200" $([ "${r%% *}" = 200 ] && echo 1 || echo 0) "$r"

echo; [ "$fails" = 0 ] && echo "ALL CHECKS PASSED" || echo "FAILED checks: $fails"; exit $((fails > 0))
