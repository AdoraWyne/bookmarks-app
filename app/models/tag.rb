class Tag < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :bookmark_tags
  has_many :bookmarks, through: :bookmark_tags
end
