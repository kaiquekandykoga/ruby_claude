# frozen_string_literal: true

module RubyClaude
  # Holds every tunable option with sane defaults.
  #
  # Used as the global default (via {RubyClaude.configure}) and as the basis
  # for per-{Client} overrides through {#merge}. A configuration is only ever
  # read while a query runs, never mutated, which keeps {Client} thread-safe.
  class Configuration
    # @return [String] executable name or path of the CLI
    attr_accessor :binary

    # @return [String, nil] model for +--model+ (nil uses the CLI default)
    attr_accessor :model

    # @return [String, nil] working directory for the subprocess
    attr_accessor :cwd

    # @return [Integer] seconds before the child process is killed
    attr_accessor :timeout

    # @return [Boolean] when true, strip +ANTHROPIC_API_KEY+ from the child env
    attr_accessor :use_subscription

    # @return [String, nil] text for +--append-system-prompt+
    attr_accessor :append_system_prompt

    # @return [Array<String>, String, nil] tools for +--allowedTools+
    attr_accessor :allowed_tools

    # @return [Array<String>, String, nil] tools for +--disallowedTools+
    attr_accessor :disallowed_tools

    # @return [Array<String>] directories for repeated +--add-dir+
    attr_accessor :add_dirs

    # @return [String, nil] mode for +--permission-mode+
    attr_accessor :permission_mode

    # @return [Integer, nil] limit for +--max-turns+
    attr_accessor :max_turns

    def initialize
      @binary = "claude"
      @model = nil
      @cwd = Dir.pwd
      @timeout = 300
      @use_subscription = true
      @append_system_prompt = nil
      @allowed_tools = nil
      @disallowed_tools = nil
      @add_dirs = []
      @permission_mode = nil
      @max_turns = nil
    end

    # Return a copy with the given overrides applied. The receiver is left
    # untouched, so the global configuration is never mutated by a {Client}.
    #
    # @param overrides [Hash{Symbol => Object}]
    # @return [Configuration]
    # @raise [ArgumentError] when an option is not recognized
    def merge(overrides)
      dup.tap do |copy|
        overrides.each do |key, value|
          setter = "#{key}="
          raise ArgumentError, "unknown configuration option: #{key}" unless copy.respond_to?(setter)

          copy.public_send(setter, value)
        end
      end
    end

    # @return [Hash{Symbol => Object}] a plain-hash view of the configuration
    def to_h
      {
        binary: binary, model: model, cwd: cwd, timeout: timeout,
        use_subscription: use_subscription, append_system_prompt: append_system_prompt,
        allowed_tools: allowed_tools, disallowed_tools: disallowed_tools,
        add_dirs: add_dirs, permission_mode: permission_mode, max_turns: max_turns
      }
    end

    private

    # Deep-copy the mutable array options so a {Client} can never mutate the
    # array held by the global configuration.
    def initialize_copy(source)
      super
      @add_dirs = source.add_dirs.dup if source.add_dirs.is_a?(Array)
      @allowed_tools = source.allowed_tools.dup if source.allowed_tools.is_a?(Array)
      @disallowed_tools = source.disallowed_tools.dup if source.disallowed_tools.is_a?(Array)
    end
  end
end
