ActiveAdmin.register User do
  permit_params :email, :nickname, :admin, :avatar_url, :motto, :school, :gradyear, :name

  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end
  end
  preserve_default_filters!
  filter :id
  # See permitted parameters documentation:
  # https://github.com/gregbell/active_admin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # permit_params :list, :of, :attributes, :on, :model
  #
  # or
  #
  # permit_params do
  #  permitted = [:permitted, :attributes]
  #  permitted << :other if resource.something?
  #  permitted
  # end

end
