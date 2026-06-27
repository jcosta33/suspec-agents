#!/bin/sh
# check-codex-sync.sh — the .codex no-diff guard (SPEC-agents-mcp-rearchitecture AC-005 / AUDIT F7).
#
# `.codex/agents/*.toml` is GENERATED from `agents/*.md` by `corpus agents emit --codex` and committed
# (so Codex users get it on clone — O3). Committed generated files drift: commit ed424df already had to
# "regenerate stale .codex toml". This guard fails the build when the committed `.codex/` no longer
# matches what the emitter produces from the current definitions — so a stale TOML is caught at CI/
# pre-commit time, not discovered later.
#
# It is a RECORD/CHECK, not an executor (ADR-0077): it runs the real emitter and diffs; it edits nothing.
#
# Two failure modes, both caught:
#   1. content drift / a missing TOML — `emit --force` rewrites it, `git diff` shows the change;
#   2. an ORPHAN TOML — an agent whose `agents/*.md` source was deleted but whose generated
#      `.codex/agents/<name>.toml` lingers (emit only writes, never deletes) — caught by name comparison.
#
# Usage: run from the repo root.  `bash scripts/check-codex-sync.sh`  → exit 0 clean, non-zero on drift.
set -eu

# Resolve the repo root from this script's location so it works from any cwd / in CI.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

# The emitter: the installed `corpus` CLI in CI, else the local corpus-cli checkout for dev. Override
# with CORPUS_EMIT (e.g. CORPUS_EMIT="corpus") to point at the installed binary.
if [ -n "${CORPUS_EMIT:-}" ]; then
    # shellcheck disable=SC2086 # intentional word-split so CORPUS_EMIT can carry args
    set -- $CORPUS_EMIT
elif command -v corpus >/dev/null 2>&1; then
    set -- corpus
elif [ -f ../corpus-cli/bin/corpus.js ]; then
    set -- node ../corpus-cli/bin/corpus.js
else
    echo "check-codex-sync: cannot find the corpus emitter." >&2
    echo "  Install the corpus CLI (so \`corpus\` is on PATH), or check out corpus-cli as a sibling," >&2
    echo "  or set CORPUS_EMIT to the command that runs it (e.g. CORPUS_EMIT='corpus')." >&2
    exit 2
fi

echo "check-codex-sync: emitting .codex from agents/ via: $* agents emit --codex --from agents --force"
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

# No-diff check: the committed .codex/ must equal what the emitter just produced.
if ! git diff --exit-code -- .codex/; then
    echo "" >&2
    echo "check-codex-sync: FAIL — .codex/ drifted from the agent definitions." >&2
    echo "  The committed .codex/agents/*.toml no longer matches \`corpus agents emit --codex\`." >&2
    echo "  Regenerate and commit it:" >&2
    echo "    corpus agents emit --codex --from agents --force   # (or: node ../corpus-cli/bin/corpus.js …)" >&2
    echo "    git add .codex/ && git commit" >&2
    exit 1
fi

echo "check-codex-sync: OK — .codex/ is in sync with agents/ (no drift, no orphans)."
