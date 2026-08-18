require "rails_helper"

RSpec.describe Invoice, type: :model do
  let(:user) { create(:user) }

  context "when the user has categories" do
    let!(:category) { create(:category, user: user) }

    it "enqueues categorization for a new uncategorized invoice" do
      expect { create(:invoice, user: user) }.to have_enqueued_job(InvoiceCategorizationJob)
    end

    it "enqueues categorization once extraction fills in the vendor" do
      invoice = create(:invoice, user: user, vendor_name: nil)

      expect { invoice.update!(vendor_name: "Heroku") }.to have_enqueued_job(InvoiceCategorizationJob)
    end

    it "does not enqueue when the invoice already has a category" do
      expect { create(:invoice, user: user, category: category) }
        .not_to have_enqueued_job(InvoiceCategorizationJob)
    end

    it "does not enqueue when the vendor is still unknown" do
      expect { create(:invoice, user: user, vendor_name: nil) }
        .not_to have_enqueued_job(InvoiceCategorizationJob)
    end

    it "does not enqueue when categorization was already attempted" do
      expect { create(:invoice, user: user, ai_categorization_attempted_at: Time.current) }
        .not_to have_enqueued_job(InvoiceCategorizationJob)
    end

    it "does not enqueue for a soft deleted invoice" do
      expect { create(:invoice, user: user, deleted_at: Time.current) }
        .not_to have_enqueued_job(InvoiceCategorizationJob)
    end
  end

  it "does not enqueue when the user has no categories" do
    expect { create(:invoice, user: user) }.not_to have_enqueued_job(InvoiceCategorizationJob)
  end
end
