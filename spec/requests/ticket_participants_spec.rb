require 'rails_helper'

RSpec.describe 'Ticket participants', authenticated_as: :user, type: :request do
  let(:ticket)      { create(:ticket) }
  let(:agent)       { create(:agent, groups: [ticket.group]) }
  let(:participant) { create(:customer) }
  let(:record)      { create(:ticket_participant, ticket:, user: participant) }
  let(:path)        { "/api/v1/tickets/#{ticket.id}/participants" }

  describe 'GET /api/v1/tickets/:ticket_id/participants' do
    before { record }

    context 'when user is an agent of the group' do
      let(:user) { agent }

      it 'lists participants with their email' do
        get path, as: :json

        expect(json_response).to include('can_add' => true, 'participants' => contain_exactly(include('id' => record.id, 'user_id' => participant.id, 'fullname' => participant.fullname, 'email' => participant.email, 'source' => 'agent', 'removable' => true)))
      end
    end

    context 'when user is the ticket customer' do
      let(:user) { ticket.customer }

      it 'lists participants without their email', :aggregate_failures do
        get path, as: :json

        expect(json_response).to include('can_add' => false)
        expect(json_response['participants'].first).to include('fullname' => participant.fullname, 'removable' => false)
        expect(json_response['participants'].first).not_to have_key('email')
      end
    end

    context 'when user is an agent elsewhere but only the customer of this ticket' do
      let(:user) { create(:agent_and_customer) }

      before { ticket.update!(customer: user) }

      it 'lists participants without their email' do
        get path, as: :json

        expect(json_response['participants'].first).not_to have_key('email')
      end
    end

    context 'when user is a participant' do
      let(:user) { participant }

      it 'lists participants' do
        get path, as: :json

        expect(json_response).to include('can_add' => false, 'participants' => [include('user_id' => participant.id, 'removable' => true)])
      end
    end

    context 'when user is an unrelated customer' do
      let(:user) { create(:customer) }

      it 'is forbidden' do
        get path, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/tickets/:ticket_id/participants' do
    context 'when user is an agent of the group' do
      let(:user) { agent }

      it 'adds the participant', :aggregate_failures do
        post path, params: { user_id: participant.id }, as: :json

        expect(response).to have_http_status(:created)
        expect(ticket.participants.pluck(:user_id, :source, :created_by_id)).to eq([[participant.id, 'agent', agent.id]])
      end

      it 'rejects an agent as participant' do
        post path, params: { user_id: create(:agent).id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects a duplicate' do
        record

        post path, params: { user_id: participant.id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when user is an agent of another group' do
      let(:user) { create(:agent) }

      it 'is forbidden' do
        post path, params: { user_id: participant.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is the ticket customer' do
      let(:user) { ticket.customer }

      it 'is forbidden' do
        post path, params: { user_id: participant.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when a customer tries to add themselves' do
      let(:user) { participant }

      it 'is forbidden' do
        post path, params: { user_id: participant.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/tickets/:ticket_id/participants/:id' do
    before { record }

    context 'when user is an agent of the group' do
      let(:user) { agent }

      it 'removes the participant' do
        delete "#{path}/#{record.id}", as: :json

        expect(ticket.participants).to be_empty
      end
    end

    context 'when user is the participant' do
      let(:user) { participant }

      it 'removes themselves and loses access', :aggregate_failures do
        delete "#{path}/#{record.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(TicketPolicy.new(participant, ticket)).to forbid_actions(:show)
      end
    end

    context 'when user is another participant' do
      let(:user) { create(:customer) }

      before { create(:ticket_participant, ticket:, user:) }

      it 'is forbidden', :aggregate_failures do
        delete "#{path}/#{record.id}", as: :json

        expect(response).to have_http_status(:forbidden)
        expect(ticket.participants.count).to eq(2)
      end
    end

    context 'when user is the ticket customer' do
      let(:user) { ticket.customer }

      it 'is forbidden' do
        delete "#{path}/#{record.id}", as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the participant belongs to another ticket' do
      let(:user)   { agent }
      let(:record) { create(:ticket_participant, user: participant) }

      it 'is not found' do
        delete "#{path}/#{record.id}", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
