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
   end
    
end

