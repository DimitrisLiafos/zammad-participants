module TicketParticipants::NotificationEmailExtension
  private

  def recipients_by_type(recipient_type)
    return super if recipient_type != 'ticket_participants'

    record.participants.includes(:user).map(&:user)
      .select { |user| user.active? && user.email.present? && TicketPolicy.new(user, record).show?.present? }
      .map(&:email)
  end
end
