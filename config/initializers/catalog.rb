# Network rules for every source request (spec §6.7).
Rails.application.configure do
  config.x.catalog.timeout = 15 # seconds, open + read
  config.x.catalog.user_agent = "catalogador-autopartes/1.0 (prueba tecnica)"
  # One request per second per host; tests run without waiting.
  config.x.catalog.min_interval = Rails.env.test? ? 0 : 1.0
end
