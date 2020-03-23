Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'retail_orders/api'
      resources :retail_orders
    end
  end
  get 'retail_orders/error'
  get 'retail_orders/customer'
  get 'retail_orders/selected'
  get 'retail_orders/shipto'
  get 'retail_orders/chosen'
  resources :retail_orders do
    resources :retail_order_parts, except: [:index, :show]
  end
  devise_for :users
  devise_scope :user do
    get '/signout', to: 'devise/sessions#destroy', as: :signout
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root 'retail_orders#customer'
end
