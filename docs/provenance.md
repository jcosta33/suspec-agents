# Provenance: the delegation trace

When an agent delegates to a subagent, suspec-agents leaves a reviewable record of the handoff. The
contract is canon (ADR-0088); this is how the producers here emit it and how it relates to the wider
standards.

## The contract (ADR-0088)

Per agent→subagent handoff, a trace records: `worker` (the subagent/role), `reason` (why it was
delegated to), `inputs` (what it received), `filtered` (what context was withheld — `fresh-context` /
`inherited`), `tools` (what it was granted), `could_edit` (true/false), `evidence` (what it returned),
and `ts`/`event`. It is **a record, never a verdict** (ADR-0077 D8): a missing or thin trace is a
human-attention fact, not a failure. No checker mints it (convention-first, ADR-0063/0092).

## The two producers

- **`suspec run --agent`** (in [suspec-cli](https://github.com/jcosta33/suspec-cli)) writes a `provenance`
  block + `changed_files` in its run-record for the workers it launches. (Producer 1; optional — only
  if you use suspec-cli.)
- **`hooks/delegations.sh`** (here) appends one NDJSON line per `SubagentStart`/`SubagentStop` to
  `.suspec/work/delegations.ndjson` — because in-session subagents bypass the CLI. (Producer 2; the
  producer a copy-install actually runs.) **What it actually ships, on the only verified Claude Code
  version (v2.1.173), is a timestamped worker+output log** — not the full ADR-0088 trace: only `worker`
  and `evidence` populate; `reason`/`inputs`/`tools`/`could_edit` ship `null` (the raw event is kept, so
  the rest is recoverable via `raw.transcript_path`). Describe it as what it is — a per-handoff record of
  _who_ ran and _what came back_, with a timestamp — not as the richer reason/inputs/tools trace the
  contract defines. The fuller fields are the upgrade path as the payload exposes them, not a current
  claim. See [hooks/README.md](../hooks/README.md).

## Alignment with the standards (don't reinvent names)

- **HDP** (Human Delegation Provenance — a 2026 preprint + early-stage IETF draft: arXiv 2604.04522;
  draft-helixar-hdp-agentic-delegation-00) defines a signed, append-only delegation trace (delegating
  agent id/type, timestamp, action summary, parent-hop index, chained Ed25519 signatures over prior
  hops). It is more rigorous than our plaintext NDJSON, and it draws the **same boundary we do**: it
  provides the _record_, not enforcement of actions against scope ("an application-layer concern").
  Treat HDP as the rigorous future (signing, tamper-evidence); our fields are the lightweight, same-
  shape record.
- **OpenTelemetry GenAI** conventions give reusable attribute names —
  `gen_ai.agent.name`/`.id`, `gen_ai.request.model`, `gen_ai.tool.definitions` — but **no
  agent-to-agent handoff semantics yet** (the delegation-attributes proposal, semconv-genai #35, is
  open). Align names where they overlap; the handoff gap is what this trace fills.

## What it buys

Reviewability and attribution — as shipped (producer 2 today), _who_ ran and _what came back_, with a
timestamp; the contract's _with which tools / edit rights / why_ fields are defined but ship `null` on
the verified version (recoverable from the raw event). **Not** a behavioral guarantee, and **not**
tamper-evident (plaintext, unsigned — that's the HDP upgrade path). The trace can contain prompt and
model-output content in plaintext; gitignore `.suspec/work/` in the repo where the hook runs (this repo
does; a copy-install must add its own entry — the README install snippet includes the line), and treat
it as sensitive at rest, like a transcript. See `enforcement.md` for the boundary.

Sources: see [sources.md](./sources.md).
