# Must run before the overview migration: the participants condition of that
#   overview depends on the column added here.
class TicketParticipantsPerGroup < ActiveRecord::Migration[8.0]
  def self.up
    if !ActiveRecord::Base.connection.column_exists?(:groups, :participants_enabled)
      add_column :groups, :participants_enabled, :boolean, null: false, default: false
    end
    Group.reset_column_information

    ObjectManager::Attribute.add(
      force:       true,
      object:      'Group',
      name:        'participants_enabled',
      display:     'Participants',
      data_type:   'boolean',
      data_option: {
        null:       true,
        default:    false,
        note:       'Allows additional customers to take part in the tickets of this group. They get the same access to a ticket as its customer and are notified about replies.',
        options:    {
          false: 'no',
          true:  'yes',
        },
        translate:  true,
        permission: ['admin.group'],
      },
      editable:    false,
      internal:    true,
      active:      true,
      screens:     {
        create: {
          '-all-' => {
            null: true,
          },
        },
        edit:   {
          '-all-': {
            null: true,
          },
        },
        view:   {
          '-all-' => {
            shown: true,
          },
        },
      },
      to_create:   false,
      to_migrate:  false,
      to_delete:   false,
      position:    1450,
      created_by_id: 1,
      updated_by_id: 1,
    )
  end

  def self.down
    ObjectManager::Attribute.find_by(object_lookup_id: ObjectLookup.by_name('Group'), name: 'participants_enabled')&.delete
    remove_column :groups, :participants_enabled
    Group.reset_column_information
  end
end
