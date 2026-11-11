module Lti1p1
  class Roles
    def initialize(params)
      @params = params
    end

    def names
      @names ||= [ @params["roles"], @params["ext_roles"] ]
        .flat_map { |field| field.to_s.split(",") }
        .map { |role| role.strip.split("/").last.to_s }
        .reject(&:empty?).uniq
    end

    def instructor? = names.include?("Instructor")
    def learner? = names.include?("Learner")
    def administrator? = names.include?("Administrator")
    def teaching_assistant? = names.include?("TeachingAssistant")
    def can_create_polls? = instructor? || teaching_assistant?
  end
end
