# frozen_string_literal: true

require_relative "helper"

class ConfigurationTest < Test::Unit::TestCase
  def test_defaults
    config = RubyClaude::Configuration.new
    assert_equal "claude", config.binary
    assert_nil config.model
    assert_equal Dir.pwd, config.cwd
    assert_equal 300, config.timeout
    assert_true config.use_subscription
    assert_equal [], config.add_dirs
    assert_nil config.max_turns
  end

  def test_merge_applies_overrides_without_mutating_original
    config = RubyClaude::Configuration.new
    merged = config.merge(model: "claude-sonnet-4-6", timeout: 5)

    assert_equal "claude-sonnet-4-6", merged.model
    assert_equal 5, merged.timeout
    assert_nil config.model
    assert_equal 300, config.timeout
  end

  def test_merge_rejects_unknown_option
    assert_raise(ArgumentError) do
      RubyClaude::Configuration.new.merge(not_a_real_option: 1)
    end
  end

  def test_dup_isolates_array_options
    config = RubyClaude::Configuration.new
    config.add_dirs = ["/a"]
    merged = config.merge({})
    merged.add_dirs << "/b"

    assert_equal ["/a"], config.add_dirs
    assert_equal ["/a", "/b"], merged.add_dirs
  end
end
