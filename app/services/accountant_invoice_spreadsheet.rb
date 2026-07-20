class AccountantInvoiceSpreadsheet
  def initialize(table)
    @table = table
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook
    styles = workbook.styles
    date_style = styles.add_style(format_code: "yyyy-mm-dd")
    amount_style = styles.add_style(format_code: "#,##0.00", alignment: { horizontal: :right })
    link_style = styles.add_style(fg_color: "FF0563C1", u: true)
    row_styles = @table.columns.map do |column|
      case column.kind
      when :date then date_style
      when :amount then amount_style
      when :pdf then link_style
      else 0
      end
    end

    workbook.add_worksheet(name: "Invoices") do |sheet|
      sheet.sheet_view.show_grid_lines = false
      sheet.sheet_view.pane do |pane|
        pane.state = :frozen
        pane.x_split = 2
        pane.y_split = 1
        pane.top_left_cell = "C2"
        pane.active_pane = :bottom_right
      end

      sheet.add_row(@table.columns.map(&:label))
      add_data_rows(sheet, row_styles)
      sheet.column_widths(*@table.columns.map(&:width))

      last_column = Axlsx.col_ref(@table.columns.length - 1)
      last_row = @table.rows.length + 1
      table_range = "A1:#{last_column}#{last_row}"
      sheet.add_table(
        table_range,
        name: "AccountantInvoices",
        style_info: { name: "TableStyleMedium2", show_row_stripes: true }
      )
    end

    package.to_stream(confirm_valid: true).read
  end

  private

  def add_data_rows(sheet, row_styles)
    pdf_index = @table.columns.index { |column| column.kind == :pdf }

    @table.rows.each do |record|
      values = @table.columns.map do |column|
        value = record[:values][column.key]
        column.kind == :pdf && value.present? ? "Open PDF" : value
      end
      row = sheet.add_row(values, style: row_styles)
      pdf_url = record[:values][:pdf_url]
      next unless pdf_url.present?

      sheet.add_hyperlink(
        location: pdf_url,
        ref: row.cells[pdf_index],
        tooltip: "Open invoice PDF"
      )
    end
  end
end
