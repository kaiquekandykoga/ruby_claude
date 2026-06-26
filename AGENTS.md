# AGENTS.md

Guidance for AI agents (and humans) working in this repository.

**Ruby Claude** is a small, zero-dependency Ruby gem that wraps the Claude Code
CLI (`claude -p`) in headless mode, authenticating via a Claude subscription. It
is a hand-written Ruby port of Anthropic's official Python and TypeScript Agent
SDKs — see [`doc/DEVELOPMENT.md`](doc/DEVELOPMENT.md) for that relationship.

## Keep `doc/DEVELOPMENT.md` up to date

[`doc/DEVELOPMENT.md`](doc/DEVELOPMENT.md) records how this gem stays aligned with
the official Claude Agent SDKs and the Claude Code CLI. **Whenever your change
affects that relationship, update it in the same commit.** Specifically:

- You **port or adopt an upstream change** — a new / renamed / removed CLI flag, a
  new field in the `--output-format json` result, a new `stream-json` event type
  or content shape, or a new error / auth condition. Update the matching row in
  the "When upstream changes, update here" table.
- You **re-verify the gem against a newer `claude` CLI version** — bump the
  **"Last verified against"** line (version + date) at the top of that doc.
- You **add or rename a public class or configuration option** that corresponds
  to an official SDK concept — update the concept-mapping table.
- You **change a scope decision** — anything under "Scope guardrails" / non-goals.

If a change does not touch the upstream relationship (an internal refactor, a
typo fix, a test-only change), you do not need to edit `doc/DEVELOPMENT.md`.

## Conventions (do not break)

- **Ruby 3.2+**, **zero runtime dependencies** — standard library only (`open3`,
  `json`). Dev/test dependencies live in the gemspec.
- Every `.rb` file begins with `# frozen_string_literal: true`.
- **Never invoke a shell.** Always use the array form of `Open3`; the user's
  prompt is written to the child via **stdin**, never passed as an argv item.
- Strings are **double-quoted** (the one RuboCop rule that is enabled).
- Keep the public API stable. CLI flag mapping lives in `Command`; result/stream
  JSON parsing lives in `Response` and `Event`.

## Commands

```bash
bundle exec rake        # tests + lint (default task)
bundle exec rake test   # tests only — hermetic, never spawns the real claude
bundle exec rake lint   # RuboCop
```

Tests must stay **hermetic**: inject a fake runner at the `Client`'s runner
boundary; never call the real `claude` binary or the network. A few `Runner`
tests spawn a throwaway local `ruby` process, never `claude`.

## More context

- Public API, configuration, errors, "how it works": [README](README.md).
- Provenance, upstream references, and the porting checklist:
  [`doc/DEVELOPMENT.md`](doc/DEVELOPMENT.md).
