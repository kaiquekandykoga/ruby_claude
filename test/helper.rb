# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "json"
require "test/unit"
require "ruby_claude"

# Shared helpers mixed into the test cases.
module TestHelpers
  FIXTURES = File.expand_path("fixtures", __dir__).freeze

  # Read a fixture file by name.
  def fixture(name)
    File.read(File.join(FIXTURES, name))
  end

  # Build a {RubyClaude::RunResult} for a one-shot run.
  def ok(stdout, stderr: "", exit_status: 0)
    RubyClaude::RunResult.new(stdout: stdout, stderr: stderr, exit_status: exit_status)
  end
end

# A drop-in replacement for RubyClaude::Runner that never spawns a process.
#
# It records every call's arguments and replays queued results, so the Client
# can be exercised end-to-end without touching the +claude+ binary.
class FakeRunner
  attr_reader :runs, :streams

  # @param results [Array<RubyClaude::RunResult, Exception>] one per #run call
  # @param stream_lines [Array<String>] lines yielded by #stream
  # @param stream_result [RubyClaude::RunResult, nil] result returned by #stream
  def initialize(results: [], stream_lines: [], stream_result: nil)
    @results = Array(results)
    @stream_lines = stream_lines
    @stream_result = stream_result
    @runs = []
    @streams = []
  end

  def run(argv:, env:, cwd:, timeout:, stdin:)
    @runs << { argv: argv, env: env, cwd: cwd, timeout: timeout, stdin: stdin }
    raise "FakeRunner: no queued results" if @results.empty?

    result = @results.shift
    raise result if result.is_a?(Exception)

    result
  end

  def stream(argv:, env:, cwd:, timeout:, stdin:, &block)
    @streams << { argv: argv, env: env, cwd: cwd, timeout: timeout, stdin: stdin }
    @stream_lines.each(&block)
    @stream_result || RubyClaude::RunResult.new(stdout: nil, stderr: "", exit_status: 0)
  end
end
