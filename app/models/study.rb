class Study < ApplicationRecord
  belongs_to :sponsors

  has_many :articles
  has_many :results
  has_many :trial_cities
  has_many :results
  has_many :contacts

end
