require "rails_helper"

# Stage 4, step 7. Voting.
#
# Rules (you agreed to these):
#   - Anyone in the course may vote once per poll. An instructor or a TA may vote too.
#   - A person who has NOT voted sees the choices as a vote form, and sees no counts.
#   - After a person votes, the poll shows the counts, and "You voted: <choice>".
#   - A poll creator (instructor or TA) always sees the counts, even before voting.
#
# What to build:
#   - Route: nest votes under polls, so the URL is POST /lti/polls/:poll_id/votes.
#       resources :polls, only: %i[index create] do
#         resources :votes, only: :create
#       end
#   - Lti::VotesController < BaseController (app/controllers/lti/votes_controller.rb). Plural, because
#     it serves rows of the votes table. Turn forgery protection on, as PollsController does. Use
#     require_launch.
#   - create:
#       * Find the poll through current_lti_context.polls, never Poll.find. A poll from another course
#         must answer 404. An unknown id must answer 404.
#       * The voter is current_lti_user from the session. The form never says who votes.
#       * The form field is vote[option_index], a radio button. The value is the position of the
#         choice in poll.options, starting at 0.
#       * Always redirect to /lti/polls with 303. Say what happened in flash[:alert]:
#           "You already voted on this poll."   (the person has a vote on this poll)
#           "Choose one of the choices."        (no choice, or a number that is not a choice)
#         The model already rejects a bad option_index. A success sets no alert.
#   - app/views/lti/polls/index.html.erb: show flash[:alert] at the top. For each poll show the vote
#     form or the counts, by the rules above. A count line looks like "Red: 2". A zero shows "Blue: 0".
#     Ask the database for all counts of the listed polls at once. Do not count inside the loop.
#
# A vote is a vote, and two people can vote at the same moment. The unique index on
# (poll_id, lti_user_id) is the last defense. The validation is the polite one.
RSpec.describe "Voting", type: :request do
  include_context "with signed launches"

  let(:student_roles) do
    {
      "roles" => "Learner",
      "ext_roles" => "urn:lti:instrole:ims/lis/Student,urn:lti:role:ims/lis/Learner,urn:lti:sysrole:ims/lis/User"
    }
  end
  let(:student) { { "user_id" => "student-1", "lis_person_name_full" => "Test Student 1" }.merge(student_roles) }
  let(:course) { LtiContext.find(session[:lti_context_id]) }
  let(:me) { LtiUser.find(session[:lti_user_id]) }

  def launch(overrides = {})
    post "/lti/launch", params: signed_params(overrides)
  end

  def vote_on(poll, option_index)
    post "/lti/polls/#{poll.id}/votes", params: { vote: { option_index: option_index } }
  end

  describe "the poll page" do
    context "before the person votes" do
      it "shows a vote form with each choice, and no counts, to a learner" do
        launch(student)
        poll = create(:poll, lti_context: course, options: %w[Red Blue])
        create(:vote, poll: poll, option_index: 0)

        get "/lti/polls"

        expect(response.body).to include("vote[option_index]", "Red", "Blue")
        expect(response.body).not_to match(/Red: \d/)
        expect(response.body).not_to include("You voted")
      end

      it "shows the counts and the vote form to a poll creator" do
        launch
        poll = create(:poll, lti_context: course, options: %w[Red Blue])
        create(:vote, poll: poll, option_index: 0)
        create(:vote, poll: poll, option_index: 0)

        get "/lti/polls"

        expect(response.body).to include("Red: 2", "Blue: 0", "vote[option_index]")
      end
    end

    context "after the person votes" do
      it "shows the counts and the choice, and no vote form" do
        launch(student)
        poll = create(:poll, lti_context: course, options: %w[Red Blue])
        create(:vote, poll: poll, option_index: 0)
        vote_on(poll, 1)

        get "/lti/polls"

        expect(response.body).to include("Red: 1", "Blue: 1", "You voted: Blue")
        expect(response.body).not_to include("vote[option_index]")
      end

      it "counts each poll on its own" do
        launch(student)
        first = create(:poll, lti_context: course, options: %w[Red Blue])
        second = create(:poll, lti_context: course, options: %w[Yes No])
        vote_on(first, 0)
        vote_on(second, 1)
        create(:vote, poll: second, option_index: 1)

        get "/lti/polls"

        expect(response.body).to include("Red: 1", "Blue: 0", "Yes: 0", "No: 2")
      end
    end

    it "shows the message from a refused vote on the next page" do
      launch(student)
      poll = create(:poll, lti_context: course, options: %w[Red Blue])
      vote_on(poll, 0)
      vote_on(poll, 1)

      follow_redirect!

      expect(response.body).to include("You already voted on this poll.")
    end
  end

  describe "POST /lti/polls/:poll_id/votes" do
    it "answers 401 without a launch and saves nothing" do
      poll = create(:poll)

      expect { vote_on(poll, 0) }.not_to change(Vote, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it "lets a learner vote, and goes back to the poll page" do
      launch(student)
      poll = create(:poll, lti_context: course, options: %w[Red Blue Green])

      expect { vote_on(poll, 2) }.to change(Vote, :count).by(1)

      expect(Vote.last).to have_attributes(poll: poll, lti_user: me, option_index: 2)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/lti/polls")
      expect(flash[:alert]).to be_nil
    end

    it "lets an instructor vote" do
      launch
      poll = create(:poll, lti_context: course)

      expect { vote_on(poll, 0) }.to change(Vote, :count).by(1)
    end

    it "lets a different person vote on the same poll" do
      launch
      poll = create(:poll, lti_context: course)
      vote_on(poll, 0)
      launch(student)

      expect { vote_on(poll, 1) }.to change(Vote, :count).by(1)
    end

    it "refuses a second vote on the same poll and keeps the first" do
      launch(student)
      poll = create(:poll, lti_context: course)
      vote_on(poll, 0)

      expect { vote_on(poll, 1) }.not_to change(Vote, :count)

      expect(Vote.last.option_index).to eq(0)
      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("You already voted on this poll.")
    end

    it "refuses a choice that is not on the poll" do
      launch(student)
      poll = create(:poll, lti_context: course, options: %w[Red Blue])

      [ 2, 99, -1 ].each do |bad|
        expect { vote_on(poll, bad) }.not_to change(Vote, :count)
        expect(flash[:alert]).to eq("Choose one of the choices.")
      end
    end

    it "refuses a vote with no choice" do
      launch(student)
      poll = create(:poll, lti_context: course)

      expect { post "/lti/polls/#{poll.id}/votes", params: { vote: { option_index: "" } } }.not_to change(Vote, :count)
      expect(flash[:alert]).to eq("Choose one of the choices.")

      expect { post "/lti/polls/#{poll.id}/votes" }.not_to change(Vote, :count)
      expect(flash[:alert]).to eq("Choose one of the choices.")
    end

    it "answers 404 for a poll in another course" do
      launch(student)
      other_poll = create(:poll, lti_context: create(:lti_context, lti_consumer: consumer))

      expect { vote_on(other_poll, 0) }.not_to change(Vote, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "answers 404 for a poll that does not exist" do
      launch(student)

      expect { post "/lti/polls/0/votes", params: { vote: { option_index: 0 } } }.not_to change(Vote, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "takes the voter from the session, not from the form" do
      launch(student)
      poll = create(:poll, lti_context: course)
      someone_else = create(:lti_user, lti_consumer: consumer)

      post "/lti/polls/#{poll.id}/votes", params: { vote: { option_index: 0, lti_user_id: someone_else.id } }

      expect(Vote.last.lti_user).to eq(me)
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
        launch(student)
        poll = create(:poll, lti_context: course)

        expect { vote_on(poll, 0) }.not_to change(Vote, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
