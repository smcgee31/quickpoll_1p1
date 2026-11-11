require "rails_helper"

# Stage 4, step 4. Write app/services/lti1p1/roles.rb until this passes.
#
# A launch says what the person is in this course. The tool needs one answer to one question:
# "may this person create polls?" (an instructor) or "may this person only vote?" (a learner).
#
# Canvas sends roles in TWO fields and in TWO shapes. That is the whole difficulty:
#   roles      "Instructor"                      <- short names, for an enrolled teacher
#              "urn:lti:instrole:ims/lis/Administrator,urn:lti:sysrole:ims/lis/SysAdmin"
#                                                <- URNs, for an account admin with no enrollment
#   ext_roles  "urn:lti:instrole:ims/lis/Instructor,urn:lti:role:ims/lis/Instructor,..."
#                                                <- always URNs, and the only place an unenrolled
#                                                   admin shows up as Instructor
# So read BOTH fields, split on commas, and keep only the text after the last "/".
#
# Interface these specs expect:
#   Lti1p1::Roles.new(params)
#     #names           -> Array of short names, no duplicates, the roles field first and then ext_roles,
#                         for example ["Instructor", "User"]
#     #instructor?     -> true when "Instructor" is one of the names
#     #learner?        -> true when "Learner" is one of the names
#     #administrator?  -> true when "Administrator" is one of the names
#     #teaching_assistant? -> true when "TeachingAssistant" is one of the names
#     #can_create_polls?   -> true for an instructor or a teaching assistant
#
# Compare whole names. A role called "InstructorAssistant" is not an Instructor.
# Decision made here, on purpose: a TA CAN create polls. A real Canvas TA launch also carries the
# Instructor instrole in ext_roles, so instructor? is true for a real TA anyway. The poll pages ask
# can_create_polls?, never instructor?. To change who may create polls, change can_create_polls? only.
RSpec.describe Lti1p1::Roles do
  def launch_params(name)
    JSON.parse(Rails.root.join("spec/fixtures/lti1p1/#{name}_launch.json").read)["params"]
  end

  def roles_for(roles: nil, ext_roles: nil)
    described_class.new({ "roles" => roles, "ext_roles" => ext_roles }.compact)
  end

  describe "a real teacher launch (fixture)" do
    subject(:roles) { described_class.new(launch_params("teacher")) }

    it "is an instructor and not a learner" do
      expect(roles).to be_instructor
      expect(roles).not_to be_learner
    end

    it "lists each name once" do
      expect(roles.names).to eq(%w[Instructor User])
    end
  end

  describe "a real student launch (fixture)" do
    subject(:roles) { described_class.new(launch_params("student")) }

    it "is a learner and not an instructor" do
      expect(roles).to be_learner
      expect(roles).not_to be_instructor
    end

    it "lists each name once" do
      expect(roles.names).to eq(%w[Learner Student User])
    end
  end

  describe "an account admin who is not enrolled in the course" do
    let(:admin_roles) { "urn:lti:instrole:ims/lis/Administrator,urn:lti:sysrole:ims/lis/SysAdmin" }

    it "is an instructor when only ext_roles says so" do
      roles = roles_for(
        roles: admin_roles,
        ext_roles: "#{admin_roles},urn:lti:role:ims/lis/Instructor"
      )

      expect(roles).to be_instructor
      expect(roles).to be_administrator
    end

    it "is not an instructor when ext_roles does not say so" do
      roles = roles_for(roles: admin_roles, ext_roles: admin_roles)

      expect(roles).to be_administrator
      expect(roles).not_to be_instructor
    end
  end

  describe "which fields it reads" do
    it "reads roles when ext_roles is missing" do
      expect(roles_for(roles: "Learner")).to be_learner
    end

    it "reads ext_roles when roles is missing" do
      expect(roles_for(ext_roles: "urn:lti:role:ims/lis/Instructor")).to be_instructor
    end

    it "reads ext_roles when roles is empty" do
      expect(roles_for(roles: "", ext_roles: "urn:lti:role:ims/lis/Learner")).to be_learner
    end
  end

  describe "messy input" do
    it "trims spaces around each role" do
      expect(roles_for(roles: " Instructor , Learner ").names).to eq(%w[Instructor Learner])
    end

    it "counts the same role once, whether it arrives short or as a URN" do
      roles = roles_for(roles: "Instructor", ext_roles: "urn:lti:role:ims/lis/Instructor")

      expect(roles.names).to eq(["Instructor"])
    end

    it "ignores empty entries" do
      expect(roles_for(roles: "Instructor,,").names).to eq(["Instructor"])
    end

    it "has no roles when both fields are missing or empty" do
      roles = roles_for(roles: "", ext_roles: "")

      expect(roles.names).to eq([])
      expect(roles).not_to be_instructor
      expect(roles).not_to be_learner
      expect(roles).not_to be_administrator
    end

    it "has no roles when the params hold no role fields at all" do
      expect(described_class.new({}).names).to eq([])
    end
  end

  describe "matching names" do
    it "does not match part of a longer name" do
      roles = roles_for(roles: "urn:lti:role:ims/lis/InstructorAssistant")

      expect(roles).not_to be_instructor
      expect(roles.names).to eq(["InstructorAssistant"])
    end

    it "does not treat a TeachingAssistant name alone as an instructor" do
      roles = roles_for(roles: "urn:lti:role:ims/lis/TeachingAssistant")

      expect(roles).not_to be_instructor
      expect(roles).to be_teaching_assistant
      expect(roles.names).to eq(["TeachingAssistant"])
    end
  end

  # Captured from a real Canvas launch as an enrolled TA (2026-11-11). Canvas lists the TA as an
  # Instructor too, in ext_roles (the instrole URN). So instructor? is true for a real TA.
  describe "a real TA launch (captured from Canvas)" do
    subject(:roles) do
      roles_for(
        roles: "urn:lti:role:ims/lis/TeachingAssistant",
        ext_roles: "urn:lti:instrole:ims/lis/Instructor,urn:lti:role:ims/lis/TeachingAssistant,urn:lti:sysrole:ims/lis/User"
      )
    end

    it "is a teaching assistant and, because Canvas says so, an instructor" do
      expect(roles).to be_teaching_assistant
      expect(roles).to be_instructor
      expect(roles).not_to be_learner
    end

    it "lists each name once, the roles field first" do
      expect(roles.names).to eq(%w[TeachingAssistant Instructor User])
    end

    it "can create polls" do
      expect(roles).to be_can_create_polls
    end
  end

  describe "#can_create_polls?" do
    it "is true for an instructor" do
      expect(roles_for(roles: "Instructor")).to be_can_create_polls
    end

    it "is true for a teaching assistant" do
      expect(roles_for(roles: "urn:lti:role:ims/lis/TeachingAssistant")).to be_can_create_polls
    end

    it "is true for an unenrolled admin when ext_roles says Instructor" do
      roles = roles_for(
        roles: "urn:lti:instrole:ims/lis/Administrator",
        ext_roles: "urn:lti:instrole:ims/lis/Administrator,urn:lti:role:ims/lis/Instructor"
      )

      expect(roles).to be_can_create_polls
    end

    it "is false for a learner" do
      expect(roles_for(roles: "Learner")).not_to be_can_create_polls
    end

    it "is false for an unenrolled admin with no teaching role" do
      expect(roles_for(roles: "urn:lti:instrole:ims/lis/Administrator")).not_to be_can_create_polls
    end

    it "is false when there are no roles" do
      expect(described_class.new({})).not_to be_can_create_polls
    end
  end
end
