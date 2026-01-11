Rails.application.routes.draw do
  # get 'answers/create'
  devise_for :users
  root 'top#index'
 
    resources :board, only:[:index,:show] do
      resources :questions do
        resources :answers
      end
    end
   
    namespace :simulations do
     get 'succession_gift', to: 'succession_gift#index'
     get 'incorporation' ,to: 'incorporation#index'
     get 'first_second_succession', to: 'first_second_succession#index'
    #  get 'business_succession', to: 'business_succession_tax#index', as: :business_succession
     get  'business_succession', to: 'business_succession_tax#index', as: :business_succession
     get "income_tax", to: "income_tax#index", as: :income_tax

     
     get 'succession_gift/result_tax', to: 'succession_gift#result_tax'
     get 'incorporation/result_tax', to: 'incorporation#result_tax'
     get 'first_second_succession/result_tax', to: 'first_second_succession#result_tax'
     get 'business_succession_tax/result_heir_rate', to: 'business_succession_tax#result_heir_rate'
    # API：納税猶予額・後継者相続税額の最終結果
     get 'business_succession_tax/result_business_succession', to: 'business_succession_tax#result_business_succession'
     get 'income_tax/result_tax', to: 'income_tax#result_tax'
     
   end
    
end

