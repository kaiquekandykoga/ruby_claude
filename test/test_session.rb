# frozen_string_literal: true

require_relative "helper"

class SessionTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    RubyClaude.reset_configuration!
  end

  def teardown
    RubyClaude.reset_configuration!
  end

  def result_with(session_id, text)
    ok(JSON.generate(
         "type" => "result", "is_error" => false, "result" => text, "session_id" => session_id
       ))
  end

  def test_first_query_has_no_resume_then_subsequent_queries_resume
    runner = FakeRunner.new(results: [
                              result_with("sess-A", "noted"),
                              result_with("sess-A", "seven")
                            ])
    session = RubyClaude::Client.new(runner: runner).session

    session.query("My favorite number is 7.")
    assert_equal "sess-A", session.id
    assert_false runner.runs[0][:argv].include?("--resume")

    response = session.query("What's my favorite number?")
    assert_equal "seven", response.text
    assert_resume runner.runs[1][:argv], "sess-A"
  end

  def test_starting_from_an_existing_id_resumes_on_the_first_query
    runner = FakeRunner.new(results: [result_with("sess-B", "ok")])
    session = RubyClaude::Client.new(runner: runner).session(id: "sess-B")

    session.query("continue please")
    assert_resume runner.runs[0][:argv], "sess-B"
  end

  private

  def assert_resume(argv, id)
    index = argv.index("--resume")
    assert_not_nil index, "expected --resume in #{argv.inspect}"
    assert_equal id, argv[index + 1]
  end
end
