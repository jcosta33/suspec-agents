# suspec-agents

> Optional, Claude-Code-first **worker definitions** for the [Suspec](https://github.com/jcosta33/suspec)
> roles — independent review (with a proof-first evidence mode), pre-commitment challenge, and bounded
> authoring (spec · research · audit · docs) — each a self-contained Claude Code subagent you copy into a
> repo. Records and tripwires, never an orchestrator.

Each agent runs a Suspec role in a **fresh, isolated context**, with its tools scoped to the work, and
(with the hook) leaves a **delegation trace** for review — partially structured and version-dependent
(see [hooks/README.md](./hooks/README.md)). The discipline is baked into each definition; you copy the
one you need. Nothing here runs a model loop or owns the **verdict** — the accept/reject decision on a
task, which a human still makes; the review vocabulary is defined in the
[Suspec glossary](https://github.com/jcosta33/suspec/blob/main/docs/reference/glossary.md).

## Install

Claude Code discovers agents from a repo's `.claude/agents/` directory. **Copy the one you want:**

```bash
# ensure the target dirs exist (a fresh repo has neither)
mkdir -p <your-repo>/.claude/agents <your-repo>/.claude/hooks

# one agent into the current repo
cp agents/suspec-reviewer.md <your-repo>/.claude/agents/

# the delegation-provenance hook (optional) + wire it in .claude/settings.json (see hooks/README.md)
cp hooks/delegations.sh <your-repo>/.claude/hooks/ && chmod +x <your-repo>/.claude/hooks/delegations.sh
# the read-only guard for the Bash-holding workers
cp hooks/readonly-guard.sh <your-repo>/.claude/hooks/ && chmod +x <your-repo>/.claude/hooks/readonly-guard.sh

# if you installed delegations.sh: keep its plaintext trace out of your history
echo '.suspec/work/' >> <your-repo>/.gitignore
```

Copy-based by design: these are Claude Code **agents** (`.claude/agents/`), not Agent-Skills
(`.agents/skills/`), so the `npx skills` CLI does not install them. Use it for the
[suspec-skills](https://github.com/jcosta33/suspec-skills) catalog; copy the agents here.

## The AGENTS.md contract

An agent body names abstract command slots (`cmdTest`, `cmdLint`, …) where it must re-run a project's
checks; the consuming repo's `AGENTS.md` supplies the concrete commands. An empty slot means **ask**.
That split keeps an agent portable across repos.

A consuming repo's `AGENTS.md` fills the slots — for example:

| Slot    | Command        |
| ------- | -------------- |
| cmdTest | `npm test`     |
| cmdLint | `npm run lint` |

(This repo's own [AGENTS.md](./AGENTS.md) Commands table carries one check —
`bash scripts/check-codex-sync.sh`, the `.codex/` no-diff guard — and nothing else.)

## Where to start

You need none of these to run Suspec — the [starter kit](https://github.com/jcosta33/suspec-starter-kit)
ships the loop. Add an agent when delegating that role to an isolated, scoped subagent earns its keep:

1. **`suspec-reviewer`** — the first one most want: an independent, read-only reviewer for a finished
   task or PR that re-runs the Verify checks and drafts a packet without issuing the verdict. When you
   only need the checks re-run and the evidence pasted (not a full packet), run it in
   **proof-first mode**.
2. **For code-location** — use the built-in **Explore** agent (read-only Read/Grep/Glob, same
   locate/trace mandate) with the `codebase-exploration` skill from
   [suspec-skills](https://github.com/jcosta33/suspec-skills).
3. **A bounded-authoring worker** — `suspec-spec-author` / `suspec-researcher` / `suspec-auditor` /
   `suspec-documentarian` — when you want a disciplined, isolated, traced first draft of one artifact.

## Why not just the built-in reviewer + a CLAUDE.md?

You can get far with your runner's built-in agents and a `CLAUDE.md`. These add three things those do
not: a **fresh, isolated context per role** — the subagent is never primed by your main thread's
framing ([`docs/isolation.md`](./docs/isolation.md)); a hard refusal to **self-issue a verdict** — the
reviewer/checker drafts and a human decides; and, with the hook, a **reviewable delegation
trace** the built-ins don't emit. When none of those matter, the built-ins are the lighter choice —
reach for these when the isolation, the no-self-verdict rule, or the trace earns its keep.

## Catalog

### Tier 1 — read-only workers

Their `tools` allowlist excludes Edit/Write; the ones that keep `Bash` (to re-run Verify) pair with
the `readonly-guard` hook. **Scoping is toolable/partial — it narrows the surface, it is not a
guarantee** (see [The science](#the-science)).

| Agent                                                | Use it when                                                                                                            |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [`suspec-reviewer`](./agents/suspec-reviewer.md)     | Reviewing a **finished** task/PR (or a 1:1 review-to-spec) — re-run Verify, draft the packet + staleness pins, **no verdict**. Its **proof-first mode** re-runs the Verify items and pastes verbatim output only |
| [`suspec-challenger`](./agents/suspec-challenger.md) | Pressure-testing a **not-yet-built** proposal/spec/plan — assumptions, the steelmanned alternative, external evidence  |

For **code-location**, use the built-in **Explore** agent (see [Where to start](#where-to-start)).

_Of these, only `suspec-reviewer` holds `Bash` (so the `readonly-guard` applies to it); `suspec-challenger`
has no Bash and needs no guard._

### Tier 2 — bounded-authoring workers

These grant Edit/Write to draft one artifact. **Their value is the baked-in discipline + fresh-context
isolation + the delegation trace — NOT enforcement** (a granted Write is not path-locked; the body
says so). Each refuses to self-issue a verdict.

| Agent                                                      | Use it when                                                                                       |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [`suspec-spec-author`](./agents/suspec-spec-author.md)     | Drafting (or amending) a living spec — verifiable requirements, open decisions, no smuggled implementation |
| [`suspec-researcher`](./agents/suspec-researcher.md)       | Investigating one question against primary sources → a research note, committing to no decision   |
| [`suspec-auditor`](./agents/suspec-auditor.md)             | Auditing a code area — present state, file:line, severity by impact, observation not prescription |
| [`suspec-documentarian`](./agents/suspec-documentarian.md) | Drafting human-facing docs — one Diátaxis frame, every example run as written                     |

_`suspec-auditor` and `suspec-documentarian` also hold `Bash` (to run read-only inspections / run doc
examples). The `readonly-guard` is a global `Bash` matcher, so it covers them too where you want their
shell use kept read-only._

## The science

[`docs/`](./docs/) documents the evidence behind the design, and — bluntly — the limits:

- [`enforcement.md`](./docs/enforcement.md) — what tool-scoping + hooks actually guarantee
  (toolable/partial) vs. what is honor-system, with the bypass-bug cluster cited.
- [`isolation.md`](./docs/isolation.md) — fresh-context isolation and how it is defeated (fork mode,
  parent permission modes).
- [`provenance.md`](./docs/provenance.md) — the delegation trace, aligned with HDP + OpenTelemetry.
- [`runners.md`](./docs/runners.md) — Claude-Code-first, and how it ports: `suspec agents emit --codex` generates the Codex form from the single-source defs; the `AGENTS.md` discipline is the universal layer (enforcement stays Claude-Code-only). The committed `.codex/` is kept in sync by a no-diff guard ([`scripts/check-codex-sync.sh`](./scripts/check-codex-sync.sh) + [`.github/workflows/codex-sync.yml`](./.github/workflows/codex-sync.yml)) that re-runs the emitter and fails on drift or an orphaned TOML.
- [`sources.md`](./docs/sources.md) — the bibliography.

## Security

Read an agent before installing it — a definition is instructions your agent will follow. What you
install is plain markdown plus two short POSIX-sh hooks; the hooks make no network calls and run no
other executables (the `suspec-challenger` and `suspec-researcher` agents do request
`WebSearch`/`WebFetch` for external grounding — read those two before installing). The repo itself
additionally carries a CI-only sync-check script (`scripts/check-codex-sync.sh`, which runs the
suspec-cli emitter) and its workflow — neither is part of a copy-install. The read-only guarantees are
**partial** (see `docs/enforcement.md`): a `tools` allowlist + a tripwire hook raise the bar but do not
sandbox a shell. The delegation trace is written in plaintext under `.suspec/work/` and can contain
prompt and model-output content — gitignore it in your repo (this repo does; the install snippet above
includes the line) and treat it as sensitive at rest. Pin to a commit for a stable install.

## Relationship to the Suspec framework

These agents assume nothing about Suspec beyond a repo with an `AGENTS.md` — each stands alone. They are
runner-specific (Claude Code) projections of the Suspec roles; the framework and its docs live at
[jcosta33/suspec](https://github.com/jcosta33/suspec), the copy-whole workspace at
[jcosta33/suspec-starter-kit](https://github.com/jcosta33/suspec-starter-kit), the agent-neutral
disciplines at [jcosta33/suspec-skills](https://github.com/jcosta33/suspec-skills). This catalog is
curated: agent content is edited here; changes are planned and reviewed in the Suspec project's
workspace.

The worker definitions track the framework's current **mean-and-lean** generation:
the `suspec-spec-author` drafts a **living spec** (the `draft → ready → active → superseded` lifecycle,
open decisions with options + a recommendation, per-requirement supersession, a `snapshot:` SHA, and the
append-only `## Execution` run-record); the `suspec-reviewer` handles the **task-less 1:1 review-to-spec**
(coverage on the spec's full ACs via a `spec:` key) and records the **fast-track staleness pins**
(`reviewed_sha:` + `evidence_hash:`). The matching CLI surface lives in
[suspec-cli](https://github.com/jcosta33/suspec-cli): `suspec stamp` writes those pins, `suspec check
--staleness` flags spec drift, and `suspec clean` prunes the now-ephemeral tasks/reviews.

## License

MIT — see [LICENSE](./LICENSE). Copy these files into your repo freely.
