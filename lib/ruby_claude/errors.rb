# frozen_string_literal: true

module RubyClaude
  # Base class for every error raised by Ruby Claude.
  class Error < StandardError; end

  # Raised when the +claude+ binary cannot be found on PATH or executed.
  #
  # The message explains how to install Claude Code and reminds the user that
  # they must run +claude+ and +/login+ at least once.
  class BinaryNotFoundError < Error; end

  # Raised when the CLI output or exit status indicates the user is not
  # logged in or that authentication otherwise failed.
  class AuthenticationError < Error; end

  # Raised when the child process exceeds the configured timeout and the gem
  # kills it.
  class TimeoutError < Error; end

  # Raised on a non-zero exit status, or on a result payload that reports
  # +is_error: true+. Carries the exit status and captured stderr.
  class ExecutionError < Error
    # @return [Integer, nil] the child process exit status, when known
    attr_reader :status

    # @return [String, nil] captured standard error output, when available
    attr_reader :stderr

    # @param message [String, nil]
    # @param status [Integer, nil]
    # @param stderr [String, nil]
    def initialize(message = nil, status: nil, stderr: nil)
      @status = status
      @stderr = stderr
      super(message)
    end
  end

  # Raised when the CLI output cannot be parsed as the expected JSON.
  class ParseError < Error; end
end
