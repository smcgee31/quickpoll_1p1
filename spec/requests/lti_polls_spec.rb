require "rails_helper"

# Stage 4, step 6. One page for polls: GET /lti/polls lists them, POST /lti/polls creates one.
#
# What to build:
#   - Route: inside namespace :lti, `resources :polls, only: %i[index create]`.
#   - Lti::PollsController < BaseController. Rails finds app/controllers/lti/polls_controller.rb for it.
#     Plural, because it serves rows of the polls table.
#   - before_action :require_launch for every action (401 without a launch).
#   - before_action :require_poll_creator for create only. It answers 403 when can_create_polls? is
#     false. Put require_poll_creator in BaseController next to require_launch.
#   - index: the polls of the CURRENT course only (current_lti_context.polls), newest first.
#     View: app/views/lti/polls/index.html.erb. The page names the person and the course at the top
#     (this replaces the old launch text). Views cannot call a controller's private methods, so the view
#     needs `helper_method :can_create_polls?` in BaseController. Everyone sees the polls. Only a poll creator sees the
#     "New poll" form. A missing form is not protection. The 403 on create is the protection.
#   - create: build the poll from the question and the options text, one choice per line. Trim each
#     line and drop empty lines. Take the course and the creator from the SESSION, never from params.
#     Success: redirect to /lti/polls with 303. Failure: answer 422 and show the error messages.
#   - Forgery protection: BaseController turns it off for the launch POST, which Canvas signs. The
#     poll form is a normal form from this app, so turn it back on in PollsController with
#     `protect_from_forgery with: :exception`. Rails' test setup disables it, so one example below
#     switches it on.
#   - Launch change: LaunchController#create no longer renders text. It redirects to /lti/polls with
#     status 303 (:see_other), so the Canvas iframe shows the poll page. The launch specs changed to match.
#
# Form field names: poll[question] and poll[options_text] (a textarea, one choice per line).
RSpec.describe "Polls", type: :request do
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
  let(:new_poll) { { poll: { question: "Favorite color?", options_text: "Red\nBlue\nGreen" } } }

  def launch(overrides = {})
    post "/lti/launch", params: signed_params(overrides)
  end

  describe "GET /lti/polls" do
    it "answers 401 without a launch" do
      get "/lti/polls"

      expect(response).to have_http_status(:unauthorized)
    end

    it "names the person and the course at the top of the page" do
      launch

      get "/lti/polls"

      expect(response.body).to include("Test Teacher 1")
      expect(response.body).to include("Test Course 1")
    end

    it "says so when the course has no polls" do
      launch

      get "/lti/polls"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No polls yet.")
    end

    it "lists the polls of this course with their choices, newest first" do
      launch
      course = LtiContext.last
      create(:poll, lti_context: course, question: "Older question?", options: %w[Yes No], created_at: 2.days.ago)
      create(:poll, lti_context: course, question: "Newer question?", options: %w[Cats Dogs], created_at: 1.day.ago)

      get "/lti/polls"

      expect(response.body).to include("Older question?", "Newer question?", "Cats", "Dogs", "Yes", "No")
      expect(response.body.index("Newer question?")).to be < response.body.index("Older question?")
    end

    it "does not list the polls of another course" do
      launch
      create(:poll, lti_context: create(:lti_context, lti_consumer: consumer), question: "Other course question?")

      get "/lti/polls"

      expect(response.body).not_to include("Other course question?")
    end

    it "allows the page to render in a Canvas iframe" do
      launch

      get "/lti/polls"

      expect(response.headers["X-Frame-Options"]).to be_nil
    end

    it "shows the new poll form to an instructor" do
      launch

      get "/lti/polls"

      expect(response.body).to include("New poll", "poll[question]", "poll[options_text]")
    end

    it "shows the new poll form to a teaching assistant" do
      launch(ta_roles)

      get "/lti/polls"

      expect(response.body).to include("New poll", "poll[question]", "poll[options_text]")
    end

    it "shows the polls but no form to a learner" do
      launch(student_roles)
      create(:poll, lti_context: LtiContext.last, question: "Visible to learners?")

      get "/lti/polls"

      expect(response.body).to include("Visible to learners?")
      expect(response.body).not_to include("New poll")
      expect(response.body).not_to include("poll[question]")
    end
  end

  describe "POST /lti/polls" do
    it "answers 401 without a launch and saves nothing" do
      expect { post "/lti/polls", params: new_poll }.not_to change(Poll, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it "lets an instructor create a poll in the course they launched from" do
      launch

      expect { post "/lti/polls", params: new_poll }.to change(Poll, :count).by(1)

      poll = Poll.last
      expect(poll.question).to eq("Favorite color?")
      expect(poll.options).to eq(%w[Red Blue Green])
      expect(poll.lti_context).to eq(LtiContext.last)
      expect(poll.creator).to eq(LtiUser.last)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/lti/polls")
    end

    it "lets a teaching assistant create a poll" do
      launch(ta_roles)

      expect { post "/lti/polls", params: new_poll }.to change(Poll, :count).by(1)
    end

    it "refuses a learner with 403 and saves nothing" do
      launch(student_roles)

      expect { post "/lti/polls", params: new_poll }.not_to change(Poll, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "trims each choice and drops empty lines" do
      launch

      post "/lti/polls", params: { poll: { question: "Pick one", options_text: " Red \r\n\r\n  Blue\r\n \r\n" } }

      expect(Poll.last.options).to eq(%w[Red Blue])
    end

    it "takes the course and the creator from the session, not from the form" do
      launch
      launched_course = LtiContext.find(session[:lti_context_id])
      launched_user = LtiUser.find(session[:lti_user_id])
      other_course = create(:lti_context, lti_consumer: consumer)
      other_user = create(:lti_user, lti_consumer: consumer)

      post "/lti/polls", params: {
        poll: new_poll[:poll].merge(lti_context_id: other_course.id, creator_id: other_user.id)
      }

      expect(Poll.last.lti_context).to eq(launched_course)
      expect(Poll.last.creator).to eq(launched_user)
    end

    it "answers 422 and shows the error when there is only one choice" do
      launch

      expect do
        post "/lti/polls", params: { poll: { question: "Only one?", options_text: "Red" } }
      end.not_to change(Poll, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must have at least two choices")
    end

    it "answers 422 and shows the error when the question is blank" do
      launch

      expect do
        post "/lti/polls", params: { poll: { question: "", options_text: "Red\nBlue" } }
      end.not_to change(Poll, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("can&#39;t be blank")
    end

    context "with forgery protection on, as in development and production" do
      around do |example|
        original = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = original
      end

      it "refuses a form post that has no authenticity token" do
        launch

        expect { post "/lti/polls", params: new_poll }.not_to change(Poll, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
