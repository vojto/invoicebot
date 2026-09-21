# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCategorizationAgent do
  subject(:agent) { described_class.new(invoice) }

  let(:user) { create(:user) }
  let(:email) { create(:email, user: user, subject: "Your hosting invoice", from_address: "billing@example.com") }
  let(:invoice) { create(:invoice, user: user, email: email, vendor_name: "Heroku") }
  let!(:hosting) { create(:category, user: user, name: "Hosting", note: "Servers and cloud platforms") }

  it "returns the chosen category and describes the options in the prompt" do
    answer_with(hosting.id)

    expect(agent.call).to eq(hosting)
    expect(agent).to have_received(:ask) do |prompt|
      expect(prompt).to include(
        "Heroku",
        "Your hosting invoice",
        "billing@example.com",
        "Hosting",
        "Servers and cloud platforms"
      )
    end
  end

  it "returns nothing when the model picks no category" do
    answer_with(nil)

    expect(agent.call).to be_nil
  end

  it "returns nothing when the model picks a category the user does not own" do
    answer_with(create(:category).id)

    expect(agent.call).to be_nil
  end

  it "skips the model when the user has no categories" do
    hosting.destroy!
    allow(agent).to receive(:ask)

    expect(agent.call).to be_nil
    expect(agent).not_to have_received(:ask)
  end

  def answer_with(category_id)
    allow(agent).to receive(:ask)
      .and_return(RubyLLM::Message.new(role: :assistant, content: { category_id: category_id }.to_json))
  end
end
