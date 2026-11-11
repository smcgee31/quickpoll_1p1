require "rails_helper"

# Stage 4, step 3. Remember who launched, so the next page knows who is asking.
#
# One launch is one POST. The next click is a new request that carries no LTI params. The tool needs
# a way to say "this is still the teacher from course 1". That is the Rails session: a cookie
# the browser sends back on every request.
#
# What to build:
#   - Lti::LaunchController#create, after the records save: start a NEW session, then store the ids
#     session[:lti_user_id] and session[:lti_context_id]. Store ids only. Not names, params, or secrets.
#   - GET /lti/me (route, Lti::SessionsController#show): answers with who the session belongs to.
#     This page is a stand-in. The poll pages replace it later and use the same helpers.
#   - In Lti::BaseController: current_lti_user, current_lti_context, and a require_launch
#     before_action that answers 401 when the session has no user. Use it in SessionsController only.
#     LaunchController must not use it, because a launch has no session yet.
#
# "Start a NEW session" means reset_session before you store the ids. If you keep the old session,
# an attacker who planted a session cookie in the browser keeps it after the victim signs in.
# This attack is called session fixation.
RSpec.describe "GET /lti/me", type: :request do
  include_context "with signed launches"

  context "after a verified launch" do
    before { post "/lti/launch", params: signed_params }

    it "says who launched and from which course" do
      get "/lti/me"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Teacher 1")
      expect(response.body).to include("Test Course 1")
    end

    it "stores the ids of the saved rows in the session" do
      expect(session[:lti_user_id]).to eq(LtiUser.last.id)
      expect(session[:lti_context_id]).to eq(LtiContext.last.id)
    end

    it "allows the page to render in a Canvas iframe" do
      get "/lti/me"

      expect(response.headers["X-Frame-Options"]).to be_nil
    end

    it "answers for the newest launch when a different person launches in the same browser" do
      post "/lti/launch", params: signed_params({ "user_id" => "student-1", "lis_person_name_full" => "Test Student 1" })

      get "/lti/me"

      expect(response.body).to include("Test Student 1")
      expect(response.body).not_to include("Test Teacher 1")
    end

    it "starts a new session on every launch" do
      first_session_id = session.id.to_s

      post "/lti/launch", params: signed_params

      expect(session.id.to_s).not_to eq(first_session_id)
    end

    it "answers 401 and clears the session when the saved user no longer exists" do
      LtiUser.destroy_all

      get "/lti/me"

      expect(response).to have_http_status(:unauthorized)
      expect(session[:lti_user_id]).to be_nil
    end

    it "answers 401 and clears the session when the saved course no longer exists" do
      LtiContext.destroy_all

      get "/lti/me"

      expect(response).to have_http_status(:unauthorized)
      expect(session[:lti_context_id]).to be_nil
    end
  end

  context "without a launch" do
    it "answers 401" do
      get "/lti/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 401 after a launch that was rejected" do
      post "/lti/launch", params: signed_params(secret: "not-the-secret")

      get "/lti/me"

      expect(response).to have_http_status(:unauthorized)
      expect(session[:lti_user_id]).to be_nil
    end

    it "still allows the 401 to render in a Canvas iframe" do
      get "/lti/me"

      expect(response.headers["X-Frame-Options"]).to be_nil
    end
  end
end
