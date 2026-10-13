require "rails_helper"

RSpec.describe InvoiceCategorizationJob, type: :job do
  let(:user) { create(:user) }
  let!(:category) { create(:category, user: user) }
  let(:invoice) { create(:invoice, user: user) }

  it "assigns the chosen category and stamps the attempt" do
    stub_agent(category)

    described_class.perform_now(invoice.id)

    invoice.reload
    expect(invoice.category).to eq(category)
    expect(invoice.ai_categorization_attempted_at).to be_present
  end

  it "stamps the attempt even when no category fits" do
    stub_agent(nil)

    described_class.perform_now(invoice.id)

    invoice.reload
    expect(invoice.category).to be_nil
    expect(invoice.ai_categorization_attempted_at).to be_present
  end

  it "leaves an already categorized invoice alone" do
    invoice.update!(category: category)
    allow(InvoiceCategorizationAgent).to receive(:new)

    described_class.perform_now(invoice.id)

    expect(InvoiceCategorizationAgent).not_to have_received(:new)
    expect(invoice.reload.ai_categorization_attempted_at).to be_nil
  end

  def stub_agent(result)
    allow(InvoiceCategorizationAgent).to receive(:new)
      .and_return(instance_double(InvoiceCategorizationAgent, call: result))
  end
end
