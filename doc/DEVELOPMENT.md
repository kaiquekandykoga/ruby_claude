# Development

How Ruby Claude stays aligned with upstream, and the workflow agents follow to
keep it that way. For day-to-day commands (tests, lint, build, publish) see the
[README](../README.md).

## Provenance

Ruby Claude is a hand-written, idiomatic Ruby port of Anthropic's official
**Agent SDKs** — there is no official Ruby SDK. The Python (`claude-agent-sdk`)
and TypeScript (`@anthropic-ai/claude-agent-sdk`) SDKs are themselves thin
wrappers that drive the **Claude Code CLI** (`claude -p`, the
`@anthropic-ai/claude-code` package). This gem mirrors their behavior and public
surface by shelling out to that same CLI; it is **not** generated or vendored
from them.

The CLI and SDKs evolve — new flags, output fields, event types, options. This
gem should track those and adopt what fits, while staying idiomatic Ruby and
dependency-free. The [Sync workflow](#sync-workflow) below is how that happens.

## Upstream baseline

The versions this gem was last reconciled against. There are **three** upstreams
to track, not just the CLI. Bump this table on every sync (and add a
[Sync log](#sync-log) entry) so the next diff has a starting point.

| Upstream | Package | Baseline | Repo & docs |
|----------|---------|----------|-------------|
| Claude Code CLI | `@anthropic-ai/claude-code` (npm) | **2.1.191** | [repo](https://github.com/anthropics/claude-code) · [changelog](https://code.claude.com/docs/en/changelog) · [headless](https://code.claude.com/docs/en/headless) · [CLI ref](https://code.claude.com/docs/en/cli-reference) |
| Python Agent SDK | `claude-agent-sdk` (PyPI) | **0.2.110** | [repo](https://github.com/anthropics/claude-agent-sdk-python) · [docs](https://code.claude.com/docs/en/agent-sdk/python) |
| TypeScript Agent SDK | `@anthropic-ai/claude-agent-sdk` (npm) | **0.3.193** | [repo](https://github.com/anthropics/claude-agent-sdk-typescript) · [docs](https://code.claude.com/docs/en/agent-sdk/typescript) |

**Last full sync:** 2026-06-26 — initial port. Behavior was verified against the
locally installed CLI **2.1.191**; the SDK docs were reviewed at the package
versions above. (The gem validates against the CLI; the SDKs are the design
reference for the public surface.)

## Sync workflow

Run this periodically, or whenever asked to "update against upstream." It is an
iterative loop: each pass records what it found so the next pass starts from a
known baseline.

1. **Check current versions** and compare to the baseline table:
   ```bash
   npm view @anthropic-ai/claude-code version          # CLI
   npm view @anthropic-ai/claude-agent-sdk version     # TypeScript SDK
   curl -s https://pypi.org/pypi/claude-agent-sdk/json | jq -r .info.version  # Python SDK
   claude --help                                        # current CLI flags
   ```
   If all three match the baseline, stop — there is nothing to sync.

2. **Collect the deltas** for each upstream that moved, from the authoritative
   sources — the repo's **Releases / CHANGELOG** on GitHub, then the matching
   docs page. Write down concrete changes only:
   - new / renamed / removed **CLI flags**
   - new fields in the `--output-format json` **result** object
   - new `--output-format stream-json` **message types** or content-block shapes
   - new **error / auth** conditions
   - new **options** exposed by the SDKs

3. **Decide scope** for each delta — adopt it, or skip it per the
   [guardrails](#scope-guardrails-intentionally-not-ported). Record *every*
   decision, including skips with a one-line reason, in the sync log (step 6).

4. **Implement** adopted deltas in the smallest layer (see
   [Concept mapping](#concept-mapping) and
   [When upstream changes](#when-upstream-changes-update-here)). Most additions
   are one flag in `Command` plus a `Configuration` accessor; parsing changes go
   in `Response` / `Event`.

5. **Test hermetically.** Extend the `Command` / `Response` / `Event` tests and
   `test/fixtures/`; never call the real `claude` or the network. `bundle exec
   rake` must be green.

6. **Record the sync.** Update the [baseline table](#upstream-baseline) (versions
   + "Last full sync"), add rows to the mapping tables if the surface changed,
   append a dated [Sync log](#sync-log) entry, and bump `RubyClaude::VERSION` if
   the public surface changed.

## Sync log

Append-only, newest first. One entry per sync: versions reviewed, what changed
upstream, and what this gem adopted or deliberately skipped. This is the running
record of how the gem has tracked the Claude repositories over time.

### 2026-06-26 — initial port
- Baseline established: CLI **2.1.191**, Python SDK **0.2.110**, TS SDK **0.3.193**.
- Verified flag mapping, the `--output-format json` result shape, and
  `stream-json` events against CLI 2.1.191 and the headless / CLI-reference /
  agent-sdk docs.
- Implemented the full intended public surface; nothing skipped beyond the
  standing guardrails below.

<!-- Template for the next entry:
### YYYY-MM-DD — short summary
- Versions: CLI x.y.z, Python a.b.c, TS d.e.f.
- Upstream changes reviewed: ...
- Adopted: ...
- Skipped (with reason): ...
-->

## Concept mapping

| Official Agent SDK (Python / TypeScript) | Ruby Claude |
|------------------------------------------|-------------|
| `query(prompt, options)` one-shot | `RubyClaude.query`, `Client#query` |
| `ClaudeAgentOptions` / options → CLI flags | `Configuration` + `Command` |
| `ResultMessage` (`--output-format json`) | `Response` |
| `SystemMessage` / `AssistantMessage` / `StreamEvent` (stream-json) | `Event` |
| Session resume (`--resume <id>`) | `Session` |
| Transport — spawning `claude` | `Runner` |

## When upstream changes, update here

| Upstream change | Update in Ruby Claude |
|-----------------|------------------------|
| New / renamed / removed CLI flag | `Command#build`; add/rename a `Configuration` accessor; README config table |
| New `--output-format json` result field | `Response.from_result` (+ `test/fixtures/result_*.json`) |
| New `stream-json` `type` / content shape | `Event.from_hash` / `Event.extract_text` (+ `test/fixtures/stream.txt`) |
| New failure / auth condition | `errors.rb`; `Client` translation (`AUTH_PATTERNS`, `interpret`) |
| New model ids / aliases | usually nothing (pass-through via `model`); refresh README examples |

## Scope guardrails (intentionally NOT ported)

Deliberate non-goals — keep them out even if the SDKs grow features around them:

- **No direct HTTP calls** to the Anthropic API; no API-key-first path (the key
  is used only when `use_subscription = false`).
- **No OAuth token extraction/handling** — auth is whatever the CLI is logged in with.
- **No interactive REPL/TUI** — Claude Code already is that.
- **Zero runtime gem dependencies** — standard library only (`open3`, `json`).
