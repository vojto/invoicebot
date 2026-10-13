# frozen_string_literal: true

class ApplicationAgent < RubyLLM::Agent
  class InvalidResponseError < StandardError; end

  model "gpt-6.1-sol", provider: :openai
  thinking effort: :low

  private

  def ask_for_data(prompt, **options)
    data = ask(prompt, **options).parsed
    raise InvalidResponseError, "Expected a JSON object, got #{data.inspect}" unless data.is_a?(Hash)

    data.with_indifferent_access
  end
end
