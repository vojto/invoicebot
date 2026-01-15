# frozen_string_literal: true

class Qpdf
  class Error < StandardError; end

  def initialize(path)
    @path = path
  end

  def page_count
    output = `qpdf --show-npages #{@path}`.strip
    raise Error, "Failed to get page count" unless $?.success?
    output.to_i
  end

  def extract_pages(range, output_path:)
    system("qpdf", @path, "--pages", ".", range, "--", output_path)
    raise Error, "Failed to extract pages" unless $?.success?
    output_path
  end

  def extract_first_pages(count, output_path:)
    end_page = [count, page_count].min
    extract_pages("1-#{end_page}", output_path: output_path)
  end

  def self.installed?
    system("which", "qpdf", out: File::NULL, err: File::NULL)
  end
end
