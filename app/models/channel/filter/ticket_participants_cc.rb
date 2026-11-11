module Channel::Filter::TicketParticipantsCc
  def self.run(_channel, mail, ticket, article, _session_user)
    return if !Setting.get('ticket_participants_cc_auto_add')
    return if !ticket || !article
    return if Ticket::Article::Sender.lookup(id: article.sender_id)&.name != 'Customer'

    # Follow-ups are accepted from anybody who knows the ticket number, so only
    #   somebody who may see the ticket already can bring others into it.
    sender = User.lookup(id: article.origin_by_id || article.created_by_id)
    return if !sender || !TicketPolicy.new(sender, ticket).show?

    domains = allowed_domains
    return if domains.blank?

    cc_addresses(mail).each do |email|
      next if domains.exclude?(email.split('@').last)

      add_participant(ticket, email)
    end
  end

  def self.allowed_domains
    Setting.get('ticket_participants_cc_auto_add_domains').to_s.downcase.split(%r{[\s,;]+}).map { |domain| domain.delete_prefix('@') }.compact_blank
  end

  def self.cc_addresses(mail)
    addresses = begin
      mail[:'raw-cc'].addrs.map(&:address)
    rescue
      mail[:cc].to_s.scan(Transaction::TicketParticipantNotification::EMAIL_PATTERN)
    end

    addresses.compact.map { |address| address.downcase.strip }.uniq
  end

  def self.add_participant(ticket, email)
    return if EmailAddress.exists?(email:)

    user = User.find_by(email:)
    return if !user
    return if ticket.participants.exists?(user:)

    # Agents and the ticket customer are turned down by the model.
    ticket.participants.create(user:, source: 'cc_auto', created_by_id: 1, updated_by_id: 1)
  end
end
