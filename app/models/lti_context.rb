class LtiContext < ApplicationRecord
  belongs_to :lti_consumer
  has_many :polls, dependent: :destroy

  validates :context_id, presence: true, uniqueness: { scope: :lti_consumer_id }
end
