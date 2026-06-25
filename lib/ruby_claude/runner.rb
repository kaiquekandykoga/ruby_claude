# frozen_string_literal: true

require "open3"

module RubyClaude
  # The captured result of a completed subprocess run.
  #
  # @!attribute [r] stdout
  #   @return [String, nil] captured stdout (nil when streaming)
  # @!attribute [r] stderr
  #   @return [String] captured stderr
  # @!attribute [r] exit_status
  #   @return [Integer, nil] exit code, or nil if the process was signalled
  RunResult = Data.define(:stdout, :stderr, :exit_status)

  # Owns every subprocess concern: spawning +claude+ via +Open3+, writing the
  # prompt to stdin, enforcing the timeout by killing the child, capturing
  # output, and translating spawn failures into {BinaryNotFoundError}.
  #
  # The runner is stateless, so a single instance is safe to share across
  # threads. The {Client} accepts an injected runner so tests never spawn.
  class Runner
    # Seconds to wait after +SIGTERM+ before escalating to +SIGKILL+.
    KILL_GRACE = 2

    # Run the command to completion and capture its output.
    #
    # @param argv [Array<String>] the command and its arguments
    # @param env [Hash] environment overrides (nil values unset a variable)
    # @param cwd [String, nil] working directory
    # @param timeout [Numeric] seconds before the child is killed
    # @param stdin [String, nil] data to write to the child's stdin
    # @return [RunResult]
    # @raise [TimeoutError] if the child exceeds +timeout+
    # @raise [BinaryNotFoundError] if the binary cannot be executed
    def run(argv:, env:, cwd:, timeout:, stdin: nil)
      spawn(argv, env, cwd) do |stdin_io, stdout_io, stderr_io, wait_thr|
        out_reader = Thread.new { stdout_io.read }
        err_reader = Thread.new { stderr_io.read }
        write_stdin(stdin_io, stdin)

        if wait_thr.join(timeout).nil?
          terminate(wait_thr)
          out_reader.kill
          err_reader.kill
          raise TimeoutError, "claude did not finish within #{timeout}s; the process was killed"
        end

        RunResult.new(
          stdout: out_reader.value,
          stderr: err_reader.value,
          exit_status: wait_thr.value.exitstatus
        )
      end
    end

    # Run the command and yield each non-empty stdout line as it arrives.
    #
    # @param (see #run)
    # @yieldparam line [String] one chomped, non-empty stdout line
    # @return [RunResult] with +stdout+ nil (it was streamed, not captured)
    # @raise [TimeoutError] if the child exceeds +timeout+
    # @raise [BinaryNotFoundError] if the binary cannot be executed
    def stream(argv:, env:, cwd:, timeout:, stdin: nil)
      spawn(argv, env, cwd) do |stdin_io, stdout_io, stderr_io, wait_thr|
        err_reader = Thread.new { stderr_io.read }
        # Write stdin on its own thread so a prompt larger than the OS pipe
        # buffer can't deadlock against stdout we haven't started reading yet.
        writer = Thread.new { write_stdin(stdin_io, stdin) }
        timed_out = false
        watchdog = Thread.new do
          sleep(timeout)
          timed_out = true
          terminate(wait_thr)
        end

        begin
          stdout_io.each_line do |line|
            chomped = line.chomp
            yield chomped unless chomped.empty?
          end
        ensure
          watchdog.kill
          writer.join
        end

        raise TimeoutError, "claude streaming exceeded #{timeout}s; the process was killed" if timed_out

        RunResult.new(stdout: nil, stderr: err_reader.value, exit_status: wait_thr.value.exitstatus)
      end
    end

    private

    def spawn(argv, env, cwd, &block)
      validate_cwd!(cwd)
      options = {}
      options[:chdir] = cwd if cwd
      Open3.popen3(env || {}, *argv, **options, &block)
    rescue Errno::ENOENT
      raise BinaryNotFoundError, binary_not_found_message(argv.first)
    end

    def validate_cwd!(cwd)
      return if cwd.nil? || File.directory?(cwd)

      raise Error, "working directory does not exist: #{cwd}"
    end

    def write_stdin(stdin_io, data)
      stdin_io.write(data) if data
    rescue Errno::EPIPE
      # The child exited before reading stdin; the failure surfaces via status.
    ensure
      stdin_io.close unless stdin_io.closed?
    end

    # Send +SIGTERM+, wait up to {KILL_GRACE} for the child to exit, then
    # escalate to +SIGKILL+ if it ignored the polite signal.
    #
    # This runs synchronously while holding +wait_thr+: the child's PID can't
    # be reaped (and therefore can't be recycled by the OS) until we let go,
    # so the +SIGKILL+ can never land on an unrelated, reused PID.
    def terminate(wait_thr)
      Process.kill("TERM", wait_thr.pid)
      return if wait_thr.join(KILL_GRACE)

      Process.kill("KILL", wait_thr.pid)
    rescue Errno::ESRCH
      # The process already exited.
    end

    def binary_not_found_message(binary)
      "could not run #{binary.inspect}: is Claude Code installed and on your PATH?\n" \
        "Install it with `npm install -g @anthropic-ai/claude-code`, then run `claude` " \
        "and `/login` once to sign in with your Claude subscription."
    end
  end
end
