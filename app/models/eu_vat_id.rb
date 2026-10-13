class EuVatId
  NON_UNION_SCHEME_FORMAT = /\AEU\d{9}\z/

  def self.normalize(value)
    vat_id = Valvat.new(value)
    return vat_id.to_s if vat_id.to_s.match?(NON_UNION_SCHEME_FORMAT)
    return unless vat_id.valid?
    return unless Valvat::Utils::EU_MEMBER_STATES.include?(vat_id.iso_country_code)

    vat_id.to_s
  end

  def self.country_code(value)
    normalized = normalize(value)
    Valvat.new(normalized).iso_country_code if normalized
  end
end
