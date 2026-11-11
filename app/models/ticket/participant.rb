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

  # Touching (instead of updating) keeps the ticket out of the transaction
  #   dispatcher, so adding a participant fires no triggers or notifications,
  #   while the search index and connected clients still pick up the change.
  after_commit :touch_ticket

  # A reply that quotes the notification puts the link into the ticket, where
  #   others can read it, so it must not stay usable forever.
  UNSUBSCRIBE_TOKEN_VALIDITY = 30.days

  def self.find_by_unsubscribe_token(token)
    id, user_id = unsubscribe_verifier.verified(token.to_s, purpose: :unsubscribe)
    return if !id

    find_by(id:, user_id:)
  end

  def self.unsubscribe_verifier
    Rails.application.message_verifier(:ticket_participant_unsubscribe)
  end

  def unsubscribe_url
    "#{Setting.get('http_type')}://#{Setting.get('fqdn')}#{Rails.configuration.api_path}/ticket_participants/unsubscribe/#{unsubscribe_token}"
  end

  def unsubscribe_token
    @unsubscribe_token ||= self.class.unsubscribe_verifier.generate([id, user_id], purpose: :unsubscribe, expires_in: UNSUBSCRIBE_TOKEN_VALIDITY)
  end

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

  def touch_ticket
    Ticket.find_by(id: ticket_id)&.touch
  end
end
