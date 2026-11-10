class Vote < ApplicationRecord
  belongs_to :poll
  belongs_to :lti_user

  validates :option_index, presence: true
  validates :lti_user_id, uniqueness: { scope: :poll_id }
  validate :option_index_in_range

  private

  def option_index_in_range
    return if option_index.blank? || poll.blank?
    return if option_index.between?(0, poll.options.size - 1)

    errors.add(:option_index, "is not a choice on this poll")
  end
end
