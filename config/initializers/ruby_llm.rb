RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.perplexity_api_key = ENV["PERPLEXITY_API_KEY"]

  # Default to GPT-5.2
  config.default_model = "gpt-5.2"
end
