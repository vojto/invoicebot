# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCategorizationAgent do
  subject(:agent) { described_class.new(invoice) }

  let(:user) { create(:user) }
  let(:email) { create(:email, user: user, subject: "Your hosting invoice", from_address: "billing@example.com") }
  let(:invoice) { create(:invoice, user: user, email: email, vendor_name: "Heroku") }
  let!(:hosting) { create(:category, user: user, name: "Hosting", note: "Servers and cloud platforms") }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:schema_chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).with(
      model: described_class::MODEL,
      provider: described_class::PROVIDER
    ).and_return(chat)
    allow(chat).to receive(:with_thinking).with(effort: described_class::REASONING_EFFORT).and_return(chat)
    allow(chat).to receive(:with_instructions).with(described_class::SYSTEM_PROMPT)
    allow(chat).to receive(:with_schema).with(described_class::ResponseSchema).and_return(schema_chat)
  end

  it "returns the chosen category and describes the options in the prompt" do
    answer_with(hosting.id)

    expect(agent.call).to eq(hosting)
    expect(schema_chat).to have_received(:ask) do |prompt|
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

    expect(agent.call).to be_nil
    expect(RubyLLM).not_to have_received(:chat)
  end

  def answer_with(category_id)
    allow(schema_chat).to receive(:ask).and_return(
      instance_double(
        RubyLLM::Message,
        content: { category_id: category_id },
        input_tokens: 100,
        output_tokens: 5
      )
    )
  end
end
