# Agents build their chat on initialization, which requires a configured provider.
RubyLLM.config.openai_api_key ||= "test-openai-api-key"
