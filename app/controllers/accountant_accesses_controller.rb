class AccountantAccessesController < ApplicationController
  before_action :require_authentication
  before_action :set_accountant_access, only: [ :revoke, :rotate ]

  def index
    render inertia: "accountant_accesses/index", props: {
      accountant_accesses: current_user.accountant_accesses.order(created_at: :asc).map { |access|
        serialize_accountant_access(access)
      }
    }
  end

  def create
    access = current_user.accountant_accesses.new(accountant_access_params)

    if access.save
      redirect_to accountant_accesses_path, notice: "Accountant access created"
    else
      redirect_to accountant_accesses_path, alert: access.errors.full_messages.to_sentence
    end
  end

  def revoke
    @accountant_access.revoke!
    redirect_to accountant_accesses_path, notice: "Accountant access revoked"
  end

  def rotate
    @accountant_access.rotate_token!
    redirect_to accountant_accesses_path, notice: "Accountant link regenerated"
  end

  private

  def set_accountant_access
    @accountant_access = current_user.accountant_accesses.find(params[:id])
  end

  def accountant_access_params
    params.require(:accountant_access).permit(:name)
  end

  def serialize_accountant_access(access)
    {
      id: access.id,
      name: access.name,
      active: access.active?,
      created_at: access.created_at.iso8601,
      last_accessed_at: access.last_accessed_at&.iso8601,
      public_url: access.active? ? accountant_month_url(
        access_token: access.public_token,
        month: Date.current.strftime("%Y-%m")
      ) : nil
    }
  end
end
