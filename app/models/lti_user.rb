class LtiUser < ApplicationRecord
  belongs_to :lti_consumer
  has_many :votes, dependent: :destroy

  validates :lti1p1_user_id, presence: true, uniqueness: { scope: :lti_consumer_id }
  validates :lti1p3_sub, uniqueness: { scope: :lti_consumer_id }, allow_nil: true
end
