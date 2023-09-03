Rails.application.routes.draw do
  get 'answers/create'
  devise_for :users
  root 'top#index'
 
    resources :board, only:[:index,:show] do
      resources :questions do
        resources :answers
      end
    end
   
    namespace :simulations do
     get 'incorporation' ,to: 'incorporation#index'
     get 'incorporation/result_tax'
     
     get 'succession_gift', to: 'succession_gift#index'
     get 'succession_gift/result_tax'
   end
    
end

