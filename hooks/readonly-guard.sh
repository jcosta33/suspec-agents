#!/bin/sh
# Read-only guard (PreToolUse, Bash) — swarm-agents.
#
# The Tier-1 read-only workers (swarm-reviewer, swarm-evidence-checker) drop Edit/Write from their
# tools allowlist but KEEP Bash — because they must re-run a task's Verify commands. A shell can still
# write, so this hook is a TRIPWIRE, not a wall: it `exit 2`-blocks the obvious source-mutating /
# destructive / publish idioms a reviewer should never reach for, raising the bar against
# edit-via-shell. It is NOT a guarantee (ADR-0063 — "toolable/partial", never "enforced"):
#   - a determined command can evade it (a write inside python/node/perl, base64, an editor heredoc);
#   - it does not block output redirections (`>`/`tee`) — too false-positive-prone against legit
#     build/test writes — so those remain a known gap; tune the denylist to your repo;
#   - a parent in bypassPermissions/acceptEdits/auto, or a plugin-loaded subagent, bypasses hooks
#     entirely (claude-code#25000 / #43142). Pair this with a tools allowlist that excludes Edit/Write.
#
# Wire it as a Bash PreToolUse hook in `.claude/settings.json` (see README.md). Exit 0 = allow,
# exit 2 = block before the command runs.
set -eu

payload="$(cat 2>/dev/null || true)"
if command -v jq >/dev/null 2>&1 && printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .command // empty' 2>/dev/null || true)"
else
    cmd="$payload"
fi
[ -z "$cmd" ] && exit 0   # nothing to inspect -> allow

# Unambiguous source-mutation / destructive / publish idioms. Conservative on purpose: builds, tests,
# and redirections are NOT matched here (they are commonly legitimate Verify steps) — that gap is
# documented, not hidden.
case "$cmd" in
    *"git commit"*|*"git push"*|*"git add "*|*"git reset"*|*"git restore"*|*"git stash"*|*"git rm "*|\
    *"sed -i"*|*"sed --in-place"*|\
    *"rm "*|*"rmdir "*|*"mv "*|*"chmod "*|*"chown "*|\
    *"npm publish"*|*"yarn publish"*|*"pnpm publish"*)
        printf 'read-only guard: blocked a write-ish/destructive Bash command:\n  %s\nswarm-agents read-only workers re-run Verify and report — they do not mutate source. Make the change a separate task. (toolable/partial — a tripwire, not a guarantee.)\n' "$cmd" >&2
        exit 2 ;;
esac

exit 0
