# Represents an invoice or credit note extracted from an email attachment.
#
# Each invoice is linked to exactly one email (the source email containing the PDF).
# We store only the total amount charged - no subtotals or tax breakdowns, as we're
# only interested in matching the final sum against bank transactions.
#
# Fields not stored (by design):
# - invoice_number: Not needed for our matching purposes
# - due_date: Not relevant for historical matching
# - tax_amount/subtotal: Only total amount matters for bank matching
# - vendor_address: Vendor name, country, and EU VAT ID are sufficient for identification
# - payment_reference/variable_symbol: Not needed for our use case
#
class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :email, optional: true
  belongs_to :category, optional: true
  has_one :bank_transaction, class_name: "Transaction", dependent: :nullify
  has_one_attached :pdf
  has_many :page_images, class_name: "InvoicePageImage", dependent: :destroy

  enum :document_type, { invoice: "invoice", credit_note: "credit_note" }, prefix: true

  scope :compatible_with_transaction, ->(transaction) {
    where(document_type: transaction.credit? ? :credit_note : :invoice)
  }

  before_save :track_pdf_attachment_change
  before_validation :normalize_vendor_identity
  after_commit :enqueue_page_extraction, if: :pdf_attachment_changed?
  after_commit :enqueue_ai_categorization, on: [ :create, :update ], if: :needs_ai_categorization?
  after_rollback :clear_pdf_attachment_change
  validate :category_belongs_to_user
  validates :vendor_country, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true

  def soft_deleted?
    deleted_at.present?
  end

  def soft_delete!
    transaction do
      bank_transaction&.update!(invoice: nil)
      update!(deleted_at: Time.current)
    end
  end

  def restore!
    update!(deleted_at: nil)
  end

  def reprocess!
    return false unless pdf.attached?

    with_lock do
      if is_reprocessing?
        false
      else
        update!(is_reprocessing: true)
        InvoiceReprocessingJob.perform_later(id)
        true
      end
    end
  end

  def update_from_extraction!(extraction)
    update!(
      vendor_name: extraction[:vendor_name],
      vendor_country: extraction[:vendor_country],
      vendor_eu_vat_id: extraction[:vendor_eu_vat_id],
      amount_cents: extraction[:amount_cents],
      currency: extraction[:currency],
      document_type: extraction[:document_type],
      issue_date: extraction[:issue_date],
      delivery_date: extraction[:delivery_date],
      note: extraction[:note]
    )
  end

  def expected_transaction_direction
    document_type_credit_note? ? "credit" : "debit"
  end

  private

  def normalize_vendor_identity
    self.vendor_eu_vat_id = EuVatId.normalize(vendor_eu_vat_id)
    self.vendor_country = vendor_country.to_s.strip.upcase.presence || EuVatId.country_code(vendor_eu_vat_id)
  end

  def category_belongs_to_user
    return unless category && user
    return if category.user_id == user_id

    errors.add(:category, "must belong to the invoice owner")
  end

  def track_pdf_attachment_change
    @pdf_attachment_changed = attachment_changes.key?("pdf")
  end

  def pdf_attachment_changed?
    @pdf_attachment_changed
  end

  def clear_pdf_attachment_change
    @pdf_attachment_changed = false
  end

  def enqueue_page_extraction
    InvoicePageExtractionJob.perform_later(id) if pdf.attached?
  ensure
    clear_pdf_attachment_change
  end

  # Only an uncategorized invoice we have never looked at, and only once the
  # extraction filled in the vendor, is worth sending to the categorization agent.
  def needs_ai_categorization?
    vendor_name.present? &&
      category_id.nil? &&
      ai_categorization_attempted_at.nil? &&
      !soft_deleted? &&
      user.categories.exists?
  end

  def enqueue_ai_categorization
    InvoiceCategorizationJob.perform_later(id)
  end
end
