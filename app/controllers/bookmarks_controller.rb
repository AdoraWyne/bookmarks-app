class BookmarksController < ApplicationController
  def index
    render json: { message: "Welcome to Bookmarks App" }
  end
end
