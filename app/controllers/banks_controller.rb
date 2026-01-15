class BanksController < ApplicationController
  before_action :require_authentication, except: [:callback]

  def index
    client = NordigenService.new(current_user).client
    institutions = client.institution.get_institutions("SK")

    render inertia: "banks/index", props: {
      institutions: institutions.map { |inst| serialize_institution(inst) }
    }
  end

  def connect
    institution_id = params[:institution_id]
    institution_name = params[:institution_name]
    reference_id = SecureRandom.uuid

    client = NordigenService.new(current_user).client

    session_data = client.init_session(
      redirect_url: callback_banks_url,
      institution_id: institution_id,
      reference_id: reference_id,
      user_language: "en",
      account_selection: false
    )

    current_user.bank_connections.create!(
      institution_id: institution_id,
      institution_name: institution_name,
      requisition_id: session_data["id"],
      reference_id: reference_id,
      status: :pending
    )

    inertia_location session_data["link"]
  end

  def callback
    reference_id = params[:ref]
    connection = BankConnection.find_by!(reference_id: reference_id)
    connection.update!(status: :linked)

    TransactionSyncJob.perform_later(bank_connection_id: connection.id)

    redirect_to transactions_path
  end

  private

  def serialize_institution(institution)
    {
      id: institution["id"],
      name: institution["name"],
      logo: institution["logo"],
      countries: institution["countries"]
    }
  end
end
