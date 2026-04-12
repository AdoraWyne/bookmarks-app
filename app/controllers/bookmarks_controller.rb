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
    bookmark = Bookmark.new(params.require(:bookmark).permit(:title, :url))

    if bookmark.save
      render json: bookmark, status: :created
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def update
    bookmark = Bookmark.find(params[:id])

    if bookmark.update(params.require(:bookmark).permit(:title, :url))
      render json: bookmark
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    render json: { message: "Delete bookmarks #{params[:id]}" }
  end
end
