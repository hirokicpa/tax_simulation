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
     get 'succession_gift', to: 'succession_gift#index'
     get 'first_second_succession', to: 'first_second_succession#index'

     
     get 'succession_gift/result_tax'
     get 'incorporation/result_tax'
     get 'first_second_succession/result_tax'
   end
    
end

