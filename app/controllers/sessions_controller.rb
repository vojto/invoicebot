class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :google_callback

  def google_callback
    auth = request.env["omniauth.auth"]

    user = current_user || User.find_or_initialize_by(google_uid: auth.uid)
    user.email ||= auth.info.email
    user.name ||= auth.info.name
    user.picture_url ||= auth.info.image

    creds = auth.credentials
    user.google_access_token = creds.token
    user.google_refresh_token = creds.refresh_token.presence || user.google_refresh_token
    user.google_token_expires_at = Time.at(creds.expires_at) if creds.expires_at
    user.save!

    session[:user_id] ||= user.id

    PeriodicSyncAndProcessJob.perform_later(user_id: user.id)

    redirect_to dashboard_path, notice: "Google connected!"
  end

  def failure
    redirect_to root_path, alert: params[:message]
  end

  def logout
    session.delete(:user_id)
    redirect_to root_path, notice: "You have been signed out"
  end
end
