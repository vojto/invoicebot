class AccountantInvoiceSpreadsheet
  CurrencyColumn = Data.define(:key, :label, :kind, :width)

  def initialize(table)
    @table = table
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook
    @styles = workbook.styles
    date_style = @styles.add_style(format_code: "yyyy-mm-dd")
    amount_style = @styles.add_style(
      format_code: "#,##0.00;(#,##0.00);-",
      alignment: { horizontal: :right }
    )
    currency_style = @styles.add_style(alignment: { horizontal: :center })
    link_style = @styles.add_style(fg_color: "FF0563C1", u: true)
    row_styles = columns.map do |column|
      case column.kind
      when :date then date_style
      when :amount then amount_style
      when :currency then currency_style
      when :text then column.key == :vendor_name ? link_style : 0
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

      sheet.add_row(columns.map(&:label))
      add_data_rows(sheet, row_styles)
      sheet.column_widths(*columns.map { |column| [ column.width, column.label.length + 2 ].max })

      last_column = Axlsx.col_ref(columns.length - 1)
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

  def columns
    @columns ||= @table.columns.flat_map do |column|
      next column unless column.kind == :amount

      [ column, currency_column(column) ]
    end
  end

  def currency_column(amount_column)
    CurrencyColumn.new(
      key: :"#{amount_column.key}_currency",
      label: amount_column.label.sub(/ amount\z/, " currency"),
      kind: :currency,
      width: 12
    )
  end

  def add_data_rows(sheet, row_styles)
    vendor_index = columns.index { |column| column.key == :vendor_name }

    @table.rows.each do |record|
      values = columns.map { |column| spreadsheet_value(record, column) }
      styles = row_styles.dup
      pdf_url = record[:pdf_url]
      styles[vendor_index] = 0 unless pdf_url.present?
      row = sheet.add_row(values, style: styles)
      next unless pdf_url.present?

      sheet.add_hyperlink(
        location: pdf_url,
        ref: row.cells[vendor_index],
        tooltip: "Open invoice PDF"
      )
    end
  end

  def spreadsheet_value(record, column)
    if column.kind == :currency
      amount_key = column.key.to_s.delete_suffix("_currency").to_sym
      return record[:currencies][amount_key]
    end

    value = record[:values][column.key]
    return value unless column.kind == :country_vat

    [ record[:values][:vendor_country], value ].compact_blank.join(" · ").presence
  end
end
