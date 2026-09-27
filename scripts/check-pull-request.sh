#!/usr/bin/env bash
# Gate on how a pull request names its issue and its kind.
#
#   check-pull-request.sh < "$GITHUB_EVENT_PATH"
#
# Reads a `pull_request` event payload on stdin and exits 1, with a report,
# unless the pull request carries exactly one `kind:` label and its body
# names an issue with `Closes #n` or `Refs #n`. The label `no-issue` waives
# the reference, never the `kind:` label.
#
# Labels and body come from the payload, so the check makes no API call and
# needs no token.

set -uo pipefail

payload=$(cat)
mapfile -t labels < <(jq -r '.pull_request.labels[].name' <<<"$payload")
body=$(jq -r '.pull_request.body // ""' <<<"$payload")

problems=""
kinds=0 no_issue=false
for label in "${labels[@]}"; do
  [[ "$label" == kind:* ]] && kinds=$((kinds + 1))
  [[ "$label" == no-issue ]] && no_issue=true
done

if [ "$kinds" -ne 1 ]; then
  problems+="- carries $kinds kind: labels; it needs exactly one of kind:build, kind:design, kind:docs"$'\n'
fi
if ! $no_issue && ! grep -qiE '(^|[^[:alnum:]])(closes|refs) #[0-9]+' <<<"$body"; then
  problems+="- its body names no issue with 'Closes #n' or 'Refs #n'"$'\n'
fi

[ -z "$problems" ] && exit 0
printf '%s' "The pull request cannot land:
$problems
'Closes #n' when the pull request finishes the issue, 'Refs #n' when it
contributes to it; other words ('For', 'Fixes') do not count. A pull request
without an issue carries the label no-issue in place of the reference.
"
exit 1
