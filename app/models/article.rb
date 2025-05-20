# == Schema Information
#
# Table name: articles
#
#  id          :bigint           not null, primary key
#  description :string           default("")
#  title       :string           default("")
#  url         :string           default("")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  study_id    :bigint           not null
#
# Indexes
#
#  index_articles_on_study_id  (study_id)
#
# Foreign Keys
#
#  fk_rails_...  (study_id => studies.id)
#
class Article < ApplicationRecord
  belongs_to :study
end
