Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "simulations#index", as: :authenticated_root
  end

  unauthenticated do
    root "pages#home"
  end

  resources :simulations, param: :token, only: [:index, :new, :create, :show] do
    member do
      get  :compare
      post :compare
      post :upload_bulletin
    end
    collection do
      get  :tib_preview
      post :extract_bulletin
    end
  end

  namespace :admin do
    resources :simulations, only: %i[index show]
  end

  get  "carrieres/promotion-2e-grade", to: "carrieres#new_promotion",         as: :new_carriere_promotion
  get  "carrieres/ide-vers-iade",      to: "carrieres#new_reclassement_ide",  as: :new_carriere_reclassement_ide
  get  "carrieres/as-vers-ide",        to: "carrieres#new_reclassement_as",   as: :new_carriere_reclassement_as
  post "carrieres",                    to: "carrieres#create"
  resources :carrieres, param: :token, only: %i[index show]
end
