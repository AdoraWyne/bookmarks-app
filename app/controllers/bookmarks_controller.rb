class BookmarksController < ApplicationController
  def index
    bookmarks = Bookmark.all
    render json: bookmarks
  end

  def show
    render json: { message: "Showing bookmarks #{params[:id]}" }
  end

  def create
    render json: { message: "Create a bookmark" }
  end

  def update
    render json: { message: "Update bookmarks #{params[:id]}" }
  end

  def destroy
    render json: { message: "Delete bookmarks #{params[:id]}" }
  end
end
