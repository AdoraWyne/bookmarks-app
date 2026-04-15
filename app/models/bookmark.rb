class Bookmark < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\//, message: "must start with http:// or https://" }, uniqueness: true

  has_many :bookmark_tags
  has_many :tags, through: :bookmark_tags

  scope :search, ->(query) { where("title LIKE ?", "%#{query}%") }
  scope :tagged, ->(name) { joins(:tags).where(tags: { name: name }) }

  before_save :set_default_description
  after_save :log_save

  private

  def log_save
    Rails.logger.info "Bookmark saved: #{title} (#{url})"
  end

  def set_default_description
    if description.blank?
      self.description = "Bookmark for #{title}"
    end
  end
end
