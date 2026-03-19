class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :refresh_google_token_if_needed, if: :user_signed_in?
  inertia_share user: -> { current_user_props }, signed_in: -> { user_signed_in? }, flash: -> { flash_props }

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def refresh_google_token_if_needed
    return unless current_user&.google_token_expires_soon?

    begin
      current_user.ensure_fresh_google_credentials!(
        scopes: GoogleCredentials::SCOPE_GMAIL
      )
    rescue StandardError => e
      Rails.logger.error("Error refreshing Google token: #{e.message}")
    end
  end

  def require_authentication
    redirect_to root_path unless user_signed_in?
  end

  def current_user_props
    return nil unless user_signed_in?

    {
      id: current_user.id,
      email: current_user.email,
      name: current_user.name,
      picture_url: current_user.picture_url
    }
  end

  def flash_props
    flash.to_hash.slice("notice", "alert")
  end

  def pdf_upload_param(key = :file)
    file = params[key]
    return nil unless file.present?
    return nil unless file.respond_to?(:content_type) && file.respond_to?(:original_filename)

    return file if file.content_type == "application/pdf"
    return file if file.original_filename.to_s.downcase.end_with?(".pdf")

    nil
  end
end
