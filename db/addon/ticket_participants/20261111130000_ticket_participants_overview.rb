class TicketParticipantsOverview < ActiveRecord::Migration[8.0]
  def self.up
    Overview.create_if_not_exists(
      name:          'Tickets I participate in',
      link:          'my_participating_tickets',
      prio:          1150,
      role_ids:      [Role.find_by(name: 'Customer').id],
      condition:     {
        'ticket.state_id'             => {
          operator: 'is',
          value:    Ticket::State.by_category_ids(:viewable),
        },
        'ticket.participant_user_ids' => {
          operator:      'is',
          pre_condition: 'current_user.id',
        },
      },
      order:         {
        by:        'created_at',
        direction: 'DESC',
      },
      view:          {
        d:                 %w[title customer state created_at],
        s:                 %w[number title customer state created_at],
        m:                 %w[number title customer state created_at],
        view_mode_default: 's',
      },
      created_by_id: 1,
      updated_by_id: 1,
    )
  end

  def self.down
    Overview.find_by(link: 'my_participating_tickets')&.destroy
  end
end
