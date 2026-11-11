require 'rails_helper'

RSpec.describe Channel::Filter::TicketParticipantsCc, type: :channel_filter do
  let(:cc)   { 'Colleague <colleague@allowed.example>, other@elsewhere.example' }
  let(:from) { 'customer@elsewhere.example' }
  let(:raw_mail) do
    <<~MAIL
      From: #{from}
      To: support@zammad.example
      Cc: #{cc}
      Subject: Printer broken

      Some text
    MAIL
  end

  before do
    Group.find_each { |group| group.update!(participants_enabled: true) }
    Setting.set('ticket_participants_cc_auto_add', true)
    Setting.set('ticket_participants_cc_auto_add_domains', 'Allowed.example, @second.example')
  end

  def participants
    ticket, = Channel::EmailParser.new.process({}, raw_mail)

    ticket.participants.includes(:user).map { |participant| [participant.user.email, participant.source] }
  end

  it 'adds Cc recipients of allowed domains' do
    expect(participants).to eq([['colleague@allowed.example', 'cc_auto']])
  end

  it 'does not treat a subdomain as allowed' do
    Setting.set('ticket_participants_cc_auto_add_domains', 'example')

    expect(participants).to be_empty
  end

  it 'adds nobody when the group does not allow participants' do
    Group.find_each { |group| group.update!(participants_enabled: false) }

    expect(participants).to be_empty
  end

  it 'adds nobody when disabled' do
    Setting.set('ticket_participants_cc_auto_add', false)

    expect(participants).to be_empty
  end

  it 'adds nobody without allowed domains' do
    Setting.set('ticket_participants_cc_auto_add_domains', '')

    expect(participants).to be_empty
  end

  context 'when an agent is in Cc' do
    before { create(:agent, email: 'colleague@allowed.example') }

    it 'does not add the agent' do
      expect(participants).to be_empty
    end
  end

  context 'when a system address is in Cc' do
    before { create(:email_address, email: 'colleague@allowed.example') }

    it 'does not add it' do
      expect(participants).to be_empty
    end
  end

  context 'when the email is a follow-up' do
    let(:ticket) { create(:ticket, group: create(:group, participants_enabled: true)) }
    let(:from)   { ticket.customer.email }
    let(:raw_mail) do
      super().sub('Subject: Printer broken', "Subject: RE: Printer broken [Ticket##{ticket.number}]")
    end

    it 'adds the Cc recipient to the existing ticket' do
      expect(participants).to eq([['colleague@allowed.example', 'cc_auto']])
    end

    context 'when somebody without access to the ticket sends it' do
      let(:from) { 'stranger@allowed.example' }

      it 'adds nobody' do
        expect(participants).to be_empty
      end
    end

    context 'when a participant sends it' do
      let(:from) { create(:ticket_participant, ticket:).user.email }

      it 'adds the Cc recipient' do
        expect(participants).to include(['colleague@allowed.example', 'cc_auto'])
      end
    end

    context 'when an agent of the group sends it' do
      let(:from) { create(:agent, groups: [ticket.group]).email }

      it 'adds nobody' do
        expect(participants).to be_empty
      end
    end

    it 'does not notify the added participant about the email they were copied on' do
      _, article = Channel::EmailParser.new.process({}, raw_mail)
      backend    = Transaction::TicketParticipantNotification.new({ object: 'Ticket', type: 'update', object_id: ticket.id, article_id: article.id, user_id: article.created_by_id })

      expect(backend.recipients).to be_empty
    end
  end
end
