class Controllers::TicketParticipantsControllerPolicy < Controllers::ApplicationControllerPolicy
  def index?
    participant_policy(record.ticket.participants.build).show?
  end

  def create?
    participant_policy(record.ticket.participants.build).create?
  end

  def destroy?
    participant_policy(record.participant).destroy?
  end

  private

  def participant_policy(participant)
    Ticket::ParticipantPolicy.new(user, participant)
  end
end
