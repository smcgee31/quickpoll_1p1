module Lti
  # Canvas posts launches from another origin and shows the response in an iframe.
  class BaseController < ApplicationController
    skip_forgery_protection
    # before_action, not after_action. A before_action that renders (the 401) skips every after_action.
    before_action :allow_framing

    private

    def current_lti_user
      @current_lti_user ||= LtiUser.find_by(id: session[:lti_user_id])
    end

    def current_lti_context
      @current_lti_context ||= LtiContext.find_by(id: session[:lti_context_id])
    end

    def require_launch
      unless current_lti_user && current_lti_context
        reset_session
        render plain: "Launch required.", status: :unauthorized
      end
    end

    def can_create_polls?
      session[:can_create_polls] == true
    end

    # Rails sets X-Frame-Options: SAMEORIGIN by default. That blocks the Canvas iframe.
    def allow_framing
      response.headers.delete("X-Frame-Options")
    end
  end
end
