require "rails_helper"

# Stage 4, step 1. Make Lti::LaunchController check every launch before it trusts it.
# Edit app/controllers/lti/launch_controller.rb until this passes.
#
# The controller must do these things, in this order:
#   1. Find the LtiConsumer whose consumer_key equals params["oauth_consumer_key"].
#   2. Check the signature with Lti1p1::SignatureVerifier, using that consumer's shared_secret.
#   3. Only then call Lti1p1::ReplayGuard#accept?. (A bad signature must not save a nonce.)
#   4. If any step fails, answer 401 and show nothing from the launch.
#   5. If all steps pass, save the records, start the session, and redirect to /lti/polls (303).
#      (Before step 6 of Stage 4 this answered 200 with "Launch verified". The poll page replaced it.)
#
# The URL for step 2 is NOT request.url. Canvas signs the URL it was given, and a proxy can change
# the scheme or host on the way in. Build it from Rails.configuration.x.public_base_url plus
# request.fullpath. This is why config/initializers/lti.rb exists.
#
# Canvas signs launches with a real key, so these specs sign their own launches. The helper is in
# spec/support/signed_launches.rb. The verifier spec already checks the real algorithm
# against launches that Canvas signed.

RSpec.describe "POST /lti/launch", type: :request do
  include_context "with signed launches"

  context "with a launch Canvas signed correctly" do
    it "redirects to the poll page with 303" do
      post "/lti/launch", params: signed_params

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/lti/polls")
    end

    it "saves the nonce" do
      expect { post "/lti/launch", params: signed_params }.to change { consumer.used_nonces.count }.by(1)
    end

    it "accepts a launch where Canvas left ?placement on the URL and also put it in the body" do
      post "/lti/launch?placement=course_navigation", params: signed_params({ "placement" => "course_navigation" })

      expect(response).to have_http_status(:see_other)
    end

    it "allows the response to render in a Canvas iframe" do
      post "/lti/launch", params: signed_params

      expect(response.headers["X-Frame-Options"]).to be_nil
    end
  end

  context "with a verified launch, the records" do
    it "creates the user and the course for the consumer" do
      expect { post "/lti/launch", params: signed_params }
        .to change { consumer.lti_users.count }.by(1)
        .and change { consumer.lti_contexts.count }.by(1)
    end

    it "does not create a second user when the same person launches again" do
      post "/lti/launch", params: signed_params

      expect { post "/lti/launch", params: signed_params }.not_to change(LtiUser, :count)
    end

    it "answers 400 when a verified launch has no user_id" do
      post "/lti/launch", params: signed_params({ "user_id" => "" })

      expect(response).to have_http_status(:bad_request)
    end
  end

  context "with a launch that must be rejected" do
    it "rejects a launch with no oauth_consumer_key" do
      post "/lti/launch", params: signed_params.except("oauth_consumer_key")

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a launch from a consumer key we do not know" do
      post "/lti/launch", params: signed_params({ "oauth_consumer_key" => "stranger" })

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a launch signed with the wrong secret" do
      post "/lti/launch", params: signed_params(secret: "not-the-secret")

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a launch that changed after it was signed" do
      params = signed_params
      params["roles"] = "Administrator"

      post "/lti/launch", params: params

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a launch with a timestamp older than 5 minutes" do
      post "/lti/launch", params: signed_params(timestamp: now.to_i - 301)

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects the same launch the second time" do
      params = signed_params

      post "/lti/launch", params: params
      expect(response).to have_http_status(:see_other)

      post "/lti/launch", params: params
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not save a nonce when the signature is wrong" do
      consumer

      expect { post "/lti/launch", params: signed_params(secret: "not-the-secret") }.not_to change(UsedNonce, :count)
    end

    it "does not show the launch params in the response" do
      post "/lti/launch", params: signed_params(secret: "not-the-secret")

      expect(response.body).not_to include("Test Teacher 1")
    end

    it "still allows the rejection to render in a Canvas iframe" do
      post "/lti/launch", params: signed_params(secret: "not-the-secret")

      expect(response.headers["X-Frame-Options"]).to be_nil
    end
  end
end
