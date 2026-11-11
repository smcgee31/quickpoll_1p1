require "rails_helper"

# Stage 4, step 5. Remember what the person may do, so the poll pages can ask.
#
# Lti1p1::Roles reads one launch. The next click carries no LTI params, so the answer must live in
# the session next to the user id.
#
# What to build:
#   - Lti::LaunchController#create: after reset_session, store
#       session[:can_create_polls] = Lti1p1::Roles.new(request.request_parameters).can_create_polls?
#     Store the yes or no answer only. Not the raw role strings.
#   - Lti::BaseController: a private helper can_create_polls? that reads the session value.
#     It is true only for a stored true. A missing value means false.
#   - Lti::SessionsController#show: add a sentence to the page. "You may create polls." for a poll
#     creator and "You may vote." for everyone else. Keep the existing sentence.
#
# Why the session and not a re-check: the browser holds a signed, encrypted cookie. A person cannot
# edit it. A new launch replaces the answer, so a role change in Canvas shows up on the next launch.
RSpec.describe "Roles in the session", type: :request do
  include_context "with signed launches"

  let(:student_roles) do
    {
      "roles" => "Learner",
      "ext_roles" => "urn:lti:instrole:ims/lis/Student,urn:lti:role:ims/lis/Learner,urn:lti:sysrole:ims/lis/User"
    }
  end
  let(:ta_roles) do
    {
      "roles" => "urn:lti:role:ims/lis/TeachingAssistant",
      "ext_roles" => "urn:lti:instrole:ims/lis/Instructor,urn:lti:role:ims/lis/TeachingAssistant,urn:lti:sysrole:ims/lis/User"
    }
  end

  it "lets an instructor create polls" do
    post "/lti/launch", params: signed_params

    expect(session[:can_create_polls]).to be(true)
    get "/lti/me"
    expect(response.body).to include("You may create polls.")
  end

  it "lets a teaching assistant create polls" do
    post "/lti/launch", params: signed_params(ta_roles)

    expect(session[:can_create_polls]).to be(true)
    get "/lti/me"
    expect(response.body).to include("You may create polls.")
  end

  it "lets a learner vote only" do
    post "/lti/launch", params: signed_params(student_roles)

    expect(session[:can_create_polls]).to be(false)
    get "/lti/me"
    expect(response.body).to include("You may vote.")
    expect(response.body).not_to include("You may create polls.")
  end

  it "lets a launch with no role fields vote only" do
    post "/lti/launch", params: signed_params({ "roles" => "", "ext_roles" => "" })

    expect(session[:can_create_polls]).to be(false)
    get "/lti/me"
    expect(response.body).to include("You may vote.")
  end

  it "replaces the answer when a learner launches in the browser of an instructor" do
    post "/lti/launch", params: signed_params
    post "/lti/launch", params: signed_params(student_roles)

    expect(session[:can_create_polls]).to be(false)
  end

  it "keeps the existing sentence about who launched" do
    post "/lti/launch", params: signed_params

    get "/lti/me"

    expect(response.body).to include("Signed in as Test Teacher 1 in course Test Course 1.")
  end
end
