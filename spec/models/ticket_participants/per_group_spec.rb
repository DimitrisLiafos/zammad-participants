require 'rails_helper'

RSpec.describe 'Participants per group' do # rubocop:disable RSpec/DescribeClass
  let(:group)       { create(:group, participants_enabled: true) }
  let(:ticket)      { create(:ticket, group:) }
  let(:participant) { create(:customer, email: 'participant@example.com') }
  let(:article)     { create(:ticket_article, ticket:, cc: nil) }
  let(:backend)     { Transaction::TicketParticipantNotification.new({ object: 'Ticket', type: 'update', object_id: ticket.id, article_id: article.id, user_id: 1 }) }

  before { create(:ticket_participant, ticket:, user: participant) }

  it 'is off for new groups' do
    expect(create(:group).participants_enabled).to be(false)
  end

  it 'refuses participants on tickets of a group without the feature' do
    other_ticket = create(:ticket)

    expect(Ticket::Participant.new(ticket: other_ticket, user: create(:customer), created_by_id: 1, updated_by_id: 1)).not_to be_valid
  end

  shared_examples 'dormant participants' do
    it 'keeps the participant stored' do
      expect(ticket.reload.participants.pluck(:user_id)).to eq([participant.id])
    end

    it 'takes away access to the ticket' do
      expect(TicketPolicy.new(participant, ticket.reload)).to forbid_actions(:show, :update)
    end

    it 'removes the ticket from the ticket lists' do
      expect(TicketPolicy::ReadScope.new(participant).resolve).to be_empty
    end

    it 'removes the ticket from the search filter' do
      query = Ticket.search_query_extension(current_user: participant, scope: TicketPolicy::ReadScope)

      expect(query.to_json).not_to include("\"group_id\":[#{ticket.reload.group_id}]")
    end

    it 'removes the ticket from the participants condition' do
      selected = Ticket.selectors({ 'ticket.participant_user_ids' => { operator: 'is', pre_condition: 'specific', value: [participant.id.to_s] } }, current_user: create(:agent, groups: [ticket.reload.group]), limit: 10)

      expect(selected.last.to_a).to be_empty
    end

    it 'stops notifications' do
      allow_any_instance_of(Channel).to receive(:deliver) # rubocop:disable RSpec/AnyInstance
      article

      expect(backend.perform).to be_nil
    end

    it 'empties the trigger recipient' do
      ticket.reload.group.update!(email_address: create(:email_address))
      trigger = create(:trigger, perform: { 'notification.email' => { 'recipient' => %w[ticket_participants], 'subject' => 's', 'body' => 'b' } })

      expect { ticket.reload.perform_changes(trigger, 'trigger', {}, 1) }.not_to change(Ticket::Article, :count)
    end

    it 'hides the participants from the clients' do
      expect(ticket.reload.attributes_with_association_ids).to include('participant_user_ids' => [], 'participants_enabled' => false)
    end
  end

  context 'when the feature is switched off for the group' do
    before { group.update!(participants_enabled: false) }

    it_behaves_like 'dormant participants'

    context 'when it is switched on again' do
      before { group.update!(participants_enabled: true) }

      it 'restores access' do
        expect(TicketPolicy.new(participant, ticket.reload)).to permit_actions(:show, :update)
      end
    end
  end

  context 'when the ticket moves to a group without the feature' do
    before { ticket.update!(group: create(:group)) }

    it_behaves_like 'dormant participants'

    context 'when it moves back' do
      before { ticket.update!(group:) }

      it 'restores access' do
        expect(TicketPolicy.new(participant, ticket.reload)).to permit_actions(:show, :update)
      end
    end
  end

  context 'when the ticket is merged into a ticket of a group without the feature' do
    let(:target) { create(:ticket) }

    before { ticket.merge_to(ticket_id: target.id, user_id: 1) }

    it 'moves the participant along, dormant', :aggregate_failures do
      expect(target.participants.pluck(:user_id)).to eq([participant.id])
      expect(TicketPolicy.new(participant, target)).to forbid_actions(:show)
    end
  end

  describe 'expert conditions' do
    it 'combines customer and participant with OR' do
      own_ticket = create(:ticket, customer: participant)
      create(:ticket)

      condition = {
        operator:   'OR',
        conditions: [
          { name: 'ticket.customer_id', operator: 'is', pre_condition: 'current_user.id' },
          { name: 'ticket.participant_user_ids', operator: 'is', pre_condition: 'current_user.id' },
        ],
      }

      expect(Ticket.selectors(condition, current_user: participant, limit: 10).last.to_a).to contain_exactly(ticket, own_ticket)
    end
  end
end
