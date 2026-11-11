class Ticket::ParticipantPolicy < ApplicationPolicy
  def show?
    ticket_policy.show?
  end

  def create?
    ticket_policy.agent_update_access?
  end

  def destroy?
    return true if record.user_id == user.id

    ticket_policy.agent_update_access?
  end

  private

  def ticket_policy
    @ticket_policy ||= TicketPolicy.new(user, record.ticket)
  end
end
