class Ticket::ParticipantPolicy < ApplicationPolicy
  def show?
    return false if !record.ticket.participants_enabled?

    ticket_policy.show?
  end

  def create?
    return false if !record.ticket.participants_enabled?

    ticket_policy.agent_update_access?
  end

  def destroy?
    return false if !record.ticket.participants_enabled?
    return true if record.user_id == user.id

    ticket_policy.agent_update_access?
  end

  private

  def ticket_policy
    @ticket_policy ||= TicketPolicy.new(user, record.ticket)
  end
end
