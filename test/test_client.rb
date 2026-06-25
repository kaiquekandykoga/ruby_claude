# frozen_string_literal: true

require_relative "helper"

class ClientTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    RubyClaude.reset_configuration!
  end

  def teardown
    RubyClaude.reset_configuration!
  end

  def client(runner)
    RubyClaude::Client.new(runner: runner)
  end

  def test_query_returns_response_from_json
    runner = FakeRunner.new(results: [ok(fixture("result_success.json"))])
    response = client(runner).query("hello")

    assert_equal "Ruby Claude is a small SDK.", response.text
    assert_equal "11111111-2222-3333-4444-555555555555", response.session_id
  end

  def test_query_passes_prompt_on_stdin
    runner = FakeRunner.new(results: [ok(fixture("result_success.json"))])
    client(runner).query("hello there")
    assert_equal "hello there", runner.runs.first[:stdin]
  end

  def test_query_strips_api_key_in_child_env
    runner = FakeRunner.new(results: [ok(fixture("result_success.json"))])
    client(runner).query("hi")

    env = runner.runs.first[:env]
    assert_true env.key?("ANTHROPIC_API_KEY")
    assert_nil env["ANTHROPIC_API_KEY"]
  end

  def test_error_result_raises_execution_error
    runner = FakeRunner.new(results: [ok(fixture("result_error.json"))])
    error = assert_raise(RubyClaude::ExecutionError) { client(runner).query("x") }
    assert_match(/error result/, error.message)
  end

  def test_nonzero_exit_raises_execution_error_with_status_and_stderr
    runner = FakeRunner.new(results: [ok("", stderr: "boom", exit_status: 2)])
    error = assert_raise(RubyClaude::ExecutionError) { client(runner).query("x") }

    assert_equal 2, error.status
    assert_match(/boom/, error.message)
  end

  def test_auth_failure_raises_authentication_error
    runner = FakeRunner.new(results: [ok("", stderr: "Invalid API key. Please run /login", exit_status: 1)])
    assert_raise(RubyClaude::AuthenticationError) { client(runner).query("x") }
  end

  def test_unparseable_output_raises_parse_error
    runner = FakeRunner.new(results: [ok("this is not json", exit_status: 0)])
    assert_raise(RubyClaude::ParseError) { client(runner).query("x") }
  end

  def test_stream_yields_events_and_returns_final_response
    lines = fixture("stream.txt").each_line.map(&:chomp).reject(&:empty?)
    runner = FakeRunner.new(stream_lines: lines)

    events = []
    response = client(runner).stream("poem") { |event| events << event }

    assert_equal %i[system assistant assistant result], events.map(&:type)
    assert_equal "Ruby on rails\nGems shimmer brightly", response.text
    assert_equal "poem", runner.streams.first[:stdin]
  end

  def test_stream_without_block_still_returns_response
    lines = fixture("stream.txt").each_line.map(&:chomp).reject(&:empty?)
    runner = FakeRunner.new(stream_lines: lines)

    response = client(runner).stream("poem")
    assert_equal "sess-stream-001", response.session_id
  end
end
