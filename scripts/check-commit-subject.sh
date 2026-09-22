#!/usr/bin/env bash
# Conventional-commit gate for commits made through Claude Code.
#
# Runs as a PreToolUse hook on Bash (see .claude/settings.json), reads the
# hook payload on stdin, and denies the tool call when the commit subject
# does not parse or names a scope outside the list below. The reason text
# goes back to the agent, which can then fix the subject and retry.
#
# Scopes name WHERE a change lives, never what it is about, so nothing has
# to be decided while writing the message: the diff already says which one
# applies. Keep the list sorted the way the tree is laid out.
#
# Reach: only commits that go through Claude Code's Bash tool, and only the
# `-m`/`--message` form. A `jj describe` that opens $EDITOR, or a message in
# a heredoc, carries no subject this can read and passes unchecked.

set -uo pipefail

SCOPES=(
  # packages/
  core render grammar vscode eval-web www playground
  # documents
  spec decisions notes paper examples brand
  # infrastructure
  ci nix
)

TYPES=(feat fix docs refactor test chore build ci perf style revert)

cmd=$(jq -r '.tool_input.command // ""')

# Cheap bail-out for the overwhelming majority of Bash calls. Not an `if`
# filter in settings.json: those match on a command prefix, and a command
# that starts with `cd … &&` would slip past one.
case "$cmd" in
  *"jj commit"*|*"jj describe"*|*"git commit"*) ;;
  *) exit 0 ;;
esac

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# Last -m/--message wins, matching how the shell would read it.
msg=$(printf '%s' "$cmd" | rg -o '(?:-m|--message)[= ]+"([^"]*)"' -r '$1' | tail -1)
if [ -z "$msg" ]; then
  msg=$(printf '%s' "$cmd" | rg -o "(?:-m|--message)[= ]+'([^']*)'" -r '$1' | tail -1)
fi
# No readable subject (editor, heredoc, amend without a message): let it run.
[ -z "$msg" ] && exit 0

subject=${msg%%$'\n'*}

joined_types=$(printf '%s, ' "${TYPES[@]}"); joined_types=${joined_types%, }
joined_scopes=$(printf '%s, ' "${SCOPES[@]}"); joined_scopes=${joined_scopes%, }

if [[ ! "$subject" =~ ^([a-z0-9]+)(\(([a-z0-9/-]+)\))?(!)?:\ (.+)$ ]]; then
  deny "Commit subject is not a conventional commit: '$subject'
Expected <type>(<scope>)!: <description>, scope and ! optional.
Types: $joined_types
Scopes: $joined_scopes"
fi

type=${BASH_REMATCH[1]}
scope=${BASH_REMATCH[3]}

found=0
for t in "${TYPES[@]}"; do [ "$t" = "$type" ] && found=1 && break; done
if [ "$found" -eq 0 ]; then
  deny "Unknown commit type '$type' in: '$subject'
Types: $joined_types"
fi

if [ -n "$scope" ]; then
  found=0
  for s in "${SCOPES[@]}"; do [ "$s" = "$scope" ] && found=1 && break; done
  if [ "$found" -eq 0 ]; then
    deny "Unknown commit scope '$scope' in: '$subject'
A scope names where the change lives. Pick one of: $joined_scopes
Leave the scope out for a change that spans the repository.
To add a scope, edit scripts/check-commit-subject.sh."
  fi
fi

exit 0
