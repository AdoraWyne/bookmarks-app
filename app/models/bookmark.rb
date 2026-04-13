class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }, uniqueness: true
end
