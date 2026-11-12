module Lti
  class PollsController < BaseController
    protect_from_forgery with: :exception

    before_action :require_launch
    before_action :require_poll_creator, only: :create

    def index
      @polls = current_lti_context.polls.order(created_at: :desc)
      @poll = Poll.new
      load_votes
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
        load_votes
        render :index, status: :unprocessable_content
      end
    end

    private

    def load_votes
      @my_votes = current_lti_user.votes.where(poll: @polls).index_by(&:poll_id)
      @counts = Vote.where(poll: @polls).group(:poll_id, :option_index).count
    end
  end
end
