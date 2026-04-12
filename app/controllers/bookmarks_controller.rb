class BookmarksController < ApplicationController
  def index
    render json: { message: "Welcome to Bookmarks App" }
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
