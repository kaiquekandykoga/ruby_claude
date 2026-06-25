# frozen_string_literal: true

require_relative "helper"
require "rbconfig"
require "tmpdir"

# These tests exercise the real subprocess machinery, but they only ever spawn
# a throwaway local `ruby` process (or a deliberately missing binary) — never
# the `claude` CLI, and never the network.
class RunnerTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    @runner = RubyClaude::Runner.new
    @ruby = RbConfig.ruby
  end

  def test_missing_binary_raises_binary_not_found
    assert_raise(RubyClaude::BinaryNotFoundError) do
      @runner.run(argv: ["definitely_not_a_real_binary_xyz"], env: {}, cwd: nil, timeout: 5, stdin: "hi")
    end
  end

  def test_captures_stdout_and_writes_stdin
    result = @runner.run(
      argv: [@ruby, "-e", "print STDIN.read"], env: {}, cwd: nil, timeout: 10, stdin: "round-trip"
    )
    assert_equal "round-trip", result.stdout
    assert_equal 0, result.exit_status
  end

  def test_nonzero_exit_status_and_stderr_are_captured
    result = @runner.run(
      argv: [@ruby, "-e", "STDERR.print('bad'); exit 3"], env: {}, cwd: nil, timeout: 10, stdin: nil
    )
    assert_equal 3, result.exit_status
    assert_equal "bad", result.stderr
  end

  def test_timeout_kills_the_process
    # The child records its PID, then sleeps far longer than the timeout.
    pid_path = File.join(Dir.tmpdir, "rc_pid_#{Process.pid}_#{object_id}")
    script = "File.write(#{pid_path.inspect}, Process.pid); sleep 30"

    assert_raise(RubyClaude::TimeoutError) do
      @runner.run(argv: [@ruby, "-e", script], env: {}, cwd: nil, timeout: 1, stdin: nil)
    end

    assert_process_killed(Integer(File.read(pid_path)))
  ensure
    File.delete(pid_path) if pid_path && File.exist?(pid_path)
  end

  def test_strips_api_key_from_the_child_environment
    original = ENV.fetch("ANTHROPIC_API_KEY", :unset)
    ENV["ANTHROPIC_API_KEY"] = "sk-should-be-removed"

    result = @runner.run(
      argv: [@ruby, "-e", "print ENV.fetch('ANTHROPIC_API_KEY', 'REMOVED')"],
      env: { "ANTHROPIC_API_KEY" => nil }, cwd: nil, timeout: 10, stdin: nil
    )
    assert_equal "REMOVED", result.stdout
  ensure
    if original == :unset
      ENV.delete("ANTHROPIC_API_KEY")
    else
      ENV["ANTHROPIC_API_KEY"] = original
    end
  end

  def test_stream_yields_each_line
    script = 'puts({type: "system"}.to_json); puts({type: "result", result: "done"}.to_json)'
    lines = []
    result = @runner.stream(
      argv: [@ruby, "-rjson", "-e", script], env: {}, cwd: nil, timeout: 10, stdin: nil
    ) { |line| lines << line }

    assert_equal 2, lines.length
    assert_equal 0, result.exit_status
  end

  def test_missing_cwd_raises
    assert_raise(RubyClaude::Error) do
      @runner.run(argv: [@ruby, "-e", "1"], env: {}, cwd: "/no/such/dir/xyz", timeout: 5, stdin: nil)
    end
  end

  private

  # Poll briefly until the process is gone, so we assert it was actually
  # killed rather than merely that a TimeoutError was raised.
  def assert_process_killed(pid)
    20.times do
      return assert_true(true) unless process_alive?(pid)

      sleep 0.05
    end
    flunk "child process #{pid} should have been killed after the timeout"
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end
