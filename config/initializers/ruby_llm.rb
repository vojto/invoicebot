RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  config.perplexity_api_key = ENV["PERPLEXITY_API_KEY"]

  # The gem's bundled registry lags new model releases, and writing into the
  # installed gem is lost on every bundle install. Keep the registry in a
  # checked-in file instead. Refresh it with:
  #   bin/rails runner 'RubyLLM.models.refresh!; RubyLLM.models.save_to_json'
  config.model_registry_file = Rails.root.join("config/ruby_llm_models.json").to_s

  config.default_model = "gpt-5.6-terra"
end
