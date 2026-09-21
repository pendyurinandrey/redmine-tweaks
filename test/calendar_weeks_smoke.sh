#!/usr/bin/env bash
# HTTP check of the "calendar weeks" feature against any running Redmine (needs curl):
#
#   test/calendar_weeks_smoke.sh <base_url> <login> <password>
#
# Adds the Calendar block to the account's "My page" if it is missing, then saves 1..5 (and invalid) week counts in the block
# settings and counts the week rows the block renders. The account's calendar setting is restored at the end, but the block
# itself stays on the page. Use a test account.
set -uo pipefail
BASE="${1:?usage: calendar_weeks_smoke.sh <base_url> <login> <password>}"; BASE="${BASE%/}"
LOGIN="${2:?login}"; PASSWORD="${3:?password}"
fails=0; J=$(mktemp); trap 'rm -f "$J"' EXIT
check() { if [ "$2" = 1 ]; then echo "PASS  $1"; else echo "FAIL  $1${3:+  ($3)}"; fails=$((fails + 1)); fi; }

tok=$(curl -sk -c "$J" -b "$J" "$BASE/login" | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//')
curl -sk -c "$J" -b "$J" -o /dev/null --data-urlencode "authenticity_token=$tok" --data-urlencode "username=$LOGIN" --data-urlencode "password=$PASSWORD" "$BASE/login"
page() { curl -sk -b "$J" -c "$J" "$BASE/my/page"; }
csrf() { page | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | sed 's/.*content="//;s/"$//'; }
post() { curl -sk -b "$J" -c "$J" -o /dev/null -w '%{http_code}' -X POST -H "X-CSRF-Token: $(csrf)" -H 'X-Requested-With: XMLHttpRequest' -H 'Accept: text/javascript' "$@"; }
weeks_rendered() { page | grep -o 'class="label-week"' | wc -l | tr -d ' '; }
selected() { page | grep -o '<option selected="selected" value="[0-9]*">' | head -1 | grep -o 'value="[0-9]*"' | grep -o '[0-9]*'; }

echo "== the Calendar block"
page | grep -q 'id="block-calendar"' || post --data-urlencode block=calendar "$BASE/my/add_block" >/dev/null
check "the Calendar block is on My page" $(page | grep -q 'id="block-calendar"' && echo 1 || echo 0)
page | grep -q 'id="block-calendar-settings"\|id="calendar-settings"' && has_form=1 || has_form=0
check "the block has the weeks settings form (Options)" $has_form
original=$(selected); original=${original:-1}

echo "== number of weeks"
for n in 1 2 3 4 5; do
  c=$(post --data-urlencode "settings[calendar][weeks]=$n" "$BASE/my/page")
  check "weeks=$n saved (HTTP $c), block renders $n week row(s), the form shows $n selected" $([ "$(weeks_rendered)" = "$n" ] && [ "$(selected)" = "$n" ] && echo 1 || echo 0) "rows=$(weeks_rendered) selected=$(selected)"
done
echo "== invalid values are clamped"
post --data-urlencode "settings[calendar][weeks]=9" "$BASE/my/page" >/dev/null;   check "weeks=9 -> 5 rows" $([ "$(weeks_rendered)" = 5 ] && echo 1 || echo 0) "rows=$(weeks_rendered)"
post --data-urlencode "settings[calendar][weeks]=0" "$BASE/my/page" >/dev/null;   check "weeks=0 -> 1 row" $([ "$(weeks_rendered)" = 1 ] && echo 1 || echo 0) "rows=$(weeks_rendered)"
post --data-urlencode "settings[calendar][weeks]=abc" "$BASE/my/page" >/dev/null; check "weeks=abc -> 1 row" $([ "$(weeks_rendered)" = 1 ] && echo 1 || echo 0) "rows=$(weeks_rendered)"

post --data-urlencode "settings[calendar][weeks]=$original" "$BASE/my/page" >/dev/null
echo; [ "$fails" = 0 ] && echo "ALL CHECKS PASSED" || echo "FAILED checks: $fails"; exit $((fails > 0))
