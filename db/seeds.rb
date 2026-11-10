# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Local dev consumer. Use key "key" and secret "secret" when you install the XML in Canvas.
LtiConsumer.find_or_create_by!(consumer_key: "key") do |consumer|
  consumer.name = "Local Canvas"
  consumer.shared_secret = "secret"
end
