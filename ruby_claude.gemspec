# frozen_string_literal: true

require_relative "lib/ruby_claude/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_claude"
  spec.version = RubyClaude::VERSION
  spec.authors = ["Kaíque Kandy Koga"]
  spec.email = ["kaique.koga@javln.com"]

  spec.summary = "Subscription-authenticated Ruby SDK for Claude via the Claude Code CLI."
  spec.description = <<~DESC
    Ruby Claude is a small, dependency-light, idiomatic Ruby wrapper around the
    Claude Code CLI in headless mode (claude -p). It lets Ruby programs talk to
    Claude using a Claude Pro/Max subscription for authentication instead of an
    Anthropic API key: by default it strips ANTHROPIC_API_KEY from the child
    process environment so the CLI falls back to the logged-in subscription
    credentials. Unofficial; uses a supported headless feature within the
    subscription's rate limits.
  DESC
  spec.homepage = "https://github.com/kaiquekandykoga/ruby_claude"
  spec.license = "BSD-3-Clause"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").select do |path|
      path.start_with?("lib/") ||
        %w[README.md CHANGELOG.md LICENSE ruby_claude.gemspec].include?(path)
    end
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "test-unit", "~> 3.6"
  spec.add_development_dependency "yard", "~> 0.9"
end
