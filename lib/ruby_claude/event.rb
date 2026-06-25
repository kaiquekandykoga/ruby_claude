# frozen_string_literal: true

module RubyClaude
  # Immutable streaming event parsed from one line of +--output-format
  # stream-json+ output. The {#type} mirrors the CLI's +type+ field as a
  # Symbol (+:system+, +:assistant+, +:user+, +:result+, ...).
  #
  # @!attribute [r] type
  #   @return [Symbol] the event type
  # @!attribute [r] text
  #   @return [String, nil] text extracted from assistant/user/result payloads
  # @!attribute [r] session_id
  #   @return [String, nil] the session id, when present
  # @!attribute [r] cost_usd
  #   @return [Float, nil] total cost, present on the result event
  # @!attribute [r] duration_ms
  #   @return [Integer, nil] duration, present on the result event
  # @!attribute [r] raw
  #   @return [Hash] the full parsed line
  Event = Data.define(:type, :text, :session_id, :cost_usd, :duration_ms, :raw) do
    # Build an Event from one parsed NDJSON line.
    #
    # @param data [Hash, nil] the parsed line
    # @return [Event]
    def self.from_hash(data)
      data ||= {}
      new(
        type: (data["type"] || "unknown").to_sym,
        text: extract_text(data),
        session_id: data["session_id"],
        cost_usd: data["total_cost_usd"],
        duration_ms: data["duration_ms"],
        raw: data
      )
    end

    # Pull human-readable text out of a parsed line, if any.
    #
    # @param data [Hash]
    # @return [String, nil]
    def self.extract_text(data)
      case data["type"]
      when "assistant", "user"
        message = data["message"] || data
        text_from_content(message["content"])
      when "result"
        data["result"]
      end
    end

    # Join the text from a content array (or pass a bare string through).
    #
    # @param content [String, Array, nil]
    # @return [String, nil]
    def self.text_from_content(content)
      return content if content.is_a?(String)
      return nil unless content.is_a?(Array)

      texts = content
              .select { |block| block.is_a?(Hash) && block["type"] == "text" }
              .filter_map { |block| block["text"] }
      texts.empty? ? nil : texts.join
    end

    # @return [Boolean] whether this is the final result event
    def result? = type == :result

    # @return [Boolean] whether this is an assistant message event
    def assistant? = type == :assistant

    # @return [Boolean] whether this is a system event
    def system? = type == :system

    # @return [Boolean] whether this is a user message event
    def user? = type == :user
  end
end
