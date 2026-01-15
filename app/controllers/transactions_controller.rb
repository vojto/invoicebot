class TransactionsController < ApplicationController
  before_action :require_authentication

  def index
    render inertia: "transactions/index", props: {}
  end
end
