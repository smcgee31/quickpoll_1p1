FactoryBot.define do
  factory :lti_consumer do
    sequence(:name) { |n| "Consumer #{n}" }
    sequence(:consumer_key) { |n| "key#{n}" }
    shared_secret { "secret" }
  end

  factory :lti_user do
    lti_consumer
    sequence(:lti1p1_user_id) { |n| "user-#{n}" }
    name { "Test User" }
  end

  factory :lti_context do
    lti_consumer
    sequence(:context_id) { |n| "context-#{n}" }
    title { "Test Course" }
  end

  factory :poll do
    lti_context
    creator { association :lti_user, lti_consumer: lti_context.lti_consumer }
    question { "Favorite color?" }
    options { %w[Red Blue Green] }
  end

  factory :vote do
    poll
    lti_user { association :lti_user, lti_consumer: poll.lti_context.lti_consumer }
    option_index { 0 }
  end

  factory :used_nonce do
    lti_consumer
    sequence(:nonce) { |n| "nonce-#{n}" }
    oauth_timestamp { Time.now.to_i }
  end
end
