module AuthHelper
  def sign_in(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:user_signed_in?).and_return(true)
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
