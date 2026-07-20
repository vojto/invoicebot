class EuVatId
  COUNTRY_CODES = %w[
    AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK
  ].freeze
  FORMAT = /\A(?<country_code>[A-Z]{2})\d{8,12}\z/

  def self.normalize(value)
    normalized = value.to_s.strip.upcase.gsub(/[\s.-]/, "")
    match = FORMAT.match(normalized)

    normalized if match && COUNTRY_CODES.include?(match[:country_code])
  end

  def self.country_code(value)
    prefix = normalize(value)&.first(2)
    prefix == "EL" ? "GR" : prefix
  end
end
