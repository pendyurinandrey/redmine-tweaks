#!/usr/bin/env bash
# HTTP check of the "operational plan" My page widget against any running Redmine (needs curl, python3):
#
#   test/roadmap_widget_smoke.sh <base_url> <login> <password>
#
# Adds the block if missing, exercises its settings (project filter, show-completed), restores them at the end.
# Structure checks only; the specific versions depend on your data (see the README checklist).
set -uo pipefail
BASE="${1:?usage: roadmap_widget_smoke.sh <base_url> <login> <password>}"; BASE="${BASE%/}"
LOGIN="${2:?login}"; PASSWORD="${3:?password}"
fails=0; J=$(mktemp); trap 'rm -f "$J"' EXIT
check() { if [ "$2" = 1 ]; then echo "PASS  $1"; else echo "FAIL  $1${3:+  ($3)}"; fails=$((fails + 1)); fi; }

tok=$(curl -sk -c "$J" -b "$J" "$BASE/login" | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"$//')
curl -sk -c "$J" -b "$J" -o /dev/null --data-urlencode "authenticity_token=$tok" --data-urlencode "username=$LOGIN" --data-urlencode "password=$PASSWORD" "$BASE/login"
page() { curl -sk -b "$J" -c "$J" "$BASE/my/page"; }
csrf() { page | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | sed 's/.*content="//;s/"$//'; }
post() { curl -sk -b "$J" -c "$J" -o /dev/null -w '%{http_code}' -X POST -H "X-CSRF-Token: $(csrf)" -H 'X-Requested-With: XMLHttpRequest' -H 'Accept: text/javascript' "$@"; }
save() { post --data-urlencode "settings[roadmap][project_id]=$1" --data-urlencode "settings[roadmap][show_completed]=$2" "$BASE/my/page" >/dev/null; }
versions() { page | grep -o '<h4 class="icon icon-package version[^"]*"[^>]*>.*</h4>' | grep -o 'title="[^"]*"' | sed 's/title="//;s/"$//'; }
badges() { page | grep -c 'badge-status-'; }

echo "== the block"
page | grep -q 'id="block-roadmap"' || post --data-urlencode block=roadmap "$BASE/my/add_block" >/dev/null
check "the block is on My page" $(page | grep -q 'id="block-roadmap"' && echo 1 || echo 0)
check "it is offered in the Add list" $(page | grep -Eq '<option[^>]*>(Оперативный план|Operational plan)' && echo 1 || echo 0)

echo "== default: all projects, open only"
save "" 0
n_open=$(badges)
check "at least one open version is shown" $([ "$n_open" -gt 0 ] && echo 1 || echo 0) "badges=$n_open"
check "a closed version is not shown by default" $([ "$(page | grep -c 'badge-status-closed')" = 0 ] && echo 1 || echo 0)

echo "== show completed"
save "" 1
check "with 'show completed' a closed version appears" $([ "$(page | grep -c 'badge-status-closed')" -gt 0 ] && echo 1 || echo 0)
n_all=$(badges)
check "showing completed shows at least as many versions as open-only" $([ "$n_all" -ge "$n_open" ] && echo 1 || echo 0) "all=$n_all open=$n_open"

echo "== project filter"
pid=$(page | grep -A5 'id="roadmap-project"' | grep -o '<option value="[0-9][0-9]*">' | head -1 | grep -o '[0-9][0-9]*')
if [ -n "$pid" ]; then
  save "$pid" 1
  n_one=$(badges)
  check "filtering to one project shows no more versions than 'all'" $([ "$n_one" -le "$n_all" ] && echo 1 || echo 0) "one=$n_one all=$n_all"
else
  check "a project is offered in the filter" 0 "no <option value=\"N\"> found in #roadmap-project"
fi
save "" 1   # back to 'all projects' before the checks below

echo "== compact: no per-issue table, links to the version's own page work"
check "no per-version issue table (compact)" $([ "$(page | grep -c 'class=\"list related-issues\"')" = 0 ] && echo 1 || echo 0)
link=$(page | grep -o 'href="/versions/[0-9]*"' | head -1 | sed 's/href="//;s/"$//')
if [ -n "$link" ]; then
  code=$(curl -sk -b "$J" -o /dev/null -w '%{http_code}' "$BASE$link"); check "a version's own link opens (200)" $([ "$code" = 200 ] && echo 1 || echo 0) "$code"
else
  check "a version link is present" 0
fi

save "" 0
echo; [ "$fails" = 0 ] && echo "ALL CHECKS PASSED" || echo "FAILED checks: $fails"; exit $((fails > 0))
