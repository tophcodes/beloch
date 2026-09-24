#!/usr/bin/env bash
# Conventional-commit gate on the subjects of commits about to be published.
#
#   check-commit-subjects.sh --hook
#       PreToolUse hook on Bash (see .claude/settings.json). Reads the hook
#       payload on stdin. When the command runs `jj git push`, it asks jj for
#       every non-merge commit the push would send and denies the tool call if
#       any subject does not parse or names an unknown scope. The reason text
#       goes back to the agent, which can reword the commits and push again.
#
#   check-commit-subjects.sh
#       Reads subjects on stdin, one per line, and exits 1 if any is bad.
#       CI feeds it `git log --no-merges --format=%s <base>..<head>`,
#       which covers pushes made by hand.
#
# jj has no pre-push hook, so the agent side hangs off the Claude Code tool
# call. Local commits are free to say anything (`wip:` included) until they
# are pushed.
#
# Scopes name WHERE a change lives. Package scopes are read from the tree on
# every run: each directory under packages/, plus the npm name (without
# `@beloch/`) of every nested package such as packages/runtime/editor, whose
# scope is `runtime-editor`. Adding or renaming a package needs no edit here.
# The fixed list below covers the parts of the repository that are not
# packages.
#
# Known limitation: the hook sees the repository as it is before the tool call
# runs. In `jj commit -m … && jj git push`, the new commit does not exist yet
# and goes out unchecked; CI still catches it.

set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

OTHER_SCOPES=(spec decisions notes paper examples brand ci nix)
TYPES=(feat fix docs refactor test chore build ci perf style revert)

package_scopes() {
  local d p
  for d in "$root"/packages/*/; do basename "$d"; done
  for p in "$root"/packages/*/*/package.json; do
    jq -r '.name // "" | select(startswith("@beloch/")) | sub("^@beloch/"; "")' "$p"
  done
}
mapfile -t SCOPES < <({ package_scopes; printf '%s\n' "${OTHER_SCOPES[@]}"; } | sort -u)

joined_types=$(printf '%s, ' "${TYPES[@]}"); joined_types=${joined_types%, }
joined_scopes=$(printf '%s, ' "${SCOPES[@]}"); joined_scopes=${joined_scopes%, }

# Prints a one-line complaint for a bad subject, nothing for a good one.
check_subject() {
  local subject=$1 type scope
  if [[ ! "$subject" =~ ^([a-z0-9]+)(\(([a-z0-9/-]+)\))?(!)?:\ (.+)$ ]]; then
    echo "not a conventional commit: '$subject'"; return
  fi
  type=${BASH_REMATCH[1]} scope=${BASH_REMATCH[3]}
  [[ " ${TYPES[*]} " == *" $type "* ]] || { echo "unknown type '$type': '$subject'"; return; }
  [[ -z "$scope" || " ${SCOPES[*]} " == *" $scope "* ]] || echo "unknown scope '$scope': '$subject'"
}

# Checks every subject on stdin; prints the report and returns 1 on failures.
check_all() {
  local subject problem problems=""
  while IFS= read -r subject; do
    [ -z "$subject" ] && continue
    problem=$(check_subject "$subject")
    [ -n "$problem" ] && problems+="- $problem"$'\n'
  done
  [ -z "$problems" ] && return 0
  printf '%s' "Commit subjects that cannot be pushed:
$problems
Expected <type>(<scope>)!: <description>, scope and ! optional.
Types: $joined_types
Scopes: $joined_scopes
A scope names where the change lives; leave it out for a change that spans the
repository. Package scopes follow packages/; other scopes live in
scripts/check-commit-subjects.sh."
  return 1
}

if [ "${1:-}" != "--hook" ]; then
  check_all >&2
  exit
fi

payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")

# Cheap bail-out for the overwhelming majority of Bash calls. Not an `if`
# filter in settings.json: those match on a command prefix, and a command
# that starts with `cd … &&` would slip past one.
case "$cmd" in
  *"jj git push"*) ;;
  *) exit 0 ;;
esac

dir=$(jq -r '.cwd // "."' <<<"$payload")
# A leading `cd DIR &&` moves the push into another workspace, whose @ differs.
if [[ "$cmd" =~ ^cd[[:space:]]+([^[:space:]\;\&]+)[[:space:]]*\&\& ]]; then
  cd "$dir" 2>/dev/null && dir=$(cd "${BASH_REMATCH[1]}" 2>/dev/null && pwd) || exit 0
fi

# The push's own arguments end at the first shell operator or redirection.
args=${cmd#*jj git push}
args=${args%%[|;&>]*}
read -ra toks <<<"$args"

# `-b foo` is a glob by default, `-b exact:foo` names its pattern kind.
bookmark_revset() {
  case "$1" in
    *:*) printf 'bookmarks(%s:"%s")' "${1%%:*}" "${1#*:}" ;;
    *) printf 'bookmarks(glob:"%s")' "$1" ;;
  esac
}

heads=()
i=0
while [ $i -lt ${#toks[@]} ]; do
  t=${toks[$i]//[\"\']/}
  i=$((i + 1))
  val=""
  if [[ "$t" == --*=* ]]; then val=${t#*=}; t=${t%%=*}; fi
  case "$t" in
    -b|--bookmark|-c|--change|-r|--revision|--revisions|--named|-R|--repository|--remote|-t|--tag)
      if [ -z "$val" ]; then val=${toks[$i]:-}; val=${val//[\"\']/}; i=$((i + 1)); fi ;;
  esac
  case "$t" in
    -b|--bookmark) heads+=("$(bookmark_revset "$val")") ;;
    -c|--change|-r|--revision|--revisions) heads+=("($val)") ;;
    --named) heads+=("(${val#*=})") ;;
    --all|--tracked) heads+=("bookmarks()") ;;
    -R|--repository) dir=$(cd "$dir" 2>/dev/null && cd "$val" 2>/dev/null && pwd) || exit 0 ;;
  esac
done
# jj's default: the tracking bookmarks between the remote and @.
if [ ${#heads[@]} -eq 0 ]; then
  tracked=$(cd "$dir" 2>/dev/null && jj --ignore-working-copy bookmark list --tracked \
    -T 'name ++ "\n"' 2>/dev/null | sort -u) || exit 0
  [ -z "$tracked" ] && exit 0
  heads=("($(printf 'bookmarks(exact:"%s")|' $tracked)none()) & (remote_bookmarks()..@)")
fi

joined_heads=$(IFS='|'; echo "${heads[*]}")
revset="remote_bookmarks()..($joined_heads) ~ merges()"

# If jj cannot evaluate the range, the push cannot either: let it run and fail
# on its own terms.
subjects=$(cd "$dir" 2>/dev/null && jj --ignore-working-copy log --no-graph \
  -r "$revset" -T 'description.first_line() ++ "\n"' 2>/dev/null) || exit 0

if ! report=$(check_all <<<"$subjects"); then
  jq -n --arg r "$report" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
fi
exit 0
