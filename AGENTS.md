# AGENTS.md

Ruby gem wrapping the Claude Code CLI (`claude -p`) with subscription auth; a
hand-written Ruby port of Anthropic's official Python/TS Agent SDKs.

## Rules
- Ruby 3.2+, zero runtime deps — stdlib only (`open3`, `json`).
- Every `.rb` starts with `# frozen_string_literal: true`. Double-quoted strings.
- Never invoke a shell: array-form `Open3` only; prompt via stdin, never argv.
- Keep the public API stable. Flag mapping → `Command`; JSON parsing → `Response`/`Event`.

## Before committing
- `bundle exec rake` (tests + lint) must pass.
- Tests stay hermetic: inject a fake runner; never spawn real `claude` or hit the network.

## doc/DEVELOPMENT.md
If a change touches the upstream relationship (CLI/SDK flag, JSON shape, event
type, error, version bump, or scope), update `doc/DEVELOPMENT.md` per its **Sync
workflow** in the same commit.

## Pointers
Human usage → `README.md`. Provenance, baseline versions, sync workflow → `doc/DEVELOPMENT.md`.
