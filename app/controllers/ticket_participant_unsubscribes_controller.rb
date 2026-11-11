class TicketParticipantUnsubscribesController < ApplicationController
  # Reached from an email without a session: the signed token is the credential.
  skip_before_action :verify_csrf_token

  # GET /api/v1/ticket_participants/unsubscribe/:token
  #
  # Only asks for confirmation, because mail scanners and link previews fetch
  #   links on their own.
  def show
    return render_page(:not_found, 'This link is no longer valid.') if !participant

    render_page(:ok, "Do you want to leave ticket #{ticket_label}? You will no longer receive its updates and lose your access to it.", confirm: true)
  end

  # POST /api/v1/ticket_participants/unsubscribe/:token
  def create
    return render_page(:not_found, 'This link is no longer valid.') if !participant

    label = ticket_label
    participant.destroy!

    render_page(:ok, "You have left ticket #{label}.")
  end

  private

  def participant
    @participant ||= Ticket::Participant.find_by_unsubscribe_token(params[:token])
  end

  def ticket_label
    "#{Setting.get('ticket_hook')}#{participant.ticket.number}"
  end

  def render_page(status, message, confirm: false)
    button = confirm ? '<form method="post"><button type="submit">Leave ticket</button></form>' : ''

    render status:, html: <<~HTML.html_safe # rubocop:disable Rails/OutputSafety
      <!DOCTYPE html>
      <html>
        <head><meta charset="utf-8"><meta name="robots" content="noindex"><title>#{ERB::Util.h(Setting.get('product_name'))}</title></head>
        <body style="font-family: sans-serif; max-width: 32em; margin: 4em auto; padding: 0 1em;">
          <p>#{ERB::Util.h(message)}</p>
          #{button}
        </body>
      </html>
    HTML
  end
end
