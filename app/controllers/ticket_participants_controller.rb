class TicketParticipantsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # GET /api/v1/tickets/:ticket_id/participants
  def index
    render json: ticket.participants.includes(:user).reorder(:id).map { |participant| participant_json(participant) }
  end

  # POST /api/v1/tickets/:ticket_id/participants
  def create
    participant = ticket.participants.create!(user: User.find(params[:user_id]), source: 'agent')

    render json: participant_json(participant), status: :created
  end

  # DELETE /api/v1/tickets/:ticket_id/participants/:id
  def destroy
    participant.destroy!

    render json: true, status: :ok
  end

  def ticket
    @ticket ||= Ticket.find(params[:ticket_id])
  end

  def participant
    @participant ||= ticket.participants.find(params[:id])
  end

  private

  # Participants are visible to everyone who sees the ticket, including other
  #   customers, who must not learn email addresses from it.
  def participant_json(participant)
    data = {
      id:         participant.id,
      ticket_id:  participant.ticket_id,
      user_id:    participant.user_id,
      source:     participant.source,
      fullname:   participant.user.fullname,
      created_at: participant.created_at,
    }
    data[:email] = participant.user.email if current_user.permissions?('ticket.agent')
    data
  end
end
