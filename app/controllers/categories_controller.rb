# Admin UI for the study categories (therapeutic areas). Access is governed by
# the Role permission matrix like every catalog resource: the seeder grants
# Category only to admins, so other roles are denied (and never see the navbar
# entry — it's gated by policy(Category).index?).
class CategoriesController < SecureApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # GET /categories
  def index
    @categories = Category.left_joins(:studies).select("categories.*, COUNT(studies.id) AS studies_count")
                          .group("categories.id").order(:name)
                          .paginate(page: params[:page], per_page: RECORDS_PER_PAGE)
  end

  # GET /categories/1
  def show
  end

  # GET /categories/new
  def new
    @category = Category.new
  end

  # GET /categories/1/edit
  def edit
  end

  # POST /categories
  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_url, notice: t("categories.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /categories/1
  def update
    if @category.update(category_params)
      redirect_to categories_url, notice: t("categories.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /categories/1
  def destroy
    # Studies keep existing — only the join rows go; affected studies simply
    # stop carrying this therapeutic area.
    @category.destroy!
    redirect_to categories_url, notice: t("categories.destroyed")
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
