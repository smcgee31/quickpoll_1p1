# Shared setup for request specs that need a launch Canvas would accept.
#
# Canvas signs launches with a real key, so these specs sign their own. The `sign` helper is a plain
# copy of the OAuth 1.0a recipe. The verifier spec already checks the real algorithm against
# launches that Canvas signed.
#
# Use it with: include_context "with signed launches"
# Then: post "/lti/launch", params: signed_params
#       signed_params({ "user_id" => "other" })  # braces needed: string keys without them count as keywords
RSpec.shared_context "with signed launches" do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.at(1_800_000_000) }
  let(:public_base_url) { "http://quickpoll-test.example" }
  let(:launch_url) { "#{public_base_url}/lti/launch" }
  let(:consumer) { create(:lti_consumer, consumer_key: "key", shared_secret: "secret") }
  let(:teacher_params) do
    JSON.parse(Rails.root.join("spec/fixtures/lti1p1/teacher_launch.json").read)["params"]
        .except("oauth_signature", "oauth_nonce", "oauth_timestamp")
  end

  around do |example|
    original = Rails.configuration.x.public_base_url
    Rails.configuration.x.public_base_url = public_base_url
    travel_to(now) { example.run }
  ensure
    Rails.configuration.x.public_base_url = original
  end

  # Returns the launch params with oauth_timestamp, oauth_nonce, and oauth_signature added.
  def signed_params(overrides = {}, secret: consumer.shared_secret, timestamp: now.to_i, nonce: SecureRandom.hex(8))
    params = teacher_params.merge(
      "oauth_consumer_key" => consumer.consumer_key,
      "oauth_timestamp" => timestamp.to_s,
      "oauth_nonce" => nonce
    ).merge(overrides)
    params.merge("oauth_signature" => sign(params, secret))
  end

  def sign(params, secret)
    encode = ->(value) { ERB::Util.url_encode(value.to_s) }
    pairs = params.map { |k, v| [ encode.(k), encode.(v) ] }.sort.map { |k, v| "#{k}=#{v}" }.join("&")
    base = "POST&#{encode.(launch_url)}&#{encode.(pairs)}"
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", "#{encode.(secret)}&", base))
  end
end
