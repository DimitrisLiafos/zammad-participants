module TicketParticipants::TicketExtension
  def merge_to(data)
    ActiveRecord::Base.transaction do
      super.tap { move_participants_to(data[:ticket_id]) }
    end
  end

  # Read-only for the clients: the classic UI needs it to decide whether the
  #   current user may reply. Deliberately not an association, which could be
  #   assigned through ticket parameters.
  def attributes_with_association_ids
    super.merge('participant_user_ids' => participants.pluck(:user_id))
  end

  def search_index_attribute_lookup(include_references: true)
    attributes = super
    return attributes if !attributes

    attributes['participant_ids'] = participants.pluck(:user_id)
    attributes
  end

  private

  def move_participants_to(target_ticket_id)
    target = Ticket.find(target_ticket_id)

    participants.find_each do |participant|
      if target.customer_id == participant.user_id || target.participants.exists?(user_id: participant.user_id)
        participant.destroy!
      else
        participant.update!(ticket_id: target.id)
      end
    end
  end
end
