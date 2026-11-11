class Ticket::Participant < ApplicationModel
  include HasDefaultModelUserRelations
  include HasHistory

  self.table_name = 'ticket_participants'

  SOURCES = %w[agent cc_auto].freeze

  belongs_to :ticket
  belongs_to :user

  association_attributes_ignored :created_by, :updated_by

  validates :user_id, uniqueness: { scope: :ticket_id }
  validates :source, inclusion: { in: SOURCES }
  validate :user_qualifies
  validate :group_allows_participants, on: :create

  # Touching (instead of updating) keeps the ticket out of the transaction
  #   dispatcher, so adding a participant fires no triggers or notifications,
  #   while the search index and connected clients still pick up the change.
  after_commit :touch_ticket

  def history_log_attributes
    {
      related_o_id:           ticket_id,
      related_history_object: 'Ticket',
      value_to:               user_id,
    }
  end

  def history_destroy
    history_log('removed', updated_by_id)
  end

  private

  def user_qualifies
    return if user.blank?

    errors.add(:user, 'must be a customer') if !user.permissions?('ticket.customer') || user.permissions?('ticket.agent')
    errors.add(:user, 'is already the customer of this ticket') if ticket&.customer_id == user_id
  end

  # Only on create: participants of a ticket that moves into a group without
  #   the feature stay stored, to come back when it moves on or the group
  #   enables it.
  def group_allows_participants
    return if ticket.blank? || ticket.participants_enabled?

    errors.add(:ticket, 'belongs to a group that does not allow participants')
  end

  def touch_ticket
    Ticket.find_by(id: ticket_id)&.touch
  end
end
