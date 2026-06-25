# frozen_string_literal: true

require_relative "helper"

class CommandTest < Test::Unit::TestCase
  def config(**overrides)
    RubyClaude::Configuration.new.merge(overrides)
  end

  def build(stream: false, resume: nil, **overrides)
    RubyClaude::Command.new(config(**overrides)).build(stream: stream, resume: resume)
  end

  def test_one_shot_uses_json_output
    argv, = build
    assert_equal ["claude", "-p", "--output-format", "json"], argv
  end

  def test_streaming_uses_stream_json_with_verbose
    argv, = build(stream: true)
    assert_equal ["claude", "-p", "--output-format", "stream-json", "--verbose"], argv
  end

  def test_maps_model_and_system_prompt
    argv, = build(model: "claude-sonnet-4-6", append_system_prompt: "Be concise.")
    assert_subsequence argv, ["--model", "claude-sonnet-4-6"]
    assert_subsequence argv, ["--append-system-prompt", "Be concise."]
  end

  def test_allowed_and_disallowed_tools_are_separate_tokens
    argv, = build(allowed_tools: ["Read", "Bash(git log *)"], disallowed_tools: ["Edit"])
    assert_subsequence argv, ["--allowedTools", "Read", "Bash(git log *)"]
    assert_subsequence argv, ["--disallowedTools", "Edit"]
  end

  def test_add_dirs_follow_a_single_flag
    argv, = build(add_dirs: ["/a", "/b"])
    assert_subsequence argv, ["--add-dir", "/a", "/b"]
  end

  def test_permission_mode_and_max_turns
    argv, = build(permission_mode: "acceptEdits", max_turns: 3)
    assert_subsequence argv, ["--permission-mode", "acceptEdits"]
    assert_subsequence argv, ["--max-turns", "3"]
  end

  def test_resume_added_only_when_given
    argv, = build
    assert_false argv.include?("--resume")

    argv, = build(resume: "sess-123")
    assert_subsequence argv, ["--resume", "sess-123"]
  end

  def test_empty_options_are_omitted
    argv, = build(model: nil, allowed_tools: [], add_dirs: [], max_turns: nil)
    assert_false argv.include?("--model")
    assert_false argv.include?("--allowedTools")
    assert_false argv.include?("--add-dir")
    assert_false argv.include?("--max-turns")
  end

  def test_prompt_is_never_in_argv
    argv, = build(model: "x", allowed_tools: ["Read"])
    # The only tokens are the binary, flags, and their values — never a prompt.
    assert_equal "claude", argv.first
    assert_false argv.include?("-")
  end

  def test_strips_api_key_in_subscription_mode
    _, env = build(use_subscription: true)
    assert_true env.key?("ANTHROPIC_API_KEY")
    assert_nil env["ANTHROPIC_API_KEY"]
  end

  def test_keeps_env_when_subscription_disabled
    _, env = build(use_subscription: false)
    assert_equal({}, env)
  end

  private

  # Assert that +needle+ appears as a contiguous run inside +haystack+.
  def assert_subsequence(haystack, needle)
    found = (0..(haystack.length - needle.length)).any? do |i|
      haystack[i, needle.length] == needle
    end
    assert_true found, "expected #{haystack.inspect} to contain the sequence #{needle.inspect}"
  end
end
