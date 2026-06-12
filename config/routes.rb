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
    end
    collection do
      get :tib_preview
    end
  end
end
