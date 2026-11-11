require 'rails_helper'

RSpec.describe Transaction::TicketParticipantNotification, type: :model do
  let(:ticket)      { create(:ticket) }
  let(:participant) { create(:customer, email: 'participant@example.com') }
  let(:article)     { create(:ticket_article, ticket:, from: ticket.customer.email, to: 'support@example.com', cc: nil) }
  let(:item)        { { object: 'Ticket', type: 'update', object_id: ticket.id, article_id: article.id, user_id: article.created_by_id } }
  let(:deliveries)  { [] }

  before do
    create(:ticket_participant, ticket:, user: participant)
    allow_any_instance_of(Channel).to receive(:deliver) { |_channel, params, _notification| deliveries << params } # rubocop:disable RSpec/AnyInstance
  end

  def perform
    described_class.new(item).perform
  end

  def recipients
    deliveries.pluck(:to)
  end

  it 'notifies the participant about a public reply' do
    perform

    expect(recipients).to eq(['participant@example.com'])
  end

  it 'is registered as an async transaction backend' do
    TransactionJob.perform_now(item)

    expect(recipients).to eq(['participant@example.com'])
  end

  it 'renders the article into the mail' do
    perform

    expect(deliveries.first).to include(subject: include(ticket.title), body: include(article.body), content_type: 'text/html')
  end

  it 'lets replies go to the group email address' do
    ticket.group.update!(email_address: create(:email_address, email: 'support@example.com'))

    perform

    expect(deliveries.first[:reply_to]).to eq('support@example.com')
  end

  it 'logs the notification in the ticket history' do
    item

    expect { perform }.to change { History.list('Ticket', ticket.id).count }.by(1)
  end

  context 'with an outbound agent email' do
    let(:article) { create(:ticket_article, :outbound_email, ticket:) }

    it 'notifies the participant' do
      perform

      expect(recipients).to eq(['participant@example.com'])
    end
  end

  context 'with a public note' do
    let(:article) { create(:ticket_article, :outbound_note, ticket:, internal: false) }

    it 'notifies the participant' do
      perform

      expect(recipients).to eq(['participant@example.com'])
    end
  end

  context 'with an internal article' do
    let(:article) { create(:ticket_article, :outbound_note, ticket:, internal: true) }

    it 'does not notify' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'with a system article' do
    let(:article) { create(:ticket_article, ticket:, sender_name: 'System') }

    it 'does not notify' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'without an article' do
    let(:item) { { object: 'Ticket', type: 'update', object_id: ticket.id, user_id: 1, changes: { 'state_id' => [1, 4] } } }

    it 'does not notify' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when the participant wrote the article' do
    let(:article) { create(:ticket_article, ticket:, from: participant.email, created_by_id: participant.id) }

    it 'does not notify the author' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when the participant was in Cc of the email' do
    let(:article) { create(:ticket_article, ticket:, cc: 'Someone <someone@example.com>, "P" <Participant@Example.com>') }

    it 'does not notify twice' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when the participant was in To of an outbound email' do
    let(:article) { create(:ticket_article, :outbound_email, ticket:, to: "#{ticket.customer.email}, participant@example.com") }

    it 'does not notify twice' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when a trigger already mailed the participant about the article' do
    before do
      article
      create(:ticket_article, ticket:, sender_name: 'System', to: 'participant@example.com', preferences: { perform_origin: 'trigger' })
    end

    it 'does not notify twice' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when a trigger mailed the participant about an earlier article' do
    before do
      create(:ticket_article, ticket:, sender_name: 'System', to: 'participant@example.com', preferences: { perform_origin: 'trigger' })
      article
    end

    it 'notifies the participant' do
      perform

      expect(recipients).to eq(['participant@example.com'])
    end
  end

  context 'when two participants share an email address' do
    before do
      twin = create(:customer)
      twin.update_column(:email, 'PARTICIPANT@example.com') # rubocop:disable Rails/SkipsModelValidations
      create(:ticket_participant, ticket:, user: twin)
    end

    it 'notifies the address once' do
      perform

      expect(recipients.map(&:downcase)).to eq(['participant@example.com'])
    end
  end

  context 'when the participant is inactive' do
    before { participant.update!(active: false) }

    it 'does not notify' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when mail delivery to the participant failed recently' do
    before { participant.update!(preferences: { mail_delivery_failed: true, mail_delivery_failed_data: Time.current }) }

    it 'does not notify' do
      perform

      expect(recipients).to be_empty
    end
  end

  context 'when delivery fails' do
    before do
      allow_any_instance_of(Channel).to receive(:deliver).and_raise(Channel::DeliveryError.new('boom', StandardError.new)) # rubocop:disable RSpec/AnyInstance
      create(:ticket_participant, ticket:, user: create(:customer))
    end

    it 'does not raise' do
      expect { perform }.not_to raise_error
    end
  end
end
