require "rails_helper"

# Stage 4, step 2. Write app/services/lti1p1/launch_records.rb until this passes.
#
# A verified launch tells us who the person is and which course they are in. This class turns
# that into two rows, so a poll can point at them later:
#   LtiUser    (one per person, per consumer)  <- params["user_id"]
#   LtiContext (one per course, per consumer)  <- params["context_id"]
# It finds the row if it exists, or creates it. It also keeps the display fields fresh.
#
# Interface these specs expect:
#   Lti1p1::LaunchRecords.new(consumer:, params:)
#     #call    -> true/false. On true, #user and #context are saved rows.
#     #user    -> LtiUser
#     #context -> LtiContext
#     #error   -> nil, :missing_user_id, or :missing_context_id
#
# Why the consumer scopes both rows: two Canvas installs can send the same user_id for two
# different people. The unique indexes on the tables already say this.
#
# Do not call this before the signature and replay checks pass. It trusts `params`.
RSpec.describe Lti1p1::LaunchRecords do
  let(:consumer) { create(:lti_consumer) }
  let(:params) do
    {
      "user_id" => "abc123",
      "lis_person_name_full" => "Test Teacher 1",
      "context_id" => "course-1",
      "context_title" => "Test Course 1",
      "context_label" => "Test 1"
    }
  end

  def records_for(consumer: self.consumer, params: self.params)
    described_class.new(consumer: consumer, params: params)
  end

  describe "#call" do
    it "returns true and no error" do
      records = records_for

      expect(records.call).to be(true)
      expect(records.error).to be_nil
    end

    it "creates the user for the consumer" do
      records = records_for
      records.call

      expect(records.user).to be_persisted
      expect(records.user).to have_attributes(
        lti_consumer: consumer, lti1p1_user_id: "abc123", name: "Test Teacher 1", lti1p3_sub: nil
      )
    end

    it "creates the context for the consumer" do
      records = records_for
      records.call

      expect(records.context).to be_persisted
      expect(records.context).to have_attributes(
        lti_consumer: consumer, context_id: "course-1", title: "Test Course 1", label: "Test 1"
      )
    end

    context "when the same person launches again" do
      it "reuses the same user and context rows" do
        first = records_for
        first.call

        second = records_for
        expect { second.call }.not_to change { [LtiUser.count, LtiContext.count] }
        expect(second.user).to eq(first.user)
        expect(second.context).to eq(first.context)
      end

      it "updates the name when it changed" do
        records_for.call

        records = records_for(params: params.merge("lis_person_name_full" => "Renamed Teacher"))
        records.call

        expect(records.user.reload.name).to eq("Renamed Teacher")
      end

      it "updates the course title and label when they changed" do
        records_for.call

        records = records_for(params: params.merge("context_title" => "New Title", "context_label" => "NT"))
        records.call

        expect(records.context.reload).to have_attributes(title: "New Title", label: "NT")
      end

      it "keeps the old name when the new launch sends no name" do
        records_for.call

        records = records_for(params: params.merge("lis_person_name_full" => ""))
        records.call

        expect(records.user.reload.name).to eq("Test Teacher 1")
      end
    end

    context "with the same ids from a different consumer" do
      it "makes a separate user and a separate context" do
        mine = records_for
        mine.call

        theirs = records_for(consumer: create(:lti_consumer))
        theirs.call

        expect(theirs.user).not_to eq(mine.user)
        expect(theirs.context).not_to eq(mine.context)
      end
    end

    context "when Canvas sends no name" do
      it "saves the user with no name" do
        records = records_for(params: params.except("lis_person_name_full"))

        expect(records.call).to be(true)
        expect(records.user.name).to be_nil
      end
    end

    context "with missing ids" do
      [
        ["no user_id", { "user_id" => nil }, :missing_user_id],
        ["an empty user_id", { "user_id" => "" }, :missing_user_id],
        ["no context_id", { "context_id" => nil }, :missing_context_id],
        ["an empty context_id", { "context_id" => "" }, :missing_context_id]
      ].each do |description, overrides, error|
        it "returns false with #{description}" do
          records = records_for(params: params.merge(overrides))

          expect(records.call).to be(false)
          expect(records.error).to eq(error)
        end
      end

      it "saves nothing when the context id is missing, not even the user" do
        records = records_for(params: params.merge("context_id" => ""))

        expect { records.call }.not_to change { [LtiUser.count, LtiContext.count] }
      end
    end
  end
end
