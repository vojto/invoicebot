class Attachment < ApplicationRecord
  belongs_to :email
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

  validates :gmail_attachment_id, presence: true
  validates :filename, presence: true
end
