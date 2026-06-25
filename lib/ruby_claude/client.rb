# frozen_string_literal: true

require "json"

module RubyClaude
  # Composes a {Command} and a {Runner} to execute queries and build
  # {Response} and {Event} objects.
  #
  # A client holds an immutable {Configuration} and a stateless runner, builds
  # fresh argv/env per call, and never mutates shared state — so one instance
  # is safe to reuse and to call concurrently from many threads.
  class Client
    # Heuristic patterns in stderr/result text that indicate an auth problem.
    AUTH_PATTERNS = Regexp.union(
      /invalid api key/i,
      /authentication/i,
      /unauthorized/i,
      /not logged ?in/i,
      %r{/login}i,
      /oauth/i,
      /log ?in to claude/i,
      /credit balance/i,
      /api key/i
    ).freeze

    # @return [Configuration] the effective configuration for this client
    attr_reader :config

    # @param runner [#run, #stream] subprocess runner (injectable for tests)
    # @param overrides [Hash] per-instance {Configuration} overrides
    # @raise [ArgumentError] on an unknown configuration option
    def initialize(runner: Runner.new, **overrides)
      @config = RubyClaude.configuration.merge(overrides)
      @runner = runner
    end

    # Run a one-shot query and return its {Response}.
    #
    # @param prompt [String]
    # @param resume [String, nil] a session id to resume
    # @return [Response]
    # @raise [AuthenticationError, ExecutionError, ParseError, TimeoutError,
    #   BinaryNotFoundError]
    def query(prompt, resume: nil)
      argv, env = Command.new(@config).build(stream: false, resume: resume)
      result = @runner.run(**run_args(argv, env, prompt))
      interpret(result)
    end
    alias ask query

    # Stream a query, yielding {Event}s as they arrive.
    #
    # @param prompt [String]
    # @param resume [String, nil] a session id to resume
    # @yieldparam event [Event]
    # @return [Response] the final result, built from the +result+ event
    # @raise [AuthenticationError, ExecutionError, TimeoutError,
    #   BinaryNotFoundError]
    def stream(prompt, resume: nil)
      argv, env = Command.new(@config).build(stream: true, resume: resume)
      final = nil
      result = @runner.stream(**run_args(argv, env, prompt)) do |line|
        data = try_parse(line)
        next unless data

        final = data if data["type"] == "result"
        yield Event.from_hash(data) if block_given?
      end
      check_stream_result!(final, result)
      Response.from_result(final)
    end

    # Start a multi-turn {Session} backed by this client.
    #
    # @param id [String, nil] an existing session id to resume
    # @return [Session]
    def session(id: nil)
      Session.new(self, id: id)
    end

    private

    def run_args(argv, env, prompt)
      { argv: argv, env: env, cwd: @config.cwd, timeout: @config.timeout, stdin: prompt.to_s }
    end

    # Turn a one-shot {RunResult} into a {Response} or raise a typed error.
    def interpret(result)
      data = try_parse(result.stdout)
      if data.is_a?(Hash) && data["type"] == "result"
        raise_result_error!(data, result) if data["is_error"]
        return Response.from_result(data)
      end

      raise failure_for(result) if failed?(result)

      raise ParseError, "could not parse claude output as JSON: #{truncate(result.stdout)}"
    end

    def check_stream_result!(final, result)
      raise_result_error!(final, result) if final && final["is_error"]
      raise failure_for(result) if final.nil? && failed?(result)
    end

    def failed?(result)
      status = result.exit_status
      status.nil? || !status.zero?
    end

    def raise_result_error!(data, result)
      detail = data["result"] || data["errors"]&.join("; ") || "subtype=#{data["subtype"]}"
      raise AuthenticationError, auth_message(detail) if auth?(detail, result&.stderr)

      raise ExecutionError.new(
        "claude returned an error result: #{detail}",
        status: result&.exit_status,
        stderr: result&.stderr
      )
    end

    def failure_for(result)
      stderr = result.stderr.to_s
      return AuthenticationError.new(auth_message(stderr.strip)) if auth?(stderr, result.stdout)

      status = result.exit_status
      ExecutionError.new(
        "claude exited with status #{status || "signal"}: #{truncate(stderr)}",
        status: status,
        stderr: stderr
      )
    end

    def auth?(*sources)
      sources.compact.any? { |source| AUTH_PATTERNS.match?(source.to_s) }
    end

    def auth_message(detail)
      base = "Claude authentication failed. Run `claude` and use `/login` to sign in with " \
             "your Claude subscription (or set use_subscription = false to use ANTHROPIC_API_KEY)."
      detail.nil? || detail.empty? ? base : "#{base}\n#{detail}"
    end

    def try_parse(string)
      return nil if string.nil? || string.strip.empty?

      JSON.parse(string)
    rescue JSON::ParserError
      nil
    end

    def truncate(string, max = 500)
      stripped = string.to_s.strip
      stripped.length > max ? "#{stripped[0, max]}..." : stripped
    end
  end
end
