require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "lists only the current user's categories with invoice counts" do
    category = create(:category, user: user, name: "Software")
    create(:invoice, user: user, category: category)
    create(:category, name: "Someone else's category")

    get "/categories", headers: inertia_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["component"]).to eq("categories/index")
    expect(response.parsed_body.dig("props", "categories")).to eq([
      { "id" => category.id, "name" => "Software", "invoices_count" => 1 }
    ])
  end

  it "creates and renames a category" do
    post "/categories", params: { category: { name: "  Travel  " } }
    category = user.categories.find_by!(name: "Travel")

    patch "/categories/#{category.id}", params: { category: { name: "Transport" } }

    expect(category.reload.name).to eq("Transport")
  end

  it "deletes a category and leaves its invoices uncategorized" do
    category = create(:category, user: user)
    invoice = create(:invoice, user: user, category: category)

    delete "/categories/#{category.id}"

    expect(Category.exists?(category.id)).to be(false)
    expect(invoice.reload.category).to be_nil
  end

  def inertia_headers
    {
      "X-Inertia" => "true",
      "X-Inertia-Version" => ViteRuby.digest,
      "X-Requested-With" => "XMLHttpRequest",
      "Accept" => "text/html, application/xhtml+xml"
    }
  end
end
