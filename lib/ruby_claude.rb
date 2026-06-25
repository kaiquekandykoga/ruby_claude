# frozen_string_literal: true

require_relative "ruby_claude/version"
require_relative "ruby_claude/errors"
require_relative "ruby_claude/configuration"
require_relative "ruby_claude/response"
require_relative "ruby_claude/event"
require_relative "ruby_claude/command"
require_relative "ruby_claude/runner"
require_relative "ruby_claude/session"
require_relative "ruby_claude/client"

# Ruby Claude — a subscription-authenticated Ruby SDK that talks to Claude by
# shelling out to the Claude Code CLI (+claude -p+) in headless mode.
#
# It is an unofficial, community wrapper around a supported headless feature.
# By default it strips +ANTHROPIC_API_KEY+ from the child environment so calls
# draw on the logged-in Pro/Max subscription rather than API billing.
#
# @example One-shot
#   puts RubyClaude.query("Summarize lib/foo.rb in two sentences")
#
# @example A configured client
#   client = RubyClaude::Client.new(model: "claude-sonnet-4-6", timeout: 180)
#   client.query("What does this project do?").text
module RubyClaude
  class << self
    # The global configuration used by {RubyClaude.query} and as the default
    # for new {Client} instances.
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the global defaults.
    #
    # @yieldparam config [Configuration]
    # @return [Configuration]
    def configure
      yield configuration if block_given?
      @default_client = nil # rebuild with the new configuration on next use
      configuration
    end

    # Reset all global state. Mainly useful in tests.
    #
    # @return [void]
    def reset_configuration!
      @configuration = Configuration.new
      @default_client = nil
    end

    # One-shot convenience that delegates to a memoized default {Client}.
    #
    # @param prompt [String]
    # @param options [Hash] forwarded to {Client#query} (e.g. +resume:+)
    # @return [Response]
    def query(prompt, **options)
      default_client.query(prompt, **options)
    end

    # The memoized default {Client}, rebuilt whenever {configure} is called.
    #
    # @return [Client]
    def default_client
      @default_client ||= Client.new
    end
  end
end
