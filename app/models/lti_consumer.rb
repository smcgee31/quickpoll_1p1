class LtiConsumer < ApplicationRecord
  has_many :lti_users, dependent: :destroy
  has_many :lti_contexts, dependent: :destroy
  has_many :used_nonces, dependent: :destroy

  validates :name, :consumer_key, :shared_secret, presence: true
  validates :consumer_key, uniqueness: true
end
