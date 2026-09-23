#!/usr/bin/env bash
# HTTP check of the "not planned" issue filter against any running Redmine (needs curl, python3):
#
#   test/not_planned_filter_smoke.sh <base_url> <api_key> <project_id_or_identifier>
#
# Uses the REST API (issues.json) with the same filter params a saved query would send. Does not create or change
# any data; point it at a project whose issues already cover: both dates set, only start date, only due date,
# neither date, and (ideally) a closed issue with neither date.
set -uo pipefail
BASE="${1:?usage: not_planned_filter_smoke.sh <base_url> <api_key> <project>}"; BASE="${BASE%/}"
KEY="${2:?API key}"; PROJECT="${3:?project id or identifier}"
fails=0
check() { if [ "$2" = 1 ]; then echo "PASS  $1"; else echo "FAIL  $1${3:+  ($3)}"; fails=$((fails + 1)); fi; }

# base_query <status_op> <not_planned_op> <values...> -> JSON on stdout
base_query() {
  local status_op="$1" np_op="$2"; shift 2
  local url="$BASE/projects/$PROJECT/issues.json?set_filter=1&f%5B%5D=status_id&op%5Bstatus_id%5D=$status_op&f%5B%5D=not_planned&op%5Bnot_planned%5D=$np_op"
  for v in "$@"; do url="$url&v%5Bnot_planned%5D%5B%5D=$v"; done
  curl -sk -H "X-Redmine-API-Key: $KEY" "$url"
}
count() { base_query "$@" | python3 -c "import json,sys; print(json.load(sys.stdin)['total_count'])"; }
has() { # has <status_op> <not_planned_op> <values...> -- <subject>   (subject after a literal --)
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  base_query "${args[@]}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(1 if any(i['subject']=='$1' for i in d['issues']) else 0)"
}

echo "== filter is offered / API reachable"
ok=$(curl -sk -H "X-Redmine-API-Key: $KEY" "$BASE/projects/$PROJECT/issues.json?set_filter=1" | python3 -c "import json,sys; json.load(sys.stdin); print(1)" 2>/dev/null || echo 0)
check "issues.json responds with valid JSON for this project and key" "$ok"

echo "== is Yes / is No add up (status = any)"
yes=$(count '*' '='  1); no=$(count '*' '=' 0); both=$(count '*' '=' 1 0); neither=$(count '*' '!' 1 0)
echo "  is Yes=$yes  is No=$no  is Yes-or-No=$both  is neither=$neither"
check '"is Yes" + "is No" = "is Yes,No" (every issue falls in exactly one side)' $([ $((yes + no)) = "$both" ] && echo 1 || echo 0) "$yes + $no != $both"
check '"is not Yes,No" matches nothing (De Morgan of the same clause)' $([ "$neither" = 0 ] && [ "$both" -gt 0 ] && echo 1 || echo 0) "neither=$neither both=$both"

echo "== specific issues (status = any)"
check 'no start date -> "Yes" (not planned)'    "$(has '*' '=' 1 -- 'NP no start')"
check 'no due date -> "Yes" (not planned)'      "$(has '*' '=' 1 -- 'NP no due')"
check 'neither date -> "Yes" (not planned)'     "$(has '*' '=' 1 -- 'NP both dates')"
check 'closed, no dates -> "Yes" (not planned)' "$(has '*' '=' 1 -- 'NP closed no dates')"
check 'both dates set -> NOT under "Yes"'       "$([ "$(has '*' '=' 1 -- 'NP planned')" = 0 ] && echo 1 || echo 0)"
check 'both dates set -> under "No" (planned)'  "$(has '*' '=' 0 -- 'NP planned')"

echo "== combines with Status = open (AND, as usual)"
check 'a closed not-planned issue is excluded when status = open' "$([ "$(has 'o' '=' 1 -- 'NP closed no dates')" = 0 ] && echo 1 || echo 0)"
check 'the same issue is included when status = any'              "$(has '*' '=' 1 -- 'NP closed no dates')"

echo; [ "$fails" = 0 ] && echo "ALL CHECKS PASSED" || echo "FAILED checks: $fails"; exit $((fails > 0))
