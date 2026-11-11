module TicketParticipants::TicketSearchExtension
  def search_query_extension(params)
    query = super
    return query if !params[:current_user].permissions?('ticket.customer')

    query.dig(:bool, :must, 0, :bool, :should)&.push(
      { 'term' => { 'participant_ids' => params[:current_user].id } }
    )
    query
  end
end
