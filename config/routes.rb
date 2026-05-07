Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboards#show"

  resources :datasets, only: [:index, :new, :create, :show, :destroy] do
    member do
      get :preview
      get :export
      post :assign_department
    end
  end

  resources :departments, only: [:index, :show], param: :slug do
    member do
      post :refresh
      post :regenerate_summary
      get :export_pdf
      get :export_csv
      get :export_full_pdf
    end
  end

  resources :import_jobs, only: [:index, :show]

  get "comparison" => "dashboards#comparison", as: :comparison
end
