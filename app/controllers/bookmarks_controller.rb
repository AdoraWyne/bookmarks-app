class BookmarksController < ApplicationController
  def index
    bookmarks = Bookmark.all
    render json: bookmarks
  end

  def show
    bookmark = Bookmark.find(params[:id])
    render json: bookmark
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
