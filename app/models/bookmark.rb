class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }, uniqueness: true

  has_many :bookmark_tags
  has_many :tags, through: :bookmark_tags

  scope :search, ->(query) { where("title LIKE ?", "%#{query}%") }
  scope :tagged, ->(name) { joins(:tags).where(tags: { name: name }) }

  before_save :set_default_description
  private

  def log_save
    Rails.logger.info "Bookmark saved: #{title} (#{url})"
  end
end
