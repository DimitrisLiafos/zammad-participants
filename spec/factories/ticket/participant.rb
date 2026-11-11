FactoryBot.define do
  factory :'ticket/participant', aliases: %i[ticket_participant] do
    ticket factory: :ticket, strategy: :create
    user factory: :customer, strategy: :create # roles must be persisted for the permission check
    source        { 'agent' }
    created_by_id { 1 }
    updated_by_id { 1 }
  end
end
