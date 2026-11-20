#!/usr/bin/env bash
# A PreToolUse hook of the agents' settings (ADR-0080). Before an agent
# writes the hash list of the reviewed interfaces, the hook asks the user,
# who approves the call after reviewing the change. It reads the payload
# Claude Code sends on stdin and prints a permission decision of "ask" for a
# file tool whose path is the list, and for a shell command that names the
# list and writes to it: a redirection into it, or a segment that names it
# and runs `tee`, `mv`, `rm`, `truncate`, `dd`, `sed -i` or `perl -i`, or
# `cp`, `install` or `ln` with the list as the last argument. For any other
# call, reads of the list included, it prints nothing.
#
# A shell command that builds the path instead of naming it, or that writes
# through a command this hook does not know, passes the hook; the CI job
# `reviewed-interfaces` still catches a changed interface.
set -uo pipefail

list=packages/core/reviewed.sha256

# Succeeds when the shell command $1 writes the list it names.
writes_list() {
  [[ "$1" =~ \>\|?[[:space:]]*[^[:space:]\;\&\|]*packages/core/reviewed\.sha256 ]] && return 0
  local seg words
  while IFS= read -r seg; do
    [[ "$seg" == *"$list"* ]] || continue
    read -r -a words <<< "$seg"
    case "${words[0]}" in
      tee | mv | rm | truncate | dd) return 0 ;;
      cp | install | ln) [[ "${words[-1]}" == *"$list" ]] && return 0 ;;
      sed | perl) [[ " ${words[*]} " =~ [[:space:]](-[[:alpha:]]*i|--in-place) ]] && return 0 ;;
    esac
  done < <(sed -E 's/(&&|\|\||[;|&])/\n/g' <<< "$1")
  return 1
}

payload=$(cat)
tool=$(jq -r '.tool_name // empty' <<< "$payload")
case "$tool" in
  Bash)
    command=$(jq -r '.tool_input.command // empty' <<< "$payload")
    [[ "$command" == *"$list"* ]] && writes_list "$command" || exit 0
    ;;
  *)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "$payload")
    [[ "$path" == *"/$list" ]] || exit 0
    ;;
esac

jq -n --arg list "$list" '{hookSpecificOutput: {hookEventName: "PreToolUse",
  permissionDecision: "ask",
  permissionDecisionReason: ("This call writes " + $list + ", the hash list of the reviewed interfaces, which only the maintainer approves (ADR-0080).")}}'
exit 0
