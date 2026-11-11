require 'rails_helper'

RSpec.describe Ticket::Participant, type: :model do
  let(:ticket) { create(:ticket) }

  describe 'validations' do
    it 'accepts a customer' do
      expect(build(:ticket_participant, ticket:)).to be_valid
    end

    it 'rejects an agent' do
      participant = build(:ticket_participant, ticket:, user: create(:agent))

      expect(participant).not_to be_valid
    end

    it 'rejects the customer of the ticket' do
      participant = build(:ticket_participant, ticket:, user: ticket.customer)

      expect(participant).not_to be_valid
    end

    it 'rejects the same user twice on one ticket' do
      existing = create(:ticket_participant, ticket:)

      expect(build(:ticket_participant, ticket:, user: existing.user)).not_to be_valid
    end

    it 'rejects an unknown source' do
      expect(build(:ticket_participant, ticket:, source: 'other')).not_to be_valid
    end
  end

  describe 'ticket attributes for the clients' do
    it 'lists the participating users' do
      participant = create(:ticket_participant, ticket:)

      expect(ticket.reload.attributes_with_association_ids).to include('participant_user_ids' => [participant.user_id])
    end
  end

  describe 'side effects' do
    it 'does not dispatch a ticket transaction' do
      ticket
      allow(TransactionDispatcher).to receive(:after_update)

      create(:ticket_participant, ticket:)

      expect(TransactionDispatcher).not_to have_received(:after_update)
    end

    it 'is removed together with its ticket' do
      participant = create(:ticket_participant, ticket:)

      ticket.destroy!

      expect(described_class).not_to exist(participant.id)
    end

    it 'is removed together with its user' do
      participant = create(:ticket_participant, ticket:)

      participant.user.destroy!

      expect(described_class).not_to exist(participant.id)
    end
  end

  describe 'merging tickets' do
    let(:target)      { create(:ticket) }
    let(:participant) { create(:customer) }

    before { create(:ticket_participant, ticket:, user: participant) }

    def merge
      ticket.merge_to(ticket_id: target.id, user_id: 1)
    end

    it 'moves participants to the target ticket' do
      merge

      expect(target.participants.pluck(:user_id)).to eq([participant.id])
    end

    it 'drops a participant that already participates in the target ticket' do
      create(:ticket_participant, ticket: target, user: participant)

      merge

      expect(described_class.where(user: participant).pluck(:ticket_id)).to eq([target.id])
    end

    it 'drops a participant that is the customer of the target ticket' do
      target.update!(customer: participant)

      merge

      expect(described_class.where(user: participant)).to be_empty
    end
  end
end
