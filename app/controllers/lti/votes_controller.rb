module Lti
  class VotesController < BaseController
    protect_from_forgery with: :exception

    before_action :require_launch

    def create
      poll = current_lti_context.polls.find(params[:poll_id])
      if poll.votes.exists?(lti_user: current_lti_user)
        redirect_to lti_polls_path, alert: "You already voted on this poll.", status: :see_other
        return
      end

      vote = poll.votes.new(
        lti_user: current_lti_user,
        option_index: params.dig(:vote, :option_index)
      )
      if vote.save
        redirect_to lti_polls_path, status: :see_other
      else
        redirect_to lti_polls_path, alert: "Choose one of the choices.", status: :see_other
      end
    end
  end
end
