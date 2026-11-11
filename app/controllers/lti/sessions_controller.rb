module Lti
  class SessionsController < BaseController
    before_action :require_launch

    def show
      render plain: "Signed in as #{current_lti_user.name} in course #{current_lti_context.title}."
    end
  end
end
