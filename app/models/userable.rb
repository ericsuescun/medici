module Userable
  extend ActiveSupport::Concern

  included do
    has_one :user, as: :userable, touch: true, dependent: :destroy

    accepts_nested_attributes_for :user
  end
end
