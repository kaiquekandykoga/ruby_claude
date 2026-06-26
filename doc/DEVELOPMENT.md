# Development

Notes for maintaining Ruby Claude. For day-to-day commands (tests, lint,
building/publishing) see the **Development** and **Building and publishing the
gem** sections of the [README](../README.md). This document records *where the
design comes from* and *how to keep it in sync with upstream*.

## Provenance — based on the official Claude Agent SDKs

Anthropic ships official **Agent SDKs** in two languages:

- **Python** — [`claude-agent-sdk`](https://code.claude.com/docs/en/agent-sdk/python) (`from claude_agent_sdk import query, ClaudeAgentOptions`)
- **TypeScript** — [`@anthropic-ai/claude-agent-sdk`](https://code.claude.com/docs/en/agent-sdk/typescript) (`import { query } from "@anthropic-ai/claude-agent-sdk"`)

Both SDKs are, under the hood, thin wrappers that drive the **Claude Code CLI**
(`claude -p`, shipped as the `@anthropic-ai/claude-code` npm package). There is
no official Ruby SDK.

**Ruby Claude is a hand-written, idiomatic Ruby port of that same approach.** It
shells out to `claude -p` and shapes the CLI's JSON into Ruby objects. It is not
generated from, nor vendored from, the official SDKs — it deliberately *mirrors
their behavior and public surface* so Ruby users get a familiar experience.

**Why this is recorded:** the official SDKs and the CLI evolve — new flags, new
output fields, new message/event types, new options. This gem should track those
changes and adopt the worthwhile enhancements, while staying **idiomatic Ruby**
and **dependency-free** (standard library only). This doc is the map for doing
that.

## Upstream references (watch these for changes)

- Agent SDK overview: <https://code.claude.com/docs/en/agent-sdk/overview>
- Python SDK: <https://code.claude.com/docs/en/agent-sdk/python>
- TypeScript SDK: <https://code.claude.com/docs/en/agent-sdk/typescript>
- Headless / CLI usage (`claude -p`): <https://code.claude.com/docs/en/headless>
- CLI flag reference: <https://code.claude.com/docs/en/cli-reference>
- Docs map (good for diffing): <https://code.claude.com/docs/en/claude_code_docs_map.md>
- Changelog: <https://code.claude.com/docs/en/changelog>
- The binary itself: `claude --help`

> **Last verified against:** Claude Code CLI **v2.1.191** (2026-06-26).
> Update this line whenever you re-sync, so the next diff has a baseline.

## How official SDK concepts map to Ruby Claude

| Official Agent SDK (Python / TypeScript)         | Ruby Claude                          |
|--------------------------------------------------|--------------------------------------|
| `query(prompt, options)` one-shot call           | `RubyClaude.query`, `Client#query`   |
| `ClaudeAgentOptions` / options object → CLI flags | `Configuration` + `Command` (flag mapping) |
| `ResultMessage` (from `--output-format json`)    | `Response`                           |
| `SystemMessage` / `AssistantMessage` / `StreamEvent` (stream-json) | `Event`             |
| Resuming a session (`--resume <id>`)             | `Session`                            |
| Transport — spawning and talking to `claude`     | `Runner`                             |

## When upstream changes, update here

| Upstream change                                   | Update in Ruby Claude                                                   |
|---------------------------------------------------|-------------------------------------------------------------------------|
| New / renamed / removed CLI flag                  | `Command#build`; add or rename a `Configuration` accessor; README config table |
| New field in the `--output-format json` result   | `Response.from_result` (+ `test/fixtures/result_*.json`)                |
| New stream-json `type` or content-block shape     | `Event.from_hash` / `Event.extract_text` (+ `test/fixtures/stream.txt`) |
| New failure / auth condition                      | `errors.rb` and `Client` error translation (`AUTH_PATTERNS`, `interpret`) |
| New model ids / aliases                           | usually nothing (pass-through via `model`); refresh README examples     |

## Porting an enhancement — checklist

1. **Diff upstream.** Skim the changelog and the SDK / headless / CLI-reference
   pages since the "Last verified against" version above, and run `claude --help`
   to spot new flags.
2. **Decide scope.** Adopt only what fits this gem (see guardrails below); skip
   anything that needs the HTTP API or an interactive UI.
3. **Implement in the smallest layer.** Most additions are a single flag in
   `Command` plus an accessor in `Configuration`.
4. **Keep tests hermetic.** Extend the `Command` / `Response` / `Event` tests and
   fixtures. Never invoke the real `claude` binary or the network in tests — the
   `Client` takes an injected runner for exactly this.
5. **Stay green.** `bundle exec rake` (tests + lint) must pass.
6. **Bump the version.** Update `RubyClaude::VERSION` (SemVer) and the README if
   the public surface changed.
7. **Update the baseline.** Bump the "Last verified against" line above.

## Scope guardrails (intentionally NOT ported)

These are deliberate non-goals — keep them out even if the official SDKs grow
features around them:

- **No direct HTTP calls** to the Anthropic API, and no API-key-first path. The
  API key is honored only when a user opts out via `use_subscription = false`.
- **No OAuth token extraction or handling.** Authentication is whatever the CLI
  is logged in with.
- **No interactive REPL/TUI.** Claude Code already is the interactive CLI.
- **Zero runtime gem dependencies.** Standard library only (`open3`, `json`).
