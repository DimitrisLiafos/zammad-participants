require 'rails_helper'

RSpec.describe TicketPolicy, 'participant access' do
  let(:ticket)      { create(:ticket) }
  let(:participant) { create(:customer) }

  before { create(:ticket_participant, ticket:, user: participant) }

  describe 'record policy' do
    subject(:policy) { described_class.new(participant, ticket) }

    it { is_expected.to permit_actions(:show, :update, :follow_up) }
    it { is_expected.to forbid_actions(:destroy, :agent_read_access, :agent_update_access) }

    it 'hides agent-only fields' do
      expect(policy.show?).to be_a(ApplicationPolicy::FieldScope)
    end

    context 'when the participant has been removed' do
      before { Ticket::Participant.find_by(user: participant).destroy! }

      it { is_expected.to forbid_actions(:show, :update) }
    end

    context 'when the ticket is closed and the group forbids follow-ups' do
      before do
        ticket.group.update!(follow_up_possible: 'new_ticket')
        ticket.update!(state: Ticket::State.find_by(name: 'closed'))
      end

      it { is_expected.to forbid_actions(:follow_up) }
    end
  end

  describe 'article policy' do
    it 'allows public articles' do
      article = create(:ticket_article, ticket:, internal: false)

      expect(Ticket::ArticlePolicy.new(participant, article)).to permit_actions(:show)
    end

    it 'forbids internal articles' do
      article = create(:ticket_article, ticket:, internal: true)

      expect(Ticket::ArticlePolicy.new(participant, article)).to forbid_actions(:show)
    end
  end

  describe 'scopes' do
    let!(:other_ticket) { create(:ticket) }
    let!(:own_ticket)   { create(:ticket, customer: participant) }

    %w[ReadScope ChangeScope OverviewScope FullScope].each do |scope_name|
      it "#{scope_name} includes own and participating tickets only" do
        resolved = "TicketPolicy::#{scope_name}".constantize.new(participant).resolve

        expect(resolved).to contain_exactly(ticket, own_ticket)
      end
    end

    it 'keeps a predefined scope restriction' do
      resolved = TicketPolicy::ReadScope.new(participant, Ticket.where(id: own_ticket.id)).resolve

      expect(resolved).to contain_exactly(own_ticket)
    end

    it 'does not change the scope of an agent' do
      agent = create(:agent, groups: [other_ticket.group])

      expect(TicketPolicy::ReadScope.new(agent).resolve).to include(other_ticket).and(not_include(ticket))
    end
  end
end
