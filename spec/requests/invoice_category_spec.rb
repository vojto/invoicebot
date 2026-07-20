require "rails_helper"

RSpec.describe "PATCH /invoices/:id/category", type: :request do
  let(:user) { create(:user) }
  let(:invoice) { create(:invoice, user: user) }

  before { sign_in(user) }

  it "assigns and clears one of the user's categories" do
    category = create(:category, user: user)

    patch "/invoices/#{invoice.id}/category",
      params: { category_id: category.id },
      headers: { "HTTP_REFERER" => "/invoices/month/2026-07" }
    expect(invoice.reload.category).to eq(category)
    expect(response).to redirect_to("/invoices/month/2026-07")

    patch "/invoices/#{invoice.id}/category", params: { category_id: nil }
    expect(invoice.reload.category).to be_nil
  end

  it "does not assign another user's category" do
    category = create(:category)

    patch "/invoices/#{invoice.id}/category", params: { category_id: category.id }

    expect(response).to have_http_status(:not_found)
    expect(invoice.reload.category).to be_nil
  end

  it "does not update another user's invoice" do
    category = create(:category, user: user)

    patch "/invoices/#{create(:invoice).id}/category", params: { category_id: category.id }

    expect(response).to have_http_status(:not_found)
  end
end
