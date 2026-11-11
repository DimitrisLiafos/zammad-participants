require 'rails_helper'

RSpec.describe 'Trigger email notification to ticket participants' do # rubocop:disable RSpec/DescribeClass
  let(:ticket)      { create(:ticket) }
  let(:participant) { create(:customer, email: 'participant@example.com') }
  let(:recipient)   { %w[ticket_participants] }
  let(:trigger) do
    create(:trigger, perform: { 'notification.email' => { 'recipient' => recipient, 'subject' => 'closed', 'body' => 'Ticket was closed.' } })
  end

  before do
    ticket.group.update!(email_address: create(:email_address))
    create(:ticket_participant, ticket:, user: participant)
  end

  def notified
    ticket.perform_changes(trigger, 'trigger', {}, 1)

    ticket.articles.reload.where(sender: Ticket::Article::Sender.lookup(name: 'System')).last&.to.to_s
  end

  it 'mails the participants' do
    expect(notified).to eq('participant@example.com')
  end

  it 'skips inactive participants' do
    participant.update!(active: false)

    expect(notified).to be_empty
  end

  context 'when combined with the customer' do
    let(:recipient) { %w[ticket_customer ticket_participants] }

    it 'mails both in one message' do
      expect(notified).to eq("#{ticket.customer.email}, participant@example.com")
    end
  end

  it 'keeps the participant notification from mailing the same article again' do
    article = create(:ticket_article, ticket:, cc: nil)
    notified

    backend = Transaction::TicketParticipantNotification.new({ object: 'Ticket', type: 'update', object_id: ticket.id, article_id: article.id, user_id: 1 })

    expect(backend.recipients).to be_empty
  end
end
