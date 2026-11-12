# Installing Ticket Participants

For a **package install of Zammad 7.2.2** (deb/rpm, `zammad` command available, files in
`/opt/zammad`). Tested on Ubuntu 22.04. Docker installs need a derived image with the package
files and recompiled assets instead; the stock image cannot rebuild them.

Run the commands as `root` on the Zammad server.

## Before you install

- **Version:** `zammad run rails r 'puts Version.get'` must print `7.2.2…`. The package patches
  Zammad internals and is only tested against 7.2.2.
- **No ticket field named `participants`:** a custom ticket field called `participants` or
  `participant_ids` clashes with the package and breaks the new ticket form. Check:

  ```bash
  zammad run rails r 'p Ticket.column_names & %w[participants participant_ids]'
  # => []
  ```

  If it lists a field, save its data if you need it, delete the field (*Manage → Objects →
  Ticket*, then *Update database*) and restart Zammad.
- **Backup:** back up the database and `/opt/zammad`, e.g. with
  `/opt/zammad/contrib/backup/zammad_backup.sh`.
- **Downtime:** the install rebuilds the web interface's assets (several minutes). The web
  interface is unavailable until the restart at the end.
- **Network:** the asset rebuild runs `pnpm install` and needs access to `registry.npmjs.org`.

### Test on a copy first

Try the install on a test system or a copy of your production server first. A copy of
production still fetches from your mailboxes and sends mail to your customers: before it gets
network access, switch off its channels and integrations:

```bash
zammad run rails r 'Channel.update_all(active: false)'
zammad run rails r 'Webhook.update_all(active: false)'
zammad run rails r 'Setting.set("ldap_integration", false)'
```

## Install

Build the `.zpm` as described in `README.md` and copy it to the server, then:

```bash
zammad run rake zammad:package:install /tmp/TicketParticipants-0.5.2.zpm
zammad run rake zammad:package:post_install   # migrations + asset rebuild
systemctl restart zammad
```

Use `rake`, not `rails`, for these commands: `rails` rejects the file argument.

Check it:

```bash
zammad run rails r 'p Package.pluck(:name, :version, :state)'
# => [["TicketParticipants", "0.5.2", "installed"]]
```

In the browser (reload with Ctrl+F5), *Manage → Groups →* edit a group shows the field
**Participants**. Nothing changes for users yet: the feature is off for every group.

## Switch it on

1. *Manage → Groups →* edit a group *→ Participants: yes*, for groups whose tickets may be
   shared with additional customers.
2. Test with one ticket of that group: add a customer in the *Participants* sidebar tab, log in
   as that customer and check that they see the ticket and can reply. Pick a customer outside
   the ticket's organization: in a *shared* organization every member sees its tickets anyway.
3. Optional:
   - **"My Tickets" with participating tickets:** enable *Settings → Ticket → Allow expert
     conditions*, then edit the *My Tickets* overview in expert mode: *Customer is current
     user* **OR** *Participants is current user*.
   - **Cc auto-add:** *Channels → Email → Settings*: enter the allowed email domains, then
     switch on *Add Cc recipients as ticket participants*.
   - **Triggers:** use the email recipient *Participants* for state changes and other events.

## Uninstall

Switching the feature off for a group stops it there; participants stay stored but have no
access and get no mail. To remove the package completely:

```bash
zammad run rake zammad:package:uninstall TicketParticipants
zammad run rake zammad:package:post_install
systemctl restart zammad
```

**This deletes all participants** and the package's settings and overview. Revert overviews
and triggers that use *Participants* first.

## Updates

- **Zammad:** the package is tied to 7.2.2. Before updating Zammad, run the specs against the
  new version (`README.md`, "Development"). Update only when they pass, then run
  `zammad run rake zammad:package:reinstall_all`, `post_install` and the restart as above.
- **Package:** install the newer `.zpm` with the same install steps. Participants and settings
  are kept.
