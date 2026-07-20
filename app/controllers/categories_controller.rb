class CategoriesController < ApplicationController
  before_action :require_authentication
  before_action :set_category, only: [ :update, :destroy ]

  def index
    render inertia: "categories/index", props: {
      categories: categories_with_invoice_counts.map { |category| serialize_category(category) }
    }
  end

  def create
    category = current_user.categories.new(category_params)

    if category.save
      redirect_to categories_path, notice: "Category created"
    else
      redirect_to categories_path, alert: category.errors.full_messages.to_sentence
    end
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Category updated"
    else
      redirect_to categories_path, alert: @category.errors.full_messages.to_sentence
    end
  end

  def destroy
    @category.destroy!
    redirect_to categories_path, notice: "Category deleted"
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name)
  end

  def categories_with_invoice_counts
    current_user.categories
      .left_joins(:invoices)
      .select("categories.*, COUNT(invoices.id) AS invoices_count")
      .group("categories.id")
      .order(Arel.sql("LOWER(categories.name)"))
  end

  def serialize_category(category)
    {
      id: category.id,
      name: category.name,
      invoices_count: category[:invoices_count].to_i
    }
  end
end
