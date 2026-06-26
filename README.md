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

Contributing or tracking upstream SDK changes? See
[`doc/DEVELOPMENT.md`](doc/DEVELOPMENT.md).

## Building and publishing the gem

The version lives in [`lib/ruby_claude/version.rb`](lib/ruby_claude/version.rb).
Before a release, bump it following [SemVer](https://semver.org).

### Build locally

```bash
gem build ruby_claude.gemspec             # => ruby_claude-<version>.gem
gem install ./ruby_claude-<version>.gem   # try the built gem locally
```

`spec.files` is derived from `git ls-files`, so only **tracked** files are
packaged — commit (or at least stage) your changes before building, or the gem
will be missing files. Bundler's gem tasks do the same and drop the artifact in
`pkg/`:

```bash
rake build      # build into pkg/
rake install    # build and install locally
```

### Publish to RubyGems

1. Create a [RubyGems.org](https://rubygems.org) account and sign in once
   (credentials are stored in `~/.gem/credentials`):

   ```bash
   gem signin
   ```

2. Make sure the tree is green and committed:

   ```bash
   rake            # tests + lint
   git status      # nothing uncommitted
   ```

3. Build and push:

   ```bash
   gem build ruby_claude.gemspec
   gem push ruby_claude-<version>.gem
   ```

Alternatively, do it all in one step with Bundler's release task, which builds
the gem, creates and pushes a `v<version>` git tag, and pushes to RubyGems
(requires a clean, committed tree):

```bash
rake release
```

> The gemspec sets `rubygems_mfa_required`, so enable MFA on your RubyGems
> account; pushes and yanks will then prompt for a one-time code.

## License

BSD-3-Clause. See [LICENSE](LICENSE).
