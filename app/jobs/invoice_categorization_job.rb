class InvoiceCategorizationJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless categorizable?(invoice)

    category = InvoiceCategorizationAgent.new(invoice).call

    invoice.reload
    return unless categorizable?(invoice)

    invoice.update!(category: category, ai_categorization_attempted_at: Time.current)
  end

  private

  def categorizable?(invoice)
    return false if invoice.nil? || invoice.soft_deleted? || invoice.category_id.present?

    invoice.user.categories.exists?
  end
end
