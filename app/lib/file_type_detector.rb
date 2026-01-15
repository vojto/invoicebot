class FileTypeDetector
  MIME_TYPE_MAP = {
    "application/pdf" => :pdf,
    "image/jpeg" => :image,
    "image/png" => :image,
    "image/gif" => :image,
    "image/webp" => :image,
    "image/svg+xml" => :image,
    "text/plain" => :text,
    "text/html" => :html,
    "text/csv" => :csv,
    "application/json" => :json,
    "application/xml" => :xml,
    "text/xml" => :xml,
    "application/zip" => :archive,
    "application/x-zip-compressed" => :archive,
    "application/x-rar-compressed" => :archive,
    "application/vnd.ms-excel" => :spreadsheet,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => :spreadsheet,
    "application/msword" => :document,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => :document
  }.freeze

  EXTENSION_MAP = {
    ".pdf" => :pdf,
    ".jpg" => :image,
    ".jpeg" => :image,
    ".png" => :image,
    ".gif" => :image,
    ".webp" => :image,
    ".svg" => :image,
    ".txt" => :text,
    ".html" => :html,
    ".htm" => :html,
    ".csv" => :csv,
    ".json" => :json,
    ".xml" => :xml,
    ".zip" => :archive,
    ".rar" => :archive,
    ".xls" => :spreadsheet,
    ".xlsx" => :spreadsheet,
    ".doc" => :document,
    ".docx" => :document
  }.freeze

  def self.detect(mime_type:, filename:)
    # First try exact mime type match
    return MIME_TYPE_MAP[mime_type] if MIME_TYPE_MAP.key?(mime_type)

    # For octet-stream or unknown types, fall back to extension
    if mime_type.nil? || mime_type == "application/octet-stream"
      return detect_from_filename(filename)
    end

    # Try extension as last resort
    detect_from_filename(filename)
  end

  def self.detect_from_filename(filename)
    return nil unless filename

    ext = File.extname(filename).downcase
    EXTENSION_MAP[ext]
  end
end
