require 'rails_helper'

RSpec.describe Ticket::ParticipantPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:ticket)      { create(:ticket) }
  let(:participant) { create(:customer) }
  let(:record)      { create(:ticket_participant, ticket:, user: participant) }

  context 'when user is an agent with read and change access to the group' do
    let(:user) do
      create(:agent).tap do |agent|
        agent.user_groups.create!(group: ticket.group, access: 'read')
        agent.user_groups.create!(group: ticket.group, access: 'change')
      end
    end

    it { is_expected.to permit_actions(:show, :create, :destroy) }
  end

  context 'when user is an agent with read access to the group only' do
    let(:user) { create(:agent).tap { it.user_groups.create!(group: ticket.group, access: 'read') } }

    it { is_expected.to permit_actions(:show) }
    it { is_expected.to forbid_actions(:create, :destroy) }
  end

  context 'when user is an agent without access to the group' do
    let(:user) { create(:agent) }

    it { is_expected.to forbid_actions(:show, :create, :destroy) }
  end

  context 'when user is an admin without access to the group' do
    let(:user) { create(:admin_only) }

    it { is_expected.to forbid_actions(:create, :destroy) }
  end

  context 'when user is the participant' do
    let(:user) { participant }

    it { is_expected.to permit_actions(:show, :destroy) }
    it { is_expected.to forbid_actions(:create) }
  end

  context 'when user is another participant of the ticket' do
    let(:user) { create(:customer) }

    before { create(:ticket_participant, ticket:, user:) }

    it { is_expected.to permit_actions(:show) }
    it { is_expected.to forbid_actions(:create, :destroy) }
  end

  context 'when user is the customer of the ticket' do
    let(:user) { ticket.customer }

    it { is_expected.to permit_actions(:show) }
    it { is_expected.to forbid_actions(:create, :destroy) }
  end

  context 'when user is an unrelated customer' do
    let(:user) { create(:customer) }

    it { is_expected.to forbid_actions(:show, :create, :destroy) }
  end
end
