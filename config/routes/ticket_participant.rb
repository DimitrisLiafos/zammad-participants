Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    resources :tickets, only: [] do
      resources :participants, controller: 'ticket_participants', only: %i[index create destroy]
    end

    get  'ticket_participants/unsubscribe/:token', to: 'ticket_participant_unsubscribes#show'
    post 'ticket_participants/unsubscribe/:token', to: 'ticket_participant_unsubscribes#create'
  end
end
