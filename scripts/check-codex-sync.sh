#!/bin/sh
# check-codex-sync.sh — the .codex no-diff guard (SPEC-agents-mcp-rearchitecture AC-005 / AUDIT F7).
#
# `.codex/agents/*.toml` is GENERATED from `agents/*.md` by `suspec agents emit --codex` and committed
# (so Codex users get it on clone — O3). Committed generated files drift: commit ed424df already had to
# "regenerate stale .codex toml". This guard fails the build when the committed `.codex/` no longer
# matches what the emitter produces from the current definitions — so a stale TOML is caught at CI/
# pre-commit time, not discovered later.
#
# It is a RECORD/CHECK, not an executor (ADR-0077): it runs the real emitter and diffs; it edits nothing.
#
# Three failure modes, all caught:
#   1. content drift — `emit --force` rewrites a committed TOML, `git diff` shows the change;
#   2. a MISSING TOML — a new agents/<name>.md whose generated TOML was never committed: emit creates
#      it as an UNTRACKED file (invisible to `git diff`), caught by the untracked-files check;
#   3. an ORPHAN TOML — an agent whose `agents/*.md` source was deleted but whose generated
#      `.codex/agents/<name>.toml` lingers (emit only writes, never deletes) — caught by name comparison.
#
# Usage: run from the repo root.  `bash scripts/check-codex-sync.sh`  → exit 0 clean, non-zero on drift.
set -eu

# Resolve the repo root from this script's location so it works from any cwd / in CI.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

find_sibling_suspec_cli() {
    for candidate in "$REPO_ROOT"/../*; do
        [ -d "$candidate" ] || continue
        [ -f "$candidate/bin/suspec.js" ] || continue
        [ -f "$candidate/package.json" ] || continue
        if grep -Eq '"name"[[:space:]]*:[[:space:]]*"suspec-cli"' "$candidate/package.json"; then
            printf '%s\n' "$candidate/bin/suspec.js"
            return
        fi
    done
}

# The emitter: the installed `suspec` CLI in CI, else the local suspec-cli checkout for dev. Override
# with SUSPEC_EMIT (e.g. SUSPEC_EMIT="suspec") to point at the installed binary.
if [ -n "${SUSPEC_EMIT:-}" ]; then
    # shellcheck disable=SC2086 # intentional word-split so SUSPEC_EMIT can carry args
    set -- $SUSPEC_EMIT
    emitter_label="$SUSPEC_EMIT"
elif command -v suspec >/dev/null 2>&1; then
    set -- suspec
    emitter_label="suspec"
elif [ -f ../suspec-cli/bin/suspec.js ]; then
    set -- node ../suspec-cli/bin/suspec.js
    emitter_label="node ../suspec-cli/bin/suspec.js"
elif local_cli=$(find_sibling_suspec_cli) && [ -n "$local_cli" ]; then
    set -- node "$local_cli"
    emitter_label="local suspec-cli package"
else
    echo "check-codex-sync: cannot find the suspec emitter." >&2
    echo "  Install the suspec CLI (so \`suspec\` is on PATH), or check out suspec-cli as a sibling," >&2
    echo "  or set SUSPEC_EMIT to the command that runs it (e.g. SUSPEC_EMIT='suspec')." >&2
    exit 2
fi

echo "check-codex-sync: emitting .codex from agents/ via: $emitter_label agents emit --codex --from agents --force"
"$@" agents emit --codex --from agents --force

# Orphan check: every committed/emitted .codex/agents/<name>.toml must have an agents/<name>.md source.
# (The emitter writes but never deletes, so a deleted agent's TOML would otherwise survive a clean diff.)
orphans=""
if [ -d .codex/agents ]; then
    for toml in .codex/agents/*.toml; do
        [ -e "$toml" ] || continue
        name=$(basename "$toml" .toml)
        if [ ! -f "agents/$name.md" ]; then
            orphans="$orphans $name.toml"
        fi
    done
fi
if [ -n "$orphans" ]; then
    echo "check-codex-sync: FAIL — orphan generated TOML(s) with no agents/*.md source:$orphans" >&2
    echo "  An agent definition was removed but its generated .codex TOML lingers. Delete it:" >&2
    for o in $orphans; do echo "    git rm .codex/agents/$o" >&2; done
    exit 1
fi

# Untracked check: a NEW agents/<name>.md whose generated TOML was never committed shows up here as an
# untracked file — `git diff` alone is blind to it and would report a clean sync.
untracked=$(git ls-files --others --exclude-standard -- .codex/)
if [ -n "$untracked" ]; then
    echo "check-codex-sync: FAIL — uncommitted generated TOML(s):" >&2
    printf '    %s\n' $untracked >&2
    echo "  A new agent's generated .codex TOML exists but was never committed. Commit it:" >&2
    echo "    git add .codex/ && git commit" >&2
    exit 1
fi

# No-diff check: the committed .codex/ must equal what the emitter just produced.
if ! git diff --exit-code -- .codex/; then
    echo "" >&2
    echo "check-codex-sync: FAIL — .codex/ drifted from the agent definitions." >&2
    echo "  The committed .codex/agents/*.toml no longer matches \`suspec agents emit --codex\`." >&2
    echo "  Regenerate and commit it:" >&2
    echo "    suspec agents emit --codex --from agents --force   # (or: node ../suspec-cli/bin/suspec.js …)" >&2
    echo "    git add .codex/ && git commit" >&2
    exit 1
fi

echo "check-codex-sync: OK — .codex/ is in sync with agents/ (no drift, no orphans)."
