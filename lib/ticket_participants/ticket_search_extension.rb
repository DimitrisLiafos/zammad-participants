module TicketParticipants::TicketSearchExtension
  def search_query_extension(params)
    query = super
    return query if !params[:current_user].permissions?('ticket.customer')

    group_ids = Group.where(participants_enabled: true).pluck(:id)
    return query if group_ids.blank?

    # The groups are part of the query instead of the index, so switching a
    #   group on or off needs no reindexing.
    query.dig(:bool, :must, 0, :bool, :should)&.push(
      {
        bool: {
          must: [
            { 'term'  => { 'participant_ids' => params[:current_user].id } },
            { 'terms' => { 'group_id' => group_ids } },
          ],
        },
      }
    )
    query
  end
end
