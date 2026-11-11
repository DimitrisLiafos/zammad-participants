class TicketParticipantsSetup < ActiveRecord::Migration[8.0]
  def self.up
    create_table :ticket_participants do |t|
      t.references :ticket, null: false, foreign_key: { on_delete: :cascade }
      t.references :user,   null: false, foreign_key: { on_delete: :cascade }
      t.string     :source, limit: 20, null: false, default: 'agent'
      t.integer    :created_by_id, null: false
      t.integer    :updated_by_id, null: false
      t.timestamps limit: 3, null: false
    end
    add_index :ticket_participants, %i[ticket_id user_id], unique: true
    add_foreign_key :ticket_participants, :users, column: :created_by_id
    add_foreign_key :ticket_participants, :users, column: :updated_by_id

    Setting.create_if_not_exists(
      title:       'Defines transaction backend.',
      name:        '0110_ticket_participant_notification',
      area:        'Transaction::Backend::Async',
      description: 'Defines the transaction backend to send notifications to ticket participants.',
      options:     {},
      state:       'Transaction::TicketParticipantNotification',
      frontend:    false
    )
  end

  def self.down
    Setting.find_by(name: '0110_ticket_participant_notification')&.destroy
    drop_table :ticket_participants
  end
end
