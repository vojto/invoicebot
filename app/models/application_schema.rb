# frozen_string_literal: true

class ApplicationSchema < RubyLLM::Schema
  class << self
    # Always omit strict property for Anthropic compatibility (OpenAI works without it)
    def strict(*)
      nil
    end

    def string(name, nullable: false, nullish: false, **options)
      if nullish
        nullable_field(name, :string, required: false, **options)
      elsif nullable
        nullable_field(name, :string, **options)
      else
        super(name, **options)
      end
    end

    def number(name, nullable: false, nullish: false, **options)
      if nullish
        nullable_field(name, :number, required: false, **options)
      elsif nullable
        nullable_field(name, :number, **options)
      else
        super(name, **options)
      end
    end

    def integer(name, nullable: false, nullish: false, **options)
      if nullish
        nullable_field(name, :integer, required: false, **options)
      elsif nullable
        nullable_field(name, :integer, **options)
      else
        super(name, **options)
      end
    end

    def boolean(name, nullable: false, nullish: false, **options)
      if nullish
        nullable_field(name, :boolean, required: false, **options)
      elsif nullable
        nullable_field(name, :boolean, **options)
      else
        super(name, **options)
      end
    end

    private

    def nullable_field(name, type, required: true, **options)
      any_of(name, required: required) do
        send(type, **options)
        null
      end
    end
  end
end
