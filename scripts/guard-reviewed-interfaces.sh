#!/usr/bin/env bash
# A PreToolUse hook of the agents' settings (ADR-0080). Before an agent
# writes the hash list of the reviewed interfaces, the check that reads it,
# this hook or the settings that run it, the hook asks the user, who approves
# the call after reviewing the change. It reads the payload Claude Code sends
# on stdin and prints a permission decision of "ask" for a file tool whose
# path ends in a guarded file and for a shell command that names one; for any
# other call it prints nothing.
#
# A shell command that builds a guarded path instead of naming it passes the
# hook; the check in `check` still catches a changed interface.
set -uo pipefail

guarded=(
  packages/core/reviewed.sha256
  scripts/check-reviewed-interfaces.sh
  scripts/guard-reviewed-interfaces.sh
  .claude/settings.json
)

payload=$(cat)
tool=$(jq -r '.tool_name // empty' <<< "$payload")
case "$tool" in
  Bash) subject=$(jq -r '.tool_input.command // empty' <<< "$payload") ;;
  *) subject=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$payload") ;;
esac

for g in "${guarded[@]}"; do
  if [[ "$tool" == Bash && "$subject" == *"$g"* ]] || [[ "$tool" != Bash && "$subject" == *"/$g" ]]; then
    jq -n --arg g "$g" '{hookSpecificOutput: {hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: ("This call changes " + $g + ", which only the maintainer approves (ADR-0080).")}}'
    exit 0
  fi
done
exit 0
