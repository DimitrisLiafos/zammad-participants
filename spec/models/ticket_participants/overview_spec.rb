require 'rails_helper'

RSpec.describe 'Overviews with participants' do # rubocop:disable RSpec/DescribeClass
  let(:participant) { create(:customer) }
  let(:ticket)      { create(:ticket) }
  let!(:own_ticket) { create(:ticket, customer: participant) }

  # Selectors only return tickets the user may see, so this one never shows up.
  before { create(:ticket) }

  before { create(:ticket_participant, ticket:, user: participant) }

  def select_tickets(condition, user: participant)
    Ticket.selectors({ 'ticket.participant_user_ids' => condition }, current_user: user, limit: 100).last.to_a
  end

  describe 'condition ticket.participant_user_ids' do
    it 'selects the tickets the current user participates in' do
      expect(select_tickets({ operator: 'is', pre_condition: 'current_user.id' })).to contain_exactly(ticket)
    end

    it 'selects the tickets the current user does not participate in' do
      expect(select_tickets({ operator: 'is not', pre_condition: 'current_user.id' })).to contain_exactly(own_ticket)
    end

    it 'selects the tickets of specific participants' do
      expect(select_tickets({ operator: 'is', pre_condition: 'specific', value: [participant.id.to_s] }, user: create(:agent, groups: [ticket.group]))).to contain_exactly(ticket)
    end

    it 'selects the tickets without participants' do
      expect(select_tickets({ operator: 'is', pre_condition: 'not_set' })).to contain_exactly(own_ticket)
    end

    it 'selects the tickets with participants' do
      expect(select_tickets({ operator: 'is not', pre_condition: 'not_set' })).to contain_exactly(ticket)
    end

    it 'rejects other operators' do
      expect(Ticket.selector2sql({ 'ticket.participant_user_ids' => { operator: 'contains', value: 'x' } })).to be_blank
    end
  end

  describe 'overview "Tickets I participate in"' do
    def overview_tickets(user)
      result = Ticket::Overviews.index(user, ['my_participating_tickets']).first

      result ? result[:tickets].pluck(:id) : nil
    end

    it 'shows participants their tickets' do
      expect(overview_tickets(participant)).to eq([ticket.id])
    end

    it 'is empty for a customer who participates nowhere' do
      expect(overview_tickets(ticket.customer)).to eq([])
    end

    it 'is not offered to agents' do
      expect(overview_tickets(create(:agent, groups: [ticket.group]))).to be_nil
    end
  end
end
