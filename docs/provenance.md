# Provenance: the delegation trace

When an agent delegates to a subagent, swarm-agents leaves a reviewable record of the handoff. The
contract is canon (ADR-0088); this is how the producers here emit it and how it relates to the wider
standards.

## The contract (ADR-0088)

Per agent→subagent handoff, a trace records: `worker` (the subagent/role), `reason` (why it was
delegated to), `inputs` (what it received), `filtered` (what context was withheld — `fresh-context` /
`inherited`), `tools` (what it was granted), `could_edit` (true/false), `evidence` (what it returned),
and `ts`/`event`. It is **a record, never a verdict** (ADR-0077 D8): a missing or thin trace is a
human-attention fact, not a failure. No checker mints it (convention-first, ADR-0063/0092).

## The two producers

- **`swarm run --agent`** (in swarm-cli) writes a `provenance` block + `changed_files` in its
  run-record for the workers it launches. (Producer 1; lives in swarm-cli.)
- **`hooks/delegations.sh`** (here) appends one NDJSON line per `SubagentStart`/`SubagentStop` to
  `.swarm/work/delegations.ndjson` — because in-session subagents bypass the CLI. (Producer 2.)

## Alignment with the standards (don't reinvent names)

- **HDP** (Human Delegation Provenance — arXiv 2604.04522; IETF
  draft-helixar-hdp-agentic-delegation-00) defines a signed, append-only delegation trace (delegating
  agent id/type, timestamp, action summary, parent-hop index, chained Ed25519 signatures over prior
  hops). It is more rigorous than our plaintext NDJSON, and it draws the **same boundary we do**: it
  provides the *record*, not enforcement of actions against scope ("an application-layer concern").
  Treat HDP as the rigorous future (signing, tamper-evidence); our fields are the lightweight, same-
  shape record.
- **OpenTelemetry GenAI** conventions give reusable attribute names —
  `gen_ai.agent.name`/`.id`, `gen_ai.request.model`, `gen_ai.tool.definitions` — but **no
  agent-to-agent handoff semantics yet** (the delegation-attributes proposal, semconv-genai #35, is
  open). Align names where they overlap; the handoff gap is what this trace fills.

## What it buys

Reviewability and attribution — *who* was delegated *what*, with which tools and edit rights, and what
came back. **Not** a behavioral guarantee, and **not** tamper-evident (plaintext, unsigned — that's
the HDP upgrade path). See `enforcement.md` for the boundary.

Sources: see [sources.md](./sources.md).
