class UsedNonce < ApplicationRecord
  belongs_to :lti_consumer

  validates :nonce, :oauth_timestamp, presence: true
  validates :nonce, uniqueness: { scope: :lti_consumer_id }
end
