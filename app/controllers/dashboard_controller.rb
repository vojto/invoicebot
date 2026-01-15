class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    render inertia: "dashboard/show"
  end
end
