require "rails_helper"

RSpec.describe "LTI 1.1 models" do
  describe LtiConsumer do
    it "needs a name, key, and secret" do
      consumer = LtiConsumer.new
      expect(consumer).not_to be_valid
      expect(consumer.errors.attribute_names).to include(:name, :consumer_key, :shared_secret)
    end

    it "rejects a duplicate consumer key" do
      create(:lti_consumer, consumer_key: "dup")
      expect(build(:lti_consumer, consumer_key: "dup")).not_to be_valid
    end
  end

  describe LtiUser do
    it "allows the same lti1p1_user_id on two consumers" do
      create(:lti_user, lti1p1_user_id: "abc")
      expect(build(:lti_user, lti1p1_user_id: "abc")).to be_valid
    end

    it "rejects the same lti1p1_user_id on one consumer" do
      user = create(:lti_user, lti1p1_user_id: "abc")
      expect(build(:lti_user, lti_consumer: user.lti_consumer, lti1p1_user_id: "abc")).not_to be_valid
    end

    it "allows many users with a nil lti1p3_sub" do
      consumer = create(:lti_consumer)
      create(:lti_user, lti_consumer: consumer)
      expect(build(:lti_user, lti_consumer: consumer)).to be_valid
    end
  end

  describe LtiContext do
    it "rejects the same context_id on one consumer" do
      context = create(:lti_context, context_id: "c1")
      expect(build(:lti_context, lti_consumer: context.lti_consumer, context_id: "c1")).not_to be_valid
    end
  end

  describe Poll do
    it "needs a question" do
      expect(build(:poll, question: "")).not_to be_valid
    end

    it "needs at least two non-blank options" do
      expect(build(:poll, options: ["Only one", ""])).not_to be_valid
      expect(build(:poll, options: %w[A B])).to be_valid
    end
  end

  describe Vote do
    it "allows one vote per user per poll" do
      vote = create(:vote)
      again = build(:vote, poll: vote.poll, lti_user: vote.lti_user)
      expect(again).not_to be_valid
    end

    it "rejects an option_index outside the poll options" do
      poll = create(:poll, options: %w[A B])
      expect(build(:vote, poll: poll, option_index: 2)).not_to be_valid
      expect(build(:vote, poll: poll, option_index: 1)).to be_valid
    end
  end

  describe UsedNonce do
    it "rejects a repeated nonce for one consumer" do
      nonce = create(:used_nonce, nonce: "n1")
      expect(build(:used_nonce, lti_consumer: nonce.lti_consumer, nonce: "n1")).not_to be_valid
    end
  end
end
