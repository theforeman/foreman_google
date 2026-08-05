Rails.application.routes.draw do
  constraints(id: %r{[^/]+}) do
    resources :compute_resources, only: [] do
      member do
        get 'available_subnets', to: 'compute_resources#available_subnets'
      end
    end
  end
end
