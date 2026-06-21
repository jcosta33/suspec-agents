# AGENTS.md — swarm-agents

This repo is the optional **agent-definition** catalog for the Swarm framework: self-contained,
Claude-Code-first worker definitions for Swarm roles, one file per agent under `agents/`, the
delegation-provenance + read-only-guard hooks under `hooks/`, and the evidence behind their design
under `docs/`. It is a derived-content repo — it carries no Swarm workspace install; the work of
changing it is planned and reviewed in the family workspace (the sibling `swarm-hq` repo). The
founding decision is [ADR-0092](https://github.com/jcosta33/swarm/blob/main/docs/adrs/0092-swarm-agents-member.md)
(the `ADR-NNNN` citations here are decision records in the
[swarm repo](https://github.com/jcosta33/swarm/tree/main/docs/adrs)).

## What this is NOT

Not an orchestrator, not a runtime, not a multi-agent loop. A catalog of definitions + two hooks are
**records and tripwires, never an executor** (ADR-0077 / ADR-0088). The only CLI launcher is
`swarm run --agent` (optional, in [swarm-cli](https://github.com/jcosta33/swarm-cli)); the standalone
path these definitions support — in-session subagents spawned by your own runner's Agent tool — needs
no CLI. The absence of orchestration stays observable.

## Editing rules

- **One agent per file:** `agents/<name>.md` — Claude Code subagent format (YAML frontmatter + a body
  that is the system prompt). Only `name` + `description` are required.
- **Description is the trigger:** directive — open with the verb of the work, say when to ALWAYS apply,
  name what the worker refuses, end with a `Skip …` clause.
- **No pinned `model`:** agents inherit the session model so a definition does not rot per release.
- **Tool-scoping by tier:** read-only (Tier 1) agents set a `tools` allowlist that **excludes
  Edit/Write**; the ones that keep `Bash` name the `readonly-guard` hook. Authoring (Tier 2) agents
  grant Edit/Write and **state in the body that scoping is honor-system, not enforcement**.
- **Self-contained + canon-grounded:** the body carries its own discipline, grounded in the durable
  canon ADRs (ADR-0056 self-review, ADR-0077 reconcile-only/no-verdict, ADR-0088 trace). It must read
  correctly with nothing else installed. A persona/guide is an OPTIONAL one-line "pairs with … if you
  use it" see-also — never a dependency (personas live in `swarm-skills`; core/authoring guides in the
  starter kit). Nothing here depends on a persona.
- **Honesty (ADR-0063):** never label anything "enforced". Read-only scoping is **toolable/partial**
  (defeasible — see `docs/enforcement.md`); a trace buys reviewability/attribution, not a guarantee.
- **No verdict (ADR-0077 D8):** a worker drafts and reports; it never records Pass/Fail or closes a task.
- Markdown + the two POSIX-sh hook scripts only — no other executables, no network calls.
- The catalog tables in `README.md` gain/lose a row with every agent added/removed.

## Commands

| Slot | Command | Resolves |
|---|---|---|
| — | (none) | markdown + shell-hook repo; content is checked by review (the swarm-hq workspace cuts and reviews changes) |
