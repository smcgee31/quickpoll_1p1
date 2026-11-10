module Lti
  class LaunchController < BaseController
    before_action :verify_launch

    def create
      render plain: "Launch verified."
    end

    private

    # Three checks, in this order. The first one that fails ends the request with a 401.
    def verify_launch
      consumer = LtiConsumer.find_by(consumer_key: request.request_parameters["oauth_consumer_key"])
      return reject(:unknown_consumer) if consumer.nil?

      verifier = Lti1p1::SignatureVerifier.new(
        method: request.method,
        url: "#{Rails.configuration.x.public_base_url}#{request.fullpath}",
        params: request.request_parameters,
        secret: consumer.shared_secret
      )
      return reject(:bad_signature) unless verifier.valid?

      guard = Lti1p1::ReplayGuard.new(consumer:, params: request.request_parameters)
      reject(guard.error) unless guard.accept?
    end

    # The reason goes in the log. The response gives the caller nothing to probe.
    def reject(reason)
      Rails.logger.warn("[lti launch] rejected: #{reason}")
      render plain: "Launch rejected.", status: :unauthorized
    end
  end
end
