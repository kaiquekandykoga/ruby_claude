# Ruby Claude

A tiny, zero-dependency Ruby SDK for Claude that shells out to the **Claude Code
CLI** (`claude -p`) and authenticates with your **Claude Pro/Max subscription**
instead of an API key.

> **Unofficial** community gem — not affiliated with Anthropic. It uses the
> supported `claude -p` headless mode within your subscription's rate limits; no
> OAuth-token handling and no direct API calls.

## Subscription, not API key

`claude -p` uses whatever the CLI is logged in with — if that's a subscription,
calls draw on it with no API billing. Ruby Claude **strips `ANTHROPIC_API_KEY`
from the child environment by default** so the CLI can't silently fall back to
API billing; set `use_subscription = false` to opt back in.

## Prerequisites

`claude` must be installed and logged in (this gem drives it, it doesn't replace it):

```bash
npm install -g @anthropic-ai/claude-code
claude        # run /login once and choose the subscription option
```

## Install

```ruby
gem "ruby_claude"   # in your Gemfile
```

…or `gem install ruby_claude`. Requires Ruby 3.2+; zero runtime dependencies.

## Quickstart

```ruby
require "ruby_claude"

puts RubyClaude.query("Summarize lib/foo.rb in two sentences")
```

## Usage

```ruby
# A configured client
client = RubyClaude::Client.new(model: "claude-sonnet-4-6",
                                allowed_tools: ["Read", "Grep"], timeout: 180)

res = client.query("What does this project do?")
res.text         # final text (Response#to_s returns it too, so `puts res` works)
res.session_id   # String
res.cost_usd     # Float (often 0.0 on a subscription)
res.usage        # Hash   — also: res.num_turns, res.duration_ms, res.error?, res.raw

# Streaming — yields typed events, returns the final Response
client.stream("Write a haiku about Ruby") do |event|
  print event.text if event.type == :assistant
end

# Multi-turn session — resumes the underlying session_id automatically
chat = client.session
chat.query("My favorite number is 7.")
puts chat.query("What's my favorite number?")   # => "...7..."

# Global defaults for RubyClaude.query and new clients
RubyClaude.configure { |c| c.model = "claude-sonnet-4-6"; c.timeout = 300 }
```

A streaming `Event#type` is `:system`, `:assistant`, `:user`, or `:result`. Use
`#query` (alias `#ask`) — there is intentionally no `#send`.

## Configuration

`Client.new(**opts)` overrides per instance; `RubyClaude.configure` sets globals.

| Option | Default | Maps to |
|--------|---------|---------|
| `binary` | `"claude"` | executable name/path |
| `model` | `nil` | `--model` |
| `cwd` | `Dir.pwd` | subprocess working directory |
| `timeout` | `300` | seconds before the child is killed |
| `use_subscription` | `true` | strip `ANTHROPIC_API_KEY` from the child env |
| `append_system_prompt` | `nil` | `--append-system-prompt` |
| `allowed_tools` / `disallowed_tools` | `nil` | `--allowedTools` / `--disallowedTools` |
| `add_dirs` | `[]` | `--add-dir` |
| `permission_mode` | `nil` | `--permission-mode` |
| `max_turns` | `nil` | `--max-turns` |

## Errors

All subclass `RubyClaude::Error`: `BinaryNotFoundError` (no `claude` on PATH),
`AuthenticationError` (not logged in), `TimeoutError`, `ExecutionError` (non-zero
exit or an `is_error` result; carries `#status`/`#stderr`), and `ParseError`.

## How it works

`Command` builds the argv + child env (pure, no I/O); `Runner` spawns `claude`
via `Open3` (array form — no shell; prompt on stdin), enforces the timeout, and
parses output; `Client` builds `Response`/`Event`; `Session` resumes via
`--resume`. The runner is stateless per call, so a `Client` is safe to share
across threads.

## Development

```bash
bundle exec rake        # tests + lint (hermetic — never spawns the real claude)
bin/console             # IRB with the gem loaded
```

Publish with `gem build ruby_claude.gemspec && gem push ruby_claude-<version>.gem`
(or `rake release`). Contributing or tracking upstream SDK changes? See
[`doc/DEVELOPMENT.md`](doc/DEVELOPMENT.md).

## License

BSD-3-Clause. See [LICENSE](LICENSE).
