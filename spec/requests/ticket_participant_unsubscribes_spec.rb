require 'rails_helper'

RSpec.describe 'Ticket participant unsubscribe', type: :request do
  let(:participant) { create(:ticket_participant) }
  let(:path)        { URI(participant.unsubscribe_url).path }

  describe 'GET' do
    it 'asks for confirmation without removing the participant', :aggregate_failures do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Leave ticket', participant.ticket.number)
      expect(Ticket::Participant).to exist(participant.id)
    end

    it 'rejects a forged token' do
      get path.sub(%r{[^/]+\z}, participant.unsubscribe_token.reverse)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST' do
    it 'removes the participant without a login', :aggregate_failures do
      post path, params: { 'List-Unsubscribe' => 'One-Click' }

      expect(response).to have_http_status(:ok)
      expect(Ticket::Participant).not_to exist(participant.id)
    end

    it 'removes access to the ticket' do
      post path

      expect(TicketPolicy.new(participant.user, participant.ticket)).to forbid_actions(:show)
    end

    it 'cannot be used for another participant', :aggregate_failures do
      other = create(:ticket_participant)

      post path

      expect(Ticket::Participant).to exist(other.id)
    end

    it 'rejects a token after the participant was removed' do
      participant.destroy!

      post path

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects an expired link', :aggregate_failures do
      path

      travel_to 31.days.from_now

      post path

      expect(response).to have_http_status(:not_found)
      expect(Ticket::Participant).to exist(participant.id)
    end

    it 'rejects a forged token', :aggregate_failures do
      post "#{path}x"

      expect(response).to have_http_status(:not_found)
      expect(Ticket::Participant).to exist(participant.id)
    end
  end
end
