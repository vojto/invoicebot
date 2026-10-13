# frozen_string_literal: true

class ApplicationAgent < RubyLLM::Agent
  class InvalidResponseError < StandardError; end

  model "gpt-5.6-terra", provider: :openai
  thinking false

  private

  def ask_for_data(prompt, **options)
    data = ask(prompt, **options).parsed
    raise InvalidResponseError, "Expected a JSON object, got #{data.inspect}" unless data.is_a?(Hash)

    data.with_indifferent_access
  end
end
