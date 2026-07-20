require "rails_helper"

RSpec.describe "PATCH /transactions/:id/category", type: :request do
  let(:user) { create(:user) }
  let(:transaction) { create(:transaction, bank_connection: create(:bank_connection, user: user)) }

  before { sign_in(user) }

  it "assigns and clears one of the user's categories" do
    category = create(:category, user: user)

    patch "/transactions/#{transaction.id}/category",
      params: { category_id: category.id },
      headers: { "HTTP_REFERER" => "/invoices/month/2026-07" }
    expect(transaction.reload.category).to eq(category)
    expect(response).to redirect_to("/invoices/month/2026-07")

    patch "/transactions/#{transaction.id}/category", params: { category_id: nil }
    expect(transaction.reload.category).to be_nil
  end

  it "does not assign another user's category" do
    category = create(:category)

    patch "/transactions/#{transaction.id}/category", params: { category_id: category.id }

    expect(response).to have_http_status(:not_found)
    expect(transaction.reload.category).to be_nil
  end
end
