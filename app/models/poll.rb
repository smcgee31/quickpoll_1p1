class Poll < ApplicationRecord
  belongs_to :lti_context
  belongs_to :creator, class_name: "LtiUser"
  has_many :votes, dependent: :destroy

  validates :question, presence: true
  validate :options_has_at_least_two

  private

  def options_has_at_least_two
    return if options.is_a?(Array) && options.reject(&:blank?).size >= 2

    errors.add(:options, "must have at least two choices")
  end
end
