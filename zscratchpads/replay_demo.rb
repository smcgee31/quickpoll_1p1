# Sends one signed fake launch to the running app, twice, with the same nonce.
# Run inside the web container:
#   rails runner zscratchpads/replay_demo.rb
# Expect: first POST 200 "Launch verified.", second POST 401 "Launch rejected."
# It uses the seeded consumer (key "key", secret "secret") and fake user data only.
require "net/http"

consumer = LtiConsumer.find_by!(consumer_key: "key")
public_url = "#{Rails.configuration.x.public_base_url}/lti/launch"

params = {
  "oauth_consumer_key" => consumer.consumer_key,
  "oauth_signature_method" => "HMAC-SHA1",
  "oauth_version" => "1.0",
  "oauth_timestamp" => Time.now.to_i.to_s,
  "oauth_nonce" => SecureRandom.hex(16),
  "lti_message_type" => "basic-lti-launch-request",
  "lti_version" => "LTI-1p0",
  "user_id" => "fake-user-1",
  "roles" => "Instructor",
  "context_id" => "fake-context-1",
  "resource_link_id" => "fake-link-1",
  "lis_person_name_full" => "Fake Teacher"
}
verifier = Lti1p1::SignatureVerifier.new(method: "POST", url: public_url, params: params, secret: consumer.shared_secret)
params["oauth_signature"] = verifier.signature

# The app runs inside this container on port 80. The Host header must be one config.hosts allows.
uri = URI("http://localhost/lti/launch")
2.times do |i|
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.path, "Host" => URI(public_url).host)
  request.set_form_data(params)
  response = http.request(request)
  puts "POST ##{i + 1}: #{response.code} #{response.body.inspect}"
end
