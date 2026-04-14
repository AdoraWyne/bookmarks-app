class TagsController < ApplicationController
  def index
    tags = Tag.all
    render json: tags
  end

  def create
    tag = Tag.new(params.require(:tag).permit(:name))

    if tag.save
      render json: tag, status: :created
    else
      render json: { errors: tag.errors }, status: :unprocessable_entity
    end
  end
end
