require "rails_helper"

RSpec.describe "Accountant access management", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "creates and lists accountant access" do
    post "/accountant_accesses", params: { accountant_access: { name: "Jane" } }

    access = user.accountant_accesses.find_by!(name: "Jane")
    expect(response).to redirect_to(accountant_accesses_path)

    get "/accountant_accesses", headers: inertia_headers

    item = response.parsed_body.dig("props", "accountant_accesses", 0)
    expect(item.slice("id", "name", "active")).to eq(
      "id" => access.id,
      "name" => "Jane",
      "active" => true
    )
    expect(item["public_url"]).to include(access.public_token)
  end

  it "rotates and revokes only the current user's access" do
    access = create(:accountant_access, user: user)
    original_token = access.public_token

    post "/accountant_accesses/#{access.id}/rotate"
    expect(AccountantAccess.authenticate(original_token)).to be_nil

    post "/accountant_accesses/#{access.id}/revoke"
    expect(access.reload).not_to be_active

    other_access = create(:accountant_access)
    post "/accountant_accesses/#{other_access.id}/revoke"
    expect(response).to have_http_status(:not_found)
    expect(other_access.reload).to be_active
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
