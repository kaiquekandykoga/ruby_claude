# frozen_string_literal: true

require_relative "helper"

class EventTest < Test::Unit::TestCase
  include TestHelpers

  def lines
    fixture("stream.txt").each_line.map(&:strip).reject(&:empty?).map { |line| JSON.parse(line) }
  end

  def test_system_event_has_no_text
    event = RubyClaude::Event.from_hash(lines[0])
    assert_equal :system, event.type
    assert_nil event.text
    assert_equal "sess-stream-001", event.session_id
    assert_true event.system?
  end

  def test_assistant_event_extracts_text_from_content_blocks
    event = RubyClaude::Event.from_hash(lines[1])
    assert_equal :assistant, event.type
    assert_equal "Ruby on rails\n", event.text
    assert_true event.assistant?
  end

  def test_result_event_carries_metadata
    event = RubyClaude::Event.from_hash(lines.last)
    assert_equal :result, event.type
    assert_equal "Ruby on rails\nGems shimmer brightly", event.text
    assert_equal 2100, event.duration_ms
    assert_true event.result?
  end

  def test_handles_string_content
    event = RubyClaude::Event.from_hash({ "type" => "assistant", "message" => { "content" => "hi" } })
    assert_equal "hi", event.text
  end

  def test_unknown_type_has_symbol_type_and_no_text
    event = RubyClaude::Event.from_hash({ "type" => "weird" })
    assert_equal :weird, event.type
    assert_nil event.text
  end
end
