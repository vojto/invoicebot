class LandingController < ApplicationController
  def show
    if user_signed_in?
      redirect_to dashboard_path
    else
      render inertia: "landing/show"
    end
  end
end
