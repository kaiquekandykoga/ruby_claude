# frozen_string_literal: true

module RubyClaude
  # Pure translation of a {Configuration} plus per-call options into the argv
  # array and child-environment overrides for the +claude+ CLI.
  #
  # Performs no I/O, which makes flag mapping trivial to unit-test. The prompt
  # is intentionally *never* part of argv — it is written to the child's stdin
  # by the {Runner} to avoid +ARG_MAX+ limits and shell-escaping concerns.
  class Command
    # @param config [Configuration]
    def initialize(config)
      @config = config
    end

    # Build the argv array and child-environment overrides.
    #
    # @param stream [Boolean] use stream-json output (also adds +--verbose+,
    #   which the CLI requires for stream-json in print mode)
    # @param resume [String, nil] a session id to resume via +--resume+
    # @return [Array(Array<String>, Hash)] +[argv, env]+
    def build(stream:, resume: nil)
      argv = [@config.binary, "-p", "--output-format", stream ? "stream-json" : "json"]
      argv << "--verbose" if stream
      add_flag(argv, "--model", @config.model)
      add_flag(argv, "--append-system-prompt", @config.append_system_prompt)
      add_list(argv, "--allowedTools", @config.allowed_tools)
      add_list(argv, "--disallowedTools", @config.disallowed_tools)
      add_list(argv, "--add-dir", @config.add_dirs)
      add_flag(argv, "--permission-mode", @config.permission_mode)
      add_flag(argv, "--max-turns", @config.max_turns&.to_s)
      add_flag(argv, "--resume", resume)
      [argv, child_env]
    end

    # Environment overrides for the child process. In subscription mode,
    # +ANTHROPIC_API_KEY+ is mapped to +nil+, which tells +Open3+/+spawn+ to
    # remove it from the inherited environment so the CLI falls back to the
    # logged-in subscription credentials.
    #
    # @return [Hash{String => String, nil}]
    def child_env
      return {} unless @config.use_subscription

      { "ANTHROPIC_API_KEY" => nil }
    end

    private

    # Append +flag value+ when +value+ is present.
    def add_flag(argv, flag, value)
      return if value.nil?

      string = value.to_s
      return if string.empty?

      argv.push(flag, string)
    end

    # Append +flag item item ...+ (each list item as its own argv token, which
    # matches the CLI's space-separated variadic options and preserves spaces
    # inside permission-rule patterns such as +Bash(git log *)+).
    def add_list(argv, flag, value)
      items = Array(value).map(&:to_s).reject(&:empty?)
      return if items.empty?

      argv.push(flag, *items)
    end
  end
end
