#!/bin/sh
# Delegation-provenance hook (ADR-0088 producer 2) — Claude Code.
#
# `swarm run --agent` records a provenance block for the workers IT launches (producer 1). But
# in-session subagents — the ones the main agent spawns through Claude Code's own Agent tool — never
# touch the CLI. This hook is producer 2: it appends one NDJSON trace line per subagent event to
# `.swarm/work/delegations.ndjson`, so that delegation is reviewable too. It is a RECORD, never a
# verdict (ADR-0077 Decision 8), and it always exits 0 — provenance must never block the agent.
#
# Wire it in `.claude/settings.json` (see README.md). Pass the event name as argv[1].
set -eu

# Anchor to the repo root so traces always collect in one place, regardless of the hook's cwd.
root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
dir="$root/.swarm/work"
mkdir -p "$dir"
out="$dir/delegations.ndjson"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
event="${1:-subagent}"                  # the hook event name, passed from the settings.json config
payload="$(cat 2>/dev/null || true)"    # Claude Code delivers the event JSON on stdin

if command -v jq >/dev/null 2>&1 && printf '%s' "$payload" | jq -e . >/dev/null 2>&1; then
    # Map YOUR Claude Code version's SubagentStart/Stop fields onto the ADR-0088 schema. The keys below
    # are best-effort fallbacks — verify them against your version's hook payload and adjust the jq.
    printf '%s' "$payload" | jq -c \
        --arg ts "$ts" --arg event "$event" \
        '{ts: $ts, event: $event,
          worker: (.subagent_type // .agent_type // .name // "unknown"),
          reason: (.prompt // .description // null),
          inputs: (.inputs // .prompt // null),
          filtered: (.filtered // null),
          tools: (.tools // null),
          could_edit: .could_edit,
          evidence: (.result // .summary // null),
          raw: .}' >> "$out"
else
    # No jq, or a non-JSON payload: still record the event + timestamp so the trace is never silently
    # lost (install jq to capture the structured ADR-0088 fields).
    printf '{"ts":"%s","event":"%s","note":"install jq to capture structured fields"}\n' "$ts" "$event" >> "$out"
fi

exit 0
