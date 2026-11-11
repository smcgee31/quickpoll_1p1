module Lti1p1
  # Turns a verified launch into two rows: the person (LtiUser) and the course (LtiContext).
  # Call it only after the signature and replay checks pass. It trusts `params`.
  class LaunchRecords
    attr_reader :user, :context, :error

    def initialize(consumer:, params:)
      @consumer = consumer
      @params = params
      @error = nil
    end

    def call
      return reject(:missing_user_id) if @params["user_id"].blank?
      return reject(:missing_context_id) if @params["context_id"].blank?

      # One transaction: if the context fails to save, the user is not left behind.
      ActiveRecord::Base.transaction do
        @user = save_user
        @context = save_context
      end
      true
    end

    private

    def save_user
      user = @consumer.lti_users.find_or_initialize_by(lti1p1_user_id: @params["user_id"])
      # A launch with no name must not erase a name we already have.
      user.name = @params["lis_person_name_full"].presence || user.name
      user.save!
      user
    end

    def save_context
      context = @consumer.lti_contexts.find_or_initialize_by(context_id: @params["context_id"])
      context.title = @params["context_title"].presence || context.title
      context.label = @params["context_label"].presence || context.label
      context.save!
      context
    end

    def reject(reason)
      @error = reason
      false
    end
  end
end
