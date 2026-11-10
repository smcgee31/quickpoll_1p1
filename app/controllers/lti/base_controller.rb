module Lti
  # Canvas posts launches from another origin and shows the response in an iframe.
  class BaseController < ApplicationController
    skip_forgery_protection
    after_action :allow_framing

    private

    # Rails sets X-Frame-Options: SAMEORIGIN by default. That blocks the Canvas iframe.
    def allow_framing
      response.headers.delete("X-Frame-Options")
    end
  end
end
