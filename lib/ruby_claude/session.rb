# frozen_string_literal: true

module RubyClaude
  # A multi-turn conversation.
  #
  # The first {#query} captures the +session_id+ from the reply; subsequent
  # queries transparently pass +--resume <id>+ so the conversation continues.
  class Session
    # @return [String, nil] the session id being resumed (nil until the first
    #   reply, unless one was supplied to {Client#session})
    attr_reader :id

    # @param client [Client] the client used to run each turn
    # @param id [String, nil] an existing session id to resume from the start
    def initialize(client, id: nil)
      @client = client
      @id = id
      @mutex = Mutex.new
    end

    # Ask a question within this conversation, resuming the captured session.
    #
    # @param prompt [String]
    # @return [Response]
    def query(prompt)
      @mutex.synchronize do
        response = @client.query(prompt, resume: @id)
        @id = response.session_id || @id
        response
      end
    end
    alias ask query
  end
end
