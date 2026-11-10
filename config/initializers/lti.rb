# The URL Canvas uses to reach this app. Canvas signs the launch URL, so the
# signature check builds the URL from this value, not from request.url.
Rails.configuration.x.public_base_url = ENV.fetch("PUBLIC_BASE_URL", "http://localhost:3000")
