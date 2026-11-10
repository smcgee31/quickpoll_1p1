module Lti
  # STUB for Stage 2. It does NOT verify the OAuth signature yet, so do not trust anything it shows.
  # Stage 3 replaces this with Lti1p1::SignatureVerifier.
  class LaunchController < BaseController
    def create
      Rails.logger.info("[lti launch] #{request.request_parameters.to_json}")
      render plain: "Launch received (UNVERIFIED, Stage 2 stub).\n\n" +
                    request.request_parameters.map { |k, v| "#{k}: #{v}" }.join("\n")
    end
  end
end
