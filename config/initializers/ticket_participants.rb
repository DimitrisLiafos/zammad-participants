Rails.application.reloader.to_prepare do
  Ticket.has_many :participants, class_name: 'Ticket::Participant', dependent: :destroy
  Ticket.association_attributes_ignored :participants
  # Exposed to the clients as `participant_user_ids`, which the classic UI
  #   needs to decide whether the current user may reply.
  Ticket.has_many :participant_users, through: :participants, source: :user
  Ticket.prepend TicketParticipants::TicketExtension
  Ticket.singleton_class.prepend TicketParticipants::TicketSearchExtension

  # Must run before User#destroy_move_dependency_ownership, which refuses to
  #   delete a user that is still referenced by an unknown user_id column.
  User.before_destroy(prepend: true) { Ticket::Participant.where(user_id: id).destroy_all }

  TicketPolicy.prepend TicketParticipants::TicketPolicyExtension
  TicketPolicy::BaseScope.prepend TicketParticipants::TicketPolicyScopeExtension

  Ticket::PerformChanges::Action::NotificationEmail.prepend TicketParticipants::NotificationEmailExtension
end
