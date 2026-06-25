# Ruby Claude

A small, dependency-light, idiomatic Ruby SDK for talking to Claude — by
shelling out to the **Claude Code CLI** (`claude -p`) in headless mode and
authenticating with your **Claude Pro/Max subscription** instead of an
Anthropic API key.

> **Unofficial.** This is a community gem. It is *not* affiliated with or
> endorsed by Anthropic. It uses a documented, supported headless feature
> (`claude -p`) and stays within your subscription's normal rate limits. It
> does **not** extract or reuse OAuth tokens, and it makes **no** direct HTTP
> calls to the Anthropic API.

## Why a subscription instead of an API key?

`claude -p "<prompt>"` runs Claude Code non-interactively and prints the
result, using whatever credentials the CLI is logged in with. If you logged in
with a **subscription** (`claude` → `/login` → subscription option), those
calls draw on your subscription — **no API billing**.

The one catch: if `ANTHROPIC_API_KEY` is present in the environment, Claude
Code may use it and bill the API. **Ruby Claude strips `ANTHROPIC_API_KEY`
from the child process environment by default** (`use_subscription = true`) so
the CLI falls back to your logged-in subscription credentials. Set
`use_subscription = false` only if you *want* API-key billing.

## Prerequisites

This gem drives the `claude` binary; it does not install or replace it.

1. Install Node.js and the Claude Code CLI, and make sure `claude` is on your `PATH`:
   ```bash
   npm install -g @anthropic-ai/claude-code
   claude --version
   ```
2. Log in **once**, choosing the subscription option:
   ```bash
   claude        # then run /login and pick "Claude account with subscription"
   ```

## Installation

Add it to your `Gemfile`:

```ruby
gem "ruby_claude"
```

Or install directly:

```bash
gem install ruby_claude
```

Ruby **3.2+** is required (the value objects use `Data.define`). The gem has
**zero runtime dependencies** — it only uses the standard library.

## Quickstart

```ruby
require "ruby_claude"

puts RubyClaude.query("Summarize lib/foo.rb in two sentences")
```

That's it — if `claude` is installed and logged in, you get an answer back,
billed against your subscription.

## Usage

### 1. One-shot convenience

Delegates to a memoized, globally-configured default client.

```ruby
puts RubyClaude.query("Summarize lib/foo.rb in two sentences")
```

### 2. A configured client

```ruby
client = RubyClaude::Client.new(
  model: "claude-sonnet-4-6",
  cwd: "/path/to/project",
  append_system_prompt: "Always answer concisely.",
  allowed_tools: ["Read", "Grep"],
  timeout: 180
)

res = client.query("What does this project do?")
res.text        # => String, the final assistant result
res.session_id  # => String
res.cost_usd    # => Float (often 0.0 on a subscription)
res.usage       # => Hash (token counts, when present)
res.num_turns   # => Integer
res.duration_ms # => Integer
res.error?      # => false
res.raw         # => parsed Hash of the CLI's final result JSON
```

`Response#to_s` returns `text`, so `puts client.query("...")` prints the answer.

### 3. Streaming

`#stream` yields typed events as they arrive and returns the final `Response`.

```ruby
client.stream("Write a haiku about Ruby") do |event|
  case event.type
  when :assistant then print event.text   # assistant text for the turn
  when :result    then puts "\n[done in #{event.duration_ms}ms]"
  end
end
```

Each `Event` exposes `type` (`:system`, `:assistant`, `:user`, `:result`),
`text`, `session_id`, `cost_usd`, `duration_ms`, and `raw` (the full parsed
line). Streaming uses `--output-format stream-json --verbose` under the hood.

### 4. Multi-turn session

A `Session` captures the underlying `session_id` from the first reply and
transparently resumes it on later calls.

```ruby
session = client.session
session.query("My favorite number is 7.")
puts session.query("What's my favorite number?")  # => "...7..."
session.id  # => the session_id being resumed
```

You can also resume a known session: `client.session(id: "…")`.

### 5. Global configuration

```ruby
RubyClaude.configure do |c|
  c.model            = "claude-sonnet-4-6"
  c.timeout          = 300
  c.binary           = "claude"   # path/name of the CLI
  c.cwd              = Dir.pwd
  c.use_subscription = true       # strips ANTHROPIC_API_KEY from the child env
end
```

These become the defaults for `RubyClaude.query` and for new `Client`
instances. Per-client options passed to `Client.new(**opts)` override them.

> **Note:** there is intentionally no `#send` method (it would shadow
> `Object#send`). Use `#query`, or its alias `#ask`.

## Configuration options

| Option                 | Default              | Maps to / effect                                                          |
|------------------------|----------------------|---------------------------------------------------------------------------|
| `binary`               | `"claude"`           | executable name/path                                                      |
| `model`                | `nil` (CLI default)  | `--model`                                                                 |
| `cwd`                  | `Dir.pwd`            | working directory for the subprocess                                      |
| `timeout`              | `300`                | seconds before the child is killed                                        |
| `use_subscription`     | `true`               | when true, delete `ANTHROPIC_API_KEY` from the child env                  |
| `append_system_prompt` | `nil`                | `--append-system-prompt`                                                  |
| `allowed_tools`        | `nil`                | `--allowedTools` (array of tool/permission rules)                         |
| `disallowed_tools`     | `nil`                | `--disallowedTools`                                                       |
| `add_dirs`             | `[]`                 | `--add-dir` (extra readable/writable directories)                         |
| `permission_mode`      | `nil`                | `--permission-mode` (`default` / `acceptEdits` / `plan` / `bypassPermissions`) |
| `max_turns`            | `nil`                | `--max-turns`                                                             |

Tool and directory lists are passed as separate CLI tokens, so permission-rule
patterns that contain spaces (e.g. `"Bash(git log *)"`) are preserved.

## Errors

All errors inherit from `RubyClaude::Error`:

| Error                            | Raised when                                                                 |
|----------------------------------|-----------------------------------------------------------------------------|
| `RubyClaude::BinaryNotFoundError`| `claude` is not on `PATH` / not executable (message explains how to install)|
| `RubyClaude::AuthenticationError`| output/exit indicates you are not logged in (suggests `claude` + `/login`)  |
| `RubyClaude::TimeoutError`       | the child exceeded `timeout`; the gem killed it                             |
| `RubyClaude::ExecutionError`     | non-zero exit, or a result with `is_error: true` (carries `#status`, `#stderr`) |
| `RubyClaude::ParseError`         | the CLI output couldn't be parsed as the expected JSON                      |

```ruby
begin
  RubyClaude.query("hello")
rescue RubyClaude::BinaryNotFoundError => e
  warn e.message   # install + /login instructions
rescue RubyClaude::AuthenticationError
  warn "Run `claude` and `/login` with your subscription."
rescue RubyClaude::ExecutionError => e
  warn "claude failed (status #{e.status}): #{e.stderr}"
end
```

## How it works

Ruby Claude is a thin, well-factored wrapper around `claude -p`:

- **`Command`** (pure, no I/O) turns your configuration + per-call options into
  the argv array (`["claude", "-p", "--output-format", "json", …]`) and the
  child-environment overrides (removing `ANTHROPIC_API_KEY` in subscription mode).
- **`Runner`** owns all subprocess concerns: it spawns `claude` via `Open3`
  (always the array form — your prompt is **never** shell-interpolated), writes
  the prompt to **stdin** (avoiding `ARG_MAX` and escaping issues), enforces the
  timeout by killing the child, captures output, and — for streaming — reads
  stdout line-by-line as newline-delimited JSON.
- **`Client`** composes the two and builds `Response` / `Event` objects.
- **`Session`** remembers the `session_id` and passes `--resume <id>`.

The runner is stateless and spawns one subprocess per call, so a `Client` is
safe to reuse and to call concurrently from multiple threads.

## Development

```bash
bundle install   # install dev/test dependencies
rake test        # run the test suite (hermetic — never spawns claude)
rake lint        # rubocop
rake             # test + lint
bin/console      # IRB with the gem loaded
```

Tests inject a fake runner at the `Client`'s runner boundary, so the suite is
fully hermetic: it never makes a network call and never invokes the real
`claude` binary. (A handful of `Runner` tests spawn a throwaway local `ruby`
process to exercise the subprocess plumbing.)

## Building and publishing the gem

The version lives in [`lib/ruby_claude/version.rb`](lib/ruby_claude/version.rb).
Before a release, bump it following [SemVer](https://semver.org).

### Build locally

```bash
gem build ruby_claude.gemspec        # => ruby_claude-<version>.gem
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

   The name `ruby_claude` is currently available on RubyGems. Releasing
   `0.0.0` is unusual — bump to e.g. `0.1.0` for your first real publish.

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
