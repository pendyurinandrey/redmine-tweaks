#!/usr/bin/env bash
# HTTP check of the "planned time" My page widget against any running Redmine (needs curl, python3):
#
#   test/planned_time_smoke.sh <base_url> <login> <password>
#
# Adds the block to the account's My page if missing and changes its settings (days, assignee, norm), restoring the
# original settings at the end. Structure checks only; the numbers depend on your data (see the README checklist).
# Use a test account.
set -uo pipefail
BASE="${1:?usage: planned_time_smoke.sh <base_url> <login> <password>}"; BASE="${BASE%/}"
LOGIN="${2:?login}"; PASSWORD="${3:?password}"
fails=0; J=$(mktemp); trap 'rm -f "$J"' EXIT
check() { if [ "$2" = 1 ]; then echo "PASS  $1"; else echo "FAIL  $1${3:+  ($3)}"; fails=$((fails + 1)); fi; }

tok=$(curl -sk -c "$J" -b "$J" "$BASE/login" | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//')
curl -sk -c "$J" -b "$J" -o /dev/null --data-urlencode "authenticity_token=$tok" --data-urlencode "username=$LOGIN" --data-urlencode "password=$PASSWORD" "$BASE/login"
page() { curl -sk -b "$J" -c "$J" "$BASE/my/page"; }
csrf() { page | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | sed 's/.*content="//;s/"$//'; }
post() { curl -sk -b "$J" -c "$J" -o /dev/null -w '%{http_code}' -X POST -H "X-CSRF-Token: $(csrf)" -H 'X-Requested-With: XMLHttpRequest' -H 'Accept: text/javascript' "$@"; }
save() { post --data-urlencode "settings[planned_time][days]=$1" --data-urlencode "settings[planned_time][assignee_id]=$2" \
              --data-urlencode "settings[planned_time][norm_enabled]=$3" --data-urlencode "settings[planned_time][norm_hours]=$4" "$BASE/my/page" >/dev/null; }
bars() { page | grep -o '<a class="rt-col' | wc -l | tr -d ' '; }
norm_lines() { page | grep -o 'class="rt-norm"' | wc -l | tr -d ' '; }

echo "== the block"
page | grep -q 'id="block-planned_time"' || post --data-urlencode block=planned_time "$BASE/my/add_block" >/dev/null
check "the block is on My page" $(page | grep -q 'id="block-planned_time"' && echo 1 || echo 0)
check "it is offered in the Add list" $(page | grep -Eq '<option[^>]*>(Запланированное время|Planned time)' && echo 1 || echo 0)
orig_days=$(page | grep -o 'data-rt-days="[0-9]*"' | grep -o '[0-9]*')

echo "== number of days"
save "" "" 1 8;  check "default: 7 bars"                 $([ "$(bars)" = 7 ]  && echo 1 || echo 0) "bars=$(bars)"
save 14 "" 1 8;   check "days=14 -> 14 bars"              $([ "$(bars)" = 14 ] && echo 1 || echo 0) "bars=$(bars)"
save 10 "" 1 8;   check "days=10 -> 10 bars"              $([ "$(bars)" = 10 ] && echo 1 || echo 0) "bars=$(bars)"
save 3 "" 1 8;    check "days=3 is clamped to 7"          $([ "$(bars)" = 7 ]  && echo 1 || echo 0) "bars=$(bars)"
save 99 "" 1 8;   check "days=99 is clamped to 14"        $([ "$(bars)" = 14 ] && echo 1 || echo 0) "bars=$(bars)"
save abc "" 1 8;  check "days=abc falls back to 7"        $([ "$(bars)" = 7 ]  && echo 1 || echo 0) "bars=$(bars)"

echo "== norm line"
save 7 "" 1 8;    check "norm on -> a norm line is drawn"     $([ "$(norm_lines)" = 1 ] && echo 1 || echo 0)
save 7 "" 0 8;    check "norm off -> no norm line"            $([ "$(norm_lines)" = 0 ] && echo 1 || echo 0)
save 7 "" 1 6,5;  check "norm 6,5 (comma) is accepted"        $(page | grep -q 'class="rt-norm" data-hours="6.5"' && echo 1 || echo 0)
save 7 "" 1 -3;   check "negative norm falls back to 8"       $(page | grep -Eq 'class="rt-norm" data-hours="8(\.0)?"' && echo 1 || echo 0)

echo "== bars link to the day's issues"
save 7 "" 1 8
link=$(page | grep -o '<a class="rt-col[^>]*href="[^"]*"' | head -1 | sed 's/.*href="//;s/"$//;s/&amp;/\&/g')
check "a bar links to the issue list with start/due date filters" $(echo "$link" | grep -q 'start_date' && echo "$link" | grep -q 'due_date' && echo 1 || echo 0) "$link"
code=$(curl -sk -b "$J" -o /dev/null -w '%{http_code}' "$BASE$link"); check "that link opens (200)" $([ "$code" = 200 ] && echo 1 || echo 0) "$code"

save "${orig_days:-7}" "" 1 8
echo; [ "$fails" = 0 ] && echo "ALL CHECKS PASSED" || echo "FAILED checks: $fails"; exit $((fails > 0))
