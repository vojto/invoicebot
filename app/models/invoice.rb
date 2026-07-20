# Represents an invoice extracted from an email attachment.
#
# Each invoice is linked to exactly one email (the source email containing the PDF).
# We store only the total amount charged - no subtotals or tax breakdowns, as we're
# only interested in matching the final sum against bank transactions.
#
# Fields not stored (by design):
# - invoice_number: Not needed for our matching purposes
# - due_date: Not relevant for historical matching
# - tax_amount/subtotal: Only total amount matters for bank matching
# - vendor_tax_id/address: Vendor name is sufficient for identification
# - payment_reference/variable_symbol: Not needed for our use case
#
class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :email, optional: true
  has_one :bank_transaction, class_name: "Transaction", dependent: :nullify
  has_one_attached :pdf
  has_many :page_images, class_name: "InvoicePageImage", dependent: :destroy

  before_save :track_pdf_attachment_change
  after_commit :enqueue_page_extraction, if: :pdf_attachment_changed?
  after_rollback :clear_pdf_attachment_change

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
      amount_cents: extraction[:amount_cents],
      currency: extraction[:currency],
      issue_date: extraction[:issue_date],
      delivery_date: extraction[:delivery_date],
      note: extraction[:note]
    )
  end

  private

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
end
