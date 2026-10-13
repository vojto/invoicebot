require "rails_helper"

RSpec.describe SessionsController, type: :controller do
  it "replaces a stale session user after Google authentication" do
    user = create(:user)
    session[:user_id] = user.id + 1
    request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      uid: user.google_uid,
      info: {
        email: user.email,
        name: user.name,
        image: nil
      },
      credentials: {
        token: "new-access-token",
        refresh_token: "new-refresh-token",
        expires_at: 1.hour.from_now.to_i
      }
    )

    get :google_callback, params: { provider: "google_oauth2" }

    expect(session[:user_id]).to eq(user.id)
    expect(response).to redirect_to(dashboard_path)
  end
end
