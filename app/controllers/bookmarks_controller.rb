class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [ :show, :update, :destroy ]
  def index
    bookmarks = Bookmark.all
    render json: bookmarks, include: :tags
  end

  def show
    if @bookmark
      render json: @bookmark, include: :tags
    end
  end

  def create
    bookmark = Bookmark.new(bookmark_params)

    if bookmark.save
      render json: bookmark, status: :created
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @bookmark.update(bookmark_params)
      render json: @bookmark
    else
      render json: { errors: bookmark.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @bookmark.destroy
    head :no_content
  end

  private

  def set_bookmark
    @bookmark = Bookmark.find(params[:id])
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url)
  end

end
