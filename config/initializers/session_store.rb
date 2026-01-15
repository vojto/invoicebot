Rails.application.config.session_store :cookie_store,
  key: "_invoicebot_session",
  expire_after: 20.years
