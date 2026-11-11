module TicketParticipants::TicketPolicyExtension
  private

  def customer_access?
    super || participant_access?
  end

  def participant_access?
    return false if !user.permissions?('ticket.customer')
    return false if !record.persisted?
    return false if !Ticket::Participant.exists?(ticket_id: record.id, user_id: user.id)

    customer_field_scope
  end
end
