module TicketParticipants::TicketPolicyScopeExtension
  def resolve
    resolved = super
    return resolved if !user.permissions?('ticket.customer')

    resolved.or(
      scope.where(
        id:       Ticket::Participant.where(user_id: user.id).select(:ticket_id),
        group_id: Group.where(participants_enabled: true).select(:id),
      )
    )
  end
end
