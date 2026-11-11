module TicketParticipants::SelectorSqlExtension
  CONDITION = 'ticket.participant_user_ids'.freeze
  SUBQUERY  = 'SELECT ticket_participants.ticket_id FROM ticket_participants'.freeze

  def condition_sql(block_condition)
    return super if block_condition.blank? || block_condition[:name] != CONDITION
    raise Selector::Sql::InvalidCondition, "Invalid operator #{block_condition[:operator].inspect} for #{CONDITION}" if ['is', 'is not'].exclude?(block_condition[:operator])

    participating = block_condition[:operator] == 'is'

    # 'not_set' asks for tickets without any participant, so it flips the match.
    if block_condition[:pre_condition] == 'not_set'
      return [["tickets.id #{participating ? 'NOT IN' : 'IN'} (#{SUBQUERY})"], [], []]
    end

    user_ids = if block_condition[:pre_condition] == 'current_user.id'
                 options[:current_user]&.id || UserInfo.current_user_id
               else
                 block_condition[:value]
               end

    [["tickets.id #{participating ? 'IN' : 'NOT IN'} (#{SUBQUERY} WHERE ticket_participants.user_id IN (?))"], [Array(user_ids)], []]
  end
end
