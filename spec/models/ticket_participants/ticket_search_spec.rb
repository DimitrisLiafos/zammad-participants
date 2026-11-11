require 'rails_helper'

RSpec.describe 'Ticket search with participants' do # rubocop:disable RSpec/DescribeClass
  let(:ticket)      { create(:ticket) }
  let(:participant) { create(:customer) }

  before { create(:ticket_participant, ticket:, user: participant) }

  it 'indexes the participant ids' do
    expect(ticket.reload.search_index_attribute_lookup).to include('participant_ids' => [participant.id])
  end

  it 'lets customers find tickets they participate in' do
    query = Ticket.search_query_extension(current_user: participant, scope: TicketPolicy::ReadScope)

    expect(query.dig(:bool, :must, 0, :bool, :should)).to include({ 'term' => { 'participant_ids' => participant.id } })
  end

  it 'does not widen the query for agents' do
    agent = create(:agent, groups: [ticket.group])
    query = Ticket.search_query_extension(current_user: agent, scope: TicketPolicy::ReadScope)

    expect(query.to_json).not_to include('participant_ids')
  end

  context 'with elasticsearch', searchindex: true do
    before do
      searchindex_model_reload([Ticket])
    end

    it 'finds the ticket for the participant' do
      expect(Ticket.search(current_user: participant, query: ticket.number)).to include(ticket)
    end
  end
end
