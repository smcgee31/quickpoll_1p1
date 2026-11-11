module Lti
  class LaunchController < BaseController
    before_action :verify_launch

    def create
      records = Lti1p1::LaunchRecords.new(consumer: @consumer, params: request.request_parameters)

      if records.call
        reset_session
        session[:lti_user_id] = records.user.id
        session[:lti_context_id] = records.context.id

        render plain: "Launch verified. Hello, #{records.user.name}. Course: #{records.context.title}."
      else
        Rails.logger.warn("[lti launch] rejected: #{records.error}")
        render plain: "Launch failed.", status: :bad_request
      end
    end

    private

    def verify_launch
      @consumer = LtiConsumer.find_by(consumer_key: request.request_parameters["oauth_consumer_key"])
      return reject(:unknown_consumer) if @consumer.nil?

      verifier = Lti1p1::SignatureVerifier.new(
        method: request.method,
        url: "#{Rails.configuration.x.public_base_url}#{request.fullpath}",
        params: request.request_parameters,
        secret: @consumer.shared_secret
      )
      return reject(:bad_signature) unless verifier.valid?

      guard = Lti1p1::ReplayGuard.new(consumer: @consumer, params: request.request_parameters)
      reject(guard.error) unless guard.accept?
    end

    def reject(reason)
      Rails.logger.warn("[lti launch] rejected: #{reason}")
      render plain: "Launch rejected.", status: :unauthorized
    end
  end
end
