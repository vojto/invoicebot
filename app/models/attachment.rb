class Attachment < ApplicationRecord
  belongs_to :email, optional: true
  belongs_to :invoice, optional: true
  has_one_attached :file

  enum :file_type, {
    pdf: "pdf",
    image: "image",
    text: "text",
    html: "html",
    csv: "csv",
    json: "json",
    xml: "xml",
    archive: "archive",
    spreadsheet: "spreadsheet",
    document: "document"
  }, prefix: true

  validates :filename, presence: true
  validate :must_belong_to_email_or_invoice

  private

  def must_belong_to_email_or_invoice
    if email_id.blank? && invoice_id.blank?
      errors.add(:base, "Attachment must belong to either an email or an invoice")
    end
  end
end
