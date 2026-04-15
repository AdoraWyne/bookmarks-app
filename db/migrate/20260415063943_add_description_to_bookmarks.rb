class AddDescriptionToBookmarks < ActiveRecord::Migration[8.1]
  def change
    add_column :bookmarks, :description, :string
  end
end
