class LandingController < ApplicationController
  def show
    render inertia: "landing/show"
  end
end
