class BanksController < ApplicationController
  before_action :require_authentication, except: [ :callback ]

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
    session_data, reference_id = create_bank_session(institution_id)

    current_user.bank_connections.create!(
      institution_id: institution_id,
      institution_name: institution_name,
      requisition_id: session_data["id"],
      reference_id: reference_id,
      status: :pending
    )

    inertia_location session_data["link"]
  end

  def reconnect
    connection = current_user.bank_connections.find(params[:id])
    session_data, reference_id = create_bank_session(connection.institution_id)

    connection.update!(
      requisition_id: session_data["id"],
      reference_id: reference_id,
      status: :pending
    )

    inertia_location session_data["link"]
  end

  def callback
    reference_id = params[:ref]
    connection = BankConnection.find_by!(reference_id: reference_id)
    connection.update!(status: :linked, sync_running: true, sync_error: nil)

    TransactionSyncJob.perform_later(bank_connection_id: connection.id)

    redirect_to transactions_path
  end

  private

  def create_bank_session(institution_id)
    reference_id = SecureRandom.uuid
    session_data = NordigenService.new(current_user).client.init_session(
      redirect_url: callback_banks_url,
      institution_id: institution_id,
      reference_id: reference_id,
      user_language: "en",
      account_selection: false
    )

    [ session_data, reference_id ]
  end

  def serialize_institution(institution)
    {
      id: institution["id"],
      name: institution["name"],
      logo: institution["logo"],
      countries: institution["countries"]
    }
  end
end
