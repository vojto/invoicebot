class InvoicesController < ApplicationController
  before_action :require_authentication
  before_action :set_invoice

  def remove
    @invoice.soft_delete!
    redirect_to dashboard_path
  end

  def restore
    @invoice.restore!
    redirect_to dashboard_path
  end

  private

  def set_invoice
    @invoice = Invoice
      .joins(:email)
      .where(emails: { user_id: current_user.id })
      .find(params[:id])
  end
end
