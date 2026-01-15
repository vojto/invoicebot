class WelcomeController < ApplicationController
  def index
    render inertia: "welcome/index"
  end
end
