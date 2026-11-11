class Transaction::TicketParticipantNotification
  EMAIL_PATTERN = %r{[^\s<>,;"'()]+@[^\s<>,;"'()]+}

  def initialize(item, params = {})
    @item   = item
    @params = params
  end

  def perform
    return if Setting.get('import_mode')
    return if @item[:object] != 'Ticket'
    return if @params[:disable_notification]
    return if !ticket || !article
    return if article.internal?
    return if Ticket::Article::Sender.lookup(id: article.sender_id)&.name == 'System'

    recipients.each { |user| notify(user) }
  end

  def recipients
    candidates = ticket.participants.includes(:user).map(&:user)
    candidates = candidates.select { |user| deliverable?(user) }
    candidates.uniq { |user| user.email.downcase }
  end

  private

  def ticket
    @ticket ||= Ticket.find_by(id: @item[:object_id])
  end

  def article
    return if !@item[:article_id]

    @article ||= Ticket::Article.find_by(id: @item[:article_id])
  end

  def deliverable?(user)
    return false if !user.active?
    return false if user.email.blank?
    return false if excluded_user_ids.include?(user.id)
    return false if already_addressed_emails.include?(user.email.downcase)
    return false if user.mail_delivery_failed_blocked_days.positive?

    # A participation may outlive the role it was granted for.
    TicketPolicy.new(user, ticket).show?.present?
  end

  def excluded_user_ids
    @excluded_user_ids ||= [article.created_by_id, article.origin_by_id, ticket.customer_id].compact
  end

  # Whoever was already mailed this content directly (the article's own
  #   From/To/Cc) or by an automation reacting to it (trigger, scheduler,
  #   macro articles sent after it) must not get it a second time.
  def already_addressed_emails
    @already_addressed_emails ||= [article, *automation_articles]
      .flat_map { |mail_article| [mail_article.from, mail_article.to, mail_article.cc] }
      .flat_map { |field| field.to_s.scan(EMAIL_PATTERN) }
      .to_set(&:downcase)
  end

  def automation_articles
    ticket.articles
      .where(sender_id: Ticket::Article::Sender.lookup(name: 'System').id)
      .where('ticket_articles.id > ?', article.id)
      .select { |automation_article| automation_article.preferences['perform_origin'].present? }
  end

  def notify(user)
    delivered = deliver(user)
    return if !delivered

    History.add(
      o_id:           ticket.id,
      history_type:   'notification',
      history_object: 'Ticket',
      value_to:       "#{user.email}(participant:email)",
      created_by_id:  @item[:user_id] || 1
    )
  rescue Channel::DeliveryError => e
    Rails.logger.error "Unable to send ticket participant notification to #{user.email}: #{e.message}"
  end

  def deliver(user)
    channel = Channel.find_by(area: 'Email::Notification', active: true)
    return false if !channel

    rendered = NotificationFactory::Mailer.template(
      template: 'ticket_participant_article',
      locale:   user.locale,
      timezone: Setting.get('timezone_default'),
      objects:  {
        ticket:       ticket,
        article:      article,
        recipient:    user,
        current_user: User.lookup(id: @item[:user_id]) || User.lookup(id: 1),
      },
    )

    channel.deliver(
      {
        from:         Setting.get('notification_sender'),
        to:           user.email,
        reply_to:     ticket.group.email_address&.email,
        subject:      ticket.subject_build(rendered[:subject]),
        message_id:   "<participant.#{DateTime.current.to_fs(:number)}.#{ticket.id}.#{user.id}.#{SecureRandom.uuid}@#{Setting.get('fqdn')}>",
        references:   ticket.get_references,
        body:         HtmlSanitizer.dynamic_image_size(HtmlSanitizer.adjust_inline_image_size(rendered[:body])),
        content_type: 'text/html',
        attachments:  article.attachments_inline,
      }.compact,
      true,
    )
  end
end
