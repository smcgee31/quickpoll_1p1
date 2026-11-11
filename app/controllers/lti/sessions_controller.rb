module Lti
  class SessionsController < BaseController
    before_action :require_launch

    def show
      role_sentence = can_create_polls? ? "You may create polls." : "You may vote."

      render plain: <<~TEXT
        Signed in as #{current_lti_user.name} in course #{current_lti_context.title}.
        #{role_sentence}

        can_create_polls? is #{can_create_polls?}
      TEXT
    end
  end
end
