module Lti
  class PollsController < BaseController
    protect_from_forgery with: :exception

    before_action :require_launch
    before_action :require_poll_creator, only: :create

    def index
      @polls = current_lti_context.polls.order(created_at: :desc)
      @poll = Poll.new
    end

    def create
      options = params.dig(:poll, :options_text).to_s.lines.map(&:strip).reject(&:empty?)
      @poll = current_lti_context.polls.new(
        creator: current_lti_user,
        question: params.dig(:poll, :question),
        options: options
      )

      if @poll.save
        redirect_to lti_polls_path, status: :see_other
      else
        @polls = current_lti_context.polls.order(created_at: :desc)
        render :index, status: :unprocessable_content
      end
    end
  end
end
