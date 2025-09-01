class SponsorRep < ApplicationRecord
  include Userable

  belongs_to :sponsor, optional: true
end
