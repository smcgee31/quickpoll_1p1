require "rails_helper"

# Stage 3, step 4. Write app/services/lti1p1/replay_guard.rb until this passes.
#
# A valid signature is not enough. An attacker who copies a real launch POST can send it again,
# and the signature stays valid. Two checks stop that:
#   1. oauth_timestamp must be recent. Old launches are rejected.
#   2. oauth_nonce must be new for that consumer. A repeated nonce is rejected.
#
# Interface these specs expect:
#   Lti1p1::ReplayGuard.new(consumer:, params:, now: Time.current)
#     #accept? -> true/false. On true, it saves the nonce in used_nonces.
#     #error   -> nil, :invalid, :stale_timestamp, or :replayed_nonce
#
# `params` is the launch params hash. The guard reads oauth_timestamp and oauth_nonce from it.
# `now` is a parameter so the specs control the clock. Do not stub Time.
#
# Call order in the controller (Stage 4): check the signature first, then call accept?.
# If you save the nonce before the signature check, anyone can fill the table with fake nonces.
RSpec.describe Lti1p1::ReplayGuard do
  let(:now) { Time.zone.at(1_800_000_000) }
  let(:consumer) { create(:lti_consumer) }
  let(:params) { { "oauth_timestamp" => now.to_i.to_s, "oauth_nonce" => "nonce-1" } }

  def guard_for(consumer: self.consumer, params: self.params)
    described_class.new(consumer: consumer, params: params, now: now)
  end

  def params_aged(seconds)
    params.merge("oauth_timestamp" => (now.to_i - seconds).to_s)
  end

  describe "#accept?" do
    it "accepts a fresh timestamp with a new nonce" do
      guard = guard_for

      expect(guard.accept?).to be(true)
      expect(guard.error).to be_nil
    end

    it "saves the nonce for the consumer" do
      expect { guard_for.accept? }.to change { consumer.used_nonces.count }.by(1)

      saved = consumer.used_nonces.last
      expect(saved.nonce).to eq("nonce-1")
      expect(saved.oauth_timestamp).to eq(now.to_i)
    end

    context "with the timestamp window (5 minutes)" do
      it "accepts a launch 299 seconds old" do
        expect(guard_for(params: params_aged(299)).accept?).to be(true)
      end

      it "rejects a launch 301 seconds old" do
        guard = guard_for(params: params_aged(301))

        expect(guard.accept?).to be(false)
        expect(guard.error).to eq(:stale_timestamp)
      end

      it "accepts a timestamp 299 seconds in the future (clock skew)" do
        expect(guard_for(params: params_aged(-299)).accept?).to be(true)
      end

      it "rejects a timestamp 301 seconds in the future" do
        guard = guard_for(params: params_aged(-301))

        expect(guard.accept?).to be(false)
        expect(guard.error).to eq(:stale_timestamp)
      end

      it "does not save the nonce when the timestamp is stale" do
        expect { guard_for(params: params_aged(301)).accept? }.not_to change(UsedNonce, :count)
      end
    end

    context "with a repeated nonce" do
      it "rejects the second launch with the same nonce" do
        guard_for.accept?
        second = guard_for

        expect(second.accept?).to be(false)
        expect(second.error).to eq(:replayed_nonce)
      end

      it "saves the nonce only once" do
        guard_for.accept?

        expect { guard_for.accept? }.not_to change(UsedNonce, :count)
      end

      it "accepts the same nonce from a different consumer" do
        guard_for.accept?
        other_consumer = create(:lti_consumer)

        expect(guard_for(consumer: other_consumer).accept?).to be(true)
      end

      it "accepts a different nonce from the same consumer" do
        guard_for.accept?

        expect(guard_for(params: params.merge("oauth_nonce" => "nonce-2")).accept?).to be(true)
      end
    end

    context "with missing or broken params" do
      [
        ["no timestamp", { "oauth_timestamp" => nil }],
        ["an empty timestamp", { "oauth_timestamp" => "" }],
        ["a timestamp that is not a number", { "oauth_timestamp" => "yesterday" }],
        ["no nonce", { "oauth_nonce" => nil }],
        ["an empty nonce", { "oauth_nonce" => "" }]
      ].each do |description, overrides|
        it "rejects a launch with #{description}" do
          guard = guard_for(params: params.merge(overrides))

          expect(guard.accept?).to be(false)
          expect(guard.error).to eq(:invalid)
        end
      end

      it "does not save anything for a broken launch" do
        expect { guard_for(params: params.merge("oauth_nonce" => "")).accept? }.not_to change(UsedNonce, :count)
      end
    end
  end
end
