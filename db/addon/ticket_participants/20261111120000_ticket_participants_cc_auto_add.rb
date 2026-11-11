class TicketParticipantsCcAutoAdd < ActiveRecord::Migration[8.0]
  PERMISSIONS = ['admin.channel_email', 'admin.channel_google', 'admin.channel_microsoft365', 'admin.channel_microsoft_graph'].freeze

  def self.up
    Setting.create_if_not_exists(
      title:       'Add Cc recipients as ticket participants',
      name:        'ticket_participants_cc_auto_add',
      area:        'Email::Base',
      description: 'Adds the Cc recipients of incoming customer emails as participants of the ticket, if their email domain is allowed below. Participants get the same access to the ticket as its customer.',
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'ticket_participants_cc_auto_add',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      state:       false,
      preferences: { permission: PERMISSIONS },
      frontend:    false
    )
    Setting.create_if_not_exists(
      title:       'Email domains for adding Cc recipients as ticket participants',
      name:        'ticket_participants_cc_auto_add_domains',
      area:        'Email::Base',
      description: 'Comma-separated list of email domains (e.g. "example.com, example.org") whose addresses are added as participants. Subdomains must be listed separately. Without a domain nobody is added.',
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'ticket_participants_cc_auto_add_domains',
            tag:     'input',
          },
        ],
      },
      state:       '',
      preferences: { permission: PERMISSIONS },
      frontend:    false
    )
    Setting.create_if_not_exists(
      title:       'Define postmaster filter.',
      name:        '0950_postmaster_filter_ticket_participants_cc',
      area:        'Postmaster::PostFilter',
      description: 'Defines postmaster filter to add Cc recipients as ticket participants.',
      options:     {},
      state:       'Channel::Filter::TicketParticipantsCc',
      frontend:    false
    )
  end

  def self.down
    %w[ticket_participants_cc_auto_add ticket_participants_cc_auto_add_domains 0950_postmaster_filter_ticket_participants_cc].each do |name|
      Setting.find_by(name:)&.destroy
    end
  end
end
