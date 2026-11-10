module Lti1p1
  class ReplayGuard
    WINDOW_SECONDS = 300

    attr_reader :error

    def initialize(consumer:, params:, now: Time.current)
      @consumer = consumer
      @timestamp = Integer(params["oauth_timestamp"].to_s, exception: false)
      @nonce = params["oauth_nonce"].to_s
      @now = now
      @error = nil
    end

    def accept?
      return reject(:invalid) if @timestamp.nil? || @nonce.empty?
      return reject(:stale_timestamp) if (@timestamp - @now.to_i).abs > WINDOW_SECONDS
      return reject(:replayed_nonce) unless save_nonce

      true
    end

    private

    def reject(reason)
      @error = reason
      false
    end

    def save_nonce
      @consumer.used_nonces.create!(nonce: @nonce, oauth_timestamp: @timestamp)
      true
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      false
    end
  end
end
