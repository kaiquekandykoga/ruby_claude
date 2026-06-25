# frozen_string_literal: true

require_relative "helper"

class RubyClaudeTest < Test::Unit::TestCase
  include TestHelpers

  def setup
    RubyClaude.reset_configuration!
  end

  def teardown
    RubyClaude.reset_configuration!
  end

  def test_configure_sets_global_defaults
    RubyClaude.configure do |config|
      config.model = "claude-sonnet-4-6"
      config.timeout = 123
    end

    assert_equal "claude-sonnet-4-6", RubyClaude.configuration.model
    assert_equal 123, RubyClaude.configuration.timeout
  end

  def test_new_clients_inherit_the_global_configuration
    RubyClaude.configure { |config| config.model = "claude-sonnet-4-6" }
    client = RubyClaude::Client.new(runner: FakeRunner.new)
    assert_equal "claude-sonnet-4-6", client.config.model
  end

  def test_query_delegates_to_the_default_client
    runner = FakeRunner.new(results: [ok(fixture("result_success.json"))])
    RubyClaude.instance_variable_set(:@default_client, RubyClaude::Client.new(runner: runner))

    response = RubyClaude.query("hi")
    assert_equal "Ruby Claude is a small SDK.", response.text
  end

  def test_configure_rebuilds_the_default_client
    first = RubyClaude.default_client
    RubyClaude.configure { |config| config.model = "x" }
    assert_not_same first, RubyClaude.default_client
  end
end
