module Lti
  # Serves the LTI 1.1 XML cartridge that you paste into Canvas (Settings, Apps, + App, Paste XML).
  class ConfigurationController < BaseController
    def show
      base = Rails.configuration.x.public_base_url
      @launch_url = "#{base}/lti/launch"
      @domain = URI.parse(base).host
      @title = "QuickPoll 1.1"
      @description = "Quick polls for your course (LTI 1.1)"
      @placement = "course_navigation"
      render formats: :xml
    end
  end
end
