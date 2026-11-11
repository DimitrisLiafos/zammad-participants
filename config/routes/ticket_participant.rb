Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    resources :tickets, only: [] do
      resources :participants, controller: 'ticket_participants', only: %i[index create destroy]
    end
  end
end
