# == Schema Information
#
# Table name: campaigns
#
#  id                          :bigint           not null, primary key
#  call_to_action              :string
#  description                 :text
#  facebook_page_access_token  :text
#  instagram_access_token      :text
#  status                      :string           default("draft"), not null
#  target_facebook             :boolean          default(FALSE), not null
#  target_instagram            :boolean          default(FALSE), not null
#  target_twitter              :boolean          default(FALSE), not null
#  title                       :string           not null
#  twitter_access_token        :text
#  twitter_access_token_secret :text
#  twitter_api_key             :text
#  twitter_api_secret          :text
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  facebook_page_id            :text
#  instagram_user_id           :text
#  study_id                    :bigint           not null
#
# Indexes
#
#  index_campaigns_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
FactoryBot.define do
  factory :campaign do
    association :study, factory: :study
    sequence(:title) { |n| "Campaign #{n}" }
    description { "Promote this study across social media." }
    call_to_action { "Join today" }
    status { "draft" }

    trait :ready do
      status { "ready" }
    end

    trait :multi_channel do
      target_instagram { true }
      target_facebook { true }
      target_twitter { true }
    end
  end
end
