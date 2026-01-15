class BanksController < ApplicationController
  before_action :require_authentication

  def index
    client = NordigenService.new(current_user).client
    institutions = client.institution.get_institutions("SK")

    render inertia: "banks/index", props: {
      institutions: institutions.map { |inst| serialize_institution(inst) }
    }
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
