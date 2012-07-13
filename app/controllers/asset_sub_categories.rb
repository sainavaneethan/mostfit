class AssetSubCategories < Application
  # provides :xml, :yaml, :js

  def index
    @asset_sub_categories = AssetSubCategory.all
    display @asset_sub_categories
  end

  #auto-generated
  #def show(id)
  #  @asset_sub_category = AssetSubCategory.get(id)
  #  raise NotFound unless @asset_sub_category
  #  display @asset_sub_category
  #end

  def show
    @asset_sub_category = AssetSubCategory.get params[:id]
    @asset_types =  @asset_sub_category.asset_types
    display @asset_sub_category
  end

  def new
    only_provides :html
    @asset_sub_category = AssetSubCategory.new
    display @asset_sub_category
  end

  def edit(id)
    only_provides :html
    @asset_sub_category = AssetSubCategory.get(id)
    raise NotFound unless @asset_sub_category
    display @asset_sub_category
  end

  #auto-generated
  #def create(asset_sub_category)
  #  @asset_sub_category = AssetSubCategory.new(asset_sub_category)
  #  if @asset_sub_category.save
  #    redirect resource(@asset_sub_category), :message => {:notice => "AssetSubCategory was successfully created"}
  #  else
  #    message[:error] = "AssetSubCategory failed to be created"
  #    render :new
  #  end
  #end

  def create
    @asset_category = AssetCategory.get(params[:asset_category_id])
    @asset_sub_category = @asset_category.asset_sub_categories.new(:name => params[:name])
    if @asset_sub_category.save
      redirect resource(@asset_category), :message => {:notice => "Save Successfully"}
    else
      redirect resource(@asset_category), :message => {:error => error_messages(@asset_sub_category)}
    end
  end

  def update(id, asset_sub_category)
    @asset_sub_category = AssetSubCategory.get(id)
    raise NotFound unless @asset_sub_category
    if @asset_sub_category.update(asset_sub_category)
       redirect resource(@asset_sub_category)
    else
      display @asset_sub_category, :edit
    end
  end

  def destroy(id)
    @asset_sub_category = AssetSubCategory.get(id)
    raise NotFound unless @asset_sub_category
    if @asset_sub_category.destroy
      redirect resource(:asset_sub_categories)
    else
      raise InternalServerError
    end
  end


end # AssetSubCategories
