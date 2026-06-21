# Hooks

Two opt-in Claude Code hooks. Copy the one you want into your repo's `.claude/hooks/`
(`chmod +x` it) and wire it in `.claude/settings.json`. Both are **records/tripwires, never an
executor or a guarantee** — they raise reviewability and the bar, nothing more.

## `delegations.sh` — delegation-provenance (ADR-0088 producer 2)

`swarm run --agent` records a provenance block for the workers **it** launches (producer 1). But
**in-session subagents** — the ones the main agent spawns through Claude Code's own Agent tool —
never touch the CLI. This hook is producer 2: one NDJSON trace line per subagent event in
`.swarm/work/delegations.ndjson`, so delegation is reviewable too. A record, never a verdict
(ADR-0077 D8); always exits 0, so provenance never blocks the agent.

```json
{
  "hooks": {
    "SubagentStart": [{ "hooks": [{ "type": "command", "command": ".claude/hooks/delegations.sh SubagentStart" }] }],
    "SubagentStop":  [{ "hooks": [{ "type": "command", "command": ".claude/hooks/delegations.sh SubagentStop" }] }]
  }
}
```

It records the ADR-0088 fields (`worker`, `reason`, `inputs`, `filtered`, `tools`, `could_edit`,
`evidence`, + `ts`/`event`/`raw`), mapped **best-effort** from the Claude Code payload — adjust the
`jq` to your version's actual SubagentStart/Stop field names. (`SubagentStart` fires but **cannot
block**; it is for the trace, not enforcement.)

## `readonly-guard.sh` — a write-ish-Bash tripwire (PreToolUse) for Tier-1 agents

The read-only workers drop Edit/Write but keep Bash (to re-run Verify), and a shell can still write.
This `PreToolUse` hook `exit 2`-blocks the obvious source-mutating / destructive / publish idioms
(`git commit`/`push`/`add`/`reset`, `sed -i`, `rm`/`mv`/`chmod`/`chown`, `*publish`).

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": ".claude/hooks/readonly-guard.sh" }] }]
  }
}
```

## Honest scope (read this)

These are **toolable/partial** (ADR-0063), not "enforced":
- The guard is a **tripwire, not a wall** — a write inside `python`/`node`, a heredoc to an editor, or
  base64 can evade it; output redirections (`>`/`tee`) are deliberately **not** matched (too
  false-positive-prone against legit build/test writes) — tune the denylist to your repo.
- Both hooks are **defeasible**: a parent in `bypassPermissions`/`acceptEdits`/`auto`, or a
  plugin-loaded subagent, bypasses hooks entirely (claude-code#25000 / #43142 / #54898).
- Pair the guard with a `tools` allowlist that excludes Edit/Write (the agent definitions do this).

Verify the hook event names + `settings.json` shape against your Claude Code version — the
lifecycle-hook surface evolves; these are v0 recipes.
