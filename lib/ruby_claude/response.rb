# frozen_string_literal: true

module RubyClaude
  # Immutable value object describing the final result of a query.
  #
  # Built from the CLI's +--output-format json+ result object (or from the
  # final +result+ line of a stream). Missing keys map to sensible defaults
  # rather than raising.
  #
  # @!attribute [r] text
  #   @return [String] the assistant's final text result
  # @!attribute [r] session_id
  #   @return [String, nil] the session id of this conversation
  # @!attribute [r] cost_usd
  #   @return [Float] total cost in USD (often +0.0+ on a subscription)
  # @!attribute [r] usage
  #   @return [Hash] token usage counts, when present
  # @!attribute [r] num_turns
  #   @return [Integer] number of agentic turns
  # @!attribute [r] duration_ms
  #   @return [Integer] wall-clock duration in milliseconds
  # @!attribute [r] error
  #   @return [Boolean] whether the CLI reported an error
  # @!attribute [r] raw
  #   @return [Hash] the full parsed result object
  Response = Data.define(:text, :session_id, :cost_usd, :usage,
                         :num_turns, :duration_ms, :error, :raw) do
    # Build a Response from a parsed CLI result hash.
    #
    # @param data [Hash, nil] the parsed result object
    # @return [Response]
    def self.from_result(data)
      data ||= {}
      new(
        text: data["result"] || "",
        session_id: data["session_id"],
        cost_usd: (data["total_cost_usd"] || data["cost_usd"] || 0.0).to_f,
        usage: data["usage"] || {},
        num_turns: (data["num_turns"] || 0).to_i,
        duration_ms: (data["duration_ms"] || 0).to_i,
        error: data.fetch("is_error", false) ? true : false,
        raw: data
      )
    end

    # @return [Boolean] whether the result represents an error
    def error? = !!error

    # @return [Boolean] whether the result was successful
    def success? = !error?

    # Returns the assistant text, so +puts response+ prints the answer.
    #
    # @return [String]
    def to_s = text
  end
end
