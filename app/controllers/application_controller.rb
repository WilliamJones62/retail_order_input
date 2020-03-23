class ApplicationController < ActionController::Base
  # including the following line prevents api calls from working, so it is commented out
  # before_action :authenticate_user!
  # def after_sign_in_path_for(resource)
  #   retail_orders_customer_path
  # end
  protect_from_forgery with: :exception
end
