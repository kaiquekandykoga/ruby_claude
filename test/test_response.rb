# frozen_string_literal: true

require_relative "helper"

class ResponseTest < Test::Unit::TestCase
  include TestHelpers

  def test_parses_a_success_result
    data = JSON.parse(fixture("result_success.json"))
    response = RubyClaude::Response.from_result(data)

    assert_equal "Ruby Claude is a small SDK.", response.text
    assert_equal "11111111-2222-3333-4444-555555555555", response.session_id
    assert_in_delta 0.0123, response.cost_usd, 1e-9
    assert_equal 1, response.num_turns
    assert_equal 3120, response.duration_ms
    assert_equal 1200, response.usage["input_tokens"]
    assert_false response.error?
    assert_true response.success?
    assert_equal data, response.raw
  end

  def test_defaults_for_missing_keys
    response = RubyClaude::Response.from_result({})

    assert_equal "", response.text
    assert_nil response.session_id
    assert_equal 0.0, response.cost_usd
    assert_equal({}, response.usage)
    assert_equal 0, response.num_turns
    assert_equal 0, response.duration_ms
    assert_false response.error?
  end

  def test_handles_nil_result
    response = RubyClaude::Response.from_result(nil)
    assert_equal "", response.text
    assert_false response.error?
  end

  def test_error_flag_and_to_s
    data = JSON.parse(fixture("result_error.json"))
    response = RubyClaude::Response.from_result(data)

    assert_true response.error?
    assert_false response.success?
    assert_equal response.text, response.to_s
  end
end
