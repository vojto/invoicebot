# frozen_string_literal: true

class ApplicationAgent
  class InvalidResponseError < StandardError; end

  MODEL = "gpt-5.6-terra"
  PROVIDER = :openai
  REASONING_EFFORT = "none"

  LLMResponse = Data.define(:data, :elapsed_ms, :input_tokens, :output_tokens)

  private

  def ask(prompt, schema:, attachment: nil)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    chat = build_chat(schema: schema)
    message = attachment ? chat.ask(prompt, with: attachment) : chat.ask(prompt)

    LLMResponse.new(
      data: response_data(message),
      elapsed_ms: elapsed_ms_since(started_at),
      input_tokens: message.input_tokens,
      output_tokens: message.output_tokens
    )
  end

  def build_chat(schema:)
    chat = RubyLLM.chat(model: self.class::MODEL, provider: self.class::PROVIDER)
    chat.with_thinking(effort: self.class::REASONING_EFFORT)
    chat.with_instructions(self.class::SYSTEM_PROMPT)
    chat.with_schema(schema)
  end

  def response_data(message)
    content = message.content
    content = JSON.parse(content) if content.is_a?(String)
    raise InvalidResponseError, "Expected Hash response, got #{content.class}" unless content.is_a?(Hash)

    content.with_indifferent_access
  rescue JSON::ParserError => e
    raise InvalidResponseError, "Expected valid JSON response: #{e.message}"
  end

  def elapsed_ms_since(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
  end
end
