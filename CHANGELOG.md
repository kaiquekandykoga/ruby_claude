# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-26

### Added

- Initial release.
- `RubyClaude.query` one-shot convenience backed by a memoized default client.
- `RubyClaude::Client` with `#query` (one-shot `Response`), `#stream` (yields
  typed `Event`s, returns the final `Response`), and `#session`.
- `RubyClaude::Session` for multi-turn conversations that transparently resume
  via the underlying `session_id` (`--resume`).
- Immutable `Response` and `Event` value objects (`Data.define`).
- `RubyClaude::Configuration` and `RubyClaude.configure` with sane defaults.
- Subscription mode (`use_subscription`, default `true`): strips
  `ANTHROPIC_API_KEY` from the child process environment so the CLI uses the
  logged-in Pro/Max subscription rather than API billing.
- Typed error hierarchy: `Error`, `BinaryNotFoundError`, `AuthenticationError`,
  `TimeoutError`, `ExecutionError`, `ParseError`.
- Prompts are passed to the CLI via stdin and commands are spawned with the
  array form of `Open3` (never via a shell), with timeout enforcement.
- Zero runtime dependencies; requires Ruby 3.2+.

[Unreleased]: https://github.com/kaiquekandykoga/ruby_claude/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kaiquekandykoga/ruby_claude/releases/tag/v0.1.0
