# Production runbook: Ticket Participants on Zammad 7.2.2 (Ubuntu package install)

For a Zammad installed from the Ubuntu package (`zammad` command available, files in
`/opt/zammad`). Not for Docker installs, which need a derived image instead.

Run everything as `root` (or with `sudo`) on the Zammad server.

## Before you start

- **Version:** `zammad run rails r 'puts Version.get'` must print `7.2.2…`. The package patches
  Zammad internals and is only tested against 7.2.2.
- **Maintenance window:** plan 15–30 minutes. Step 3 rebuilds the web interface's assets (several
  minutes, CPU and memory heavy) and step 4 restarts Zammad; users are interrupted.
- **Backup:** take a database backup and a copy of `/opt/zammad` first, e.g. with Zammad's
  backup script (`/opt/zammad/contrib/backup/zammad_backup.sh`), and check that it finished.
- **Package file:** copy `TicketParticipants-0.5.2.zpm` to the server, e.g. to `/tmp/`. Build it
  as described in `README.md` ("Build & install"). Compare the checksum on the server with the
  one from the build machine: `sha256sum /tmp/TicketParticipants-0.5.2.zpm`.

## Install

```bash
# 1. Install the package files
zammad run rails zammad:package:install /tmp/TicketParticipants-0.5.2.zpm

# 2. + 3. Run the package's database migrations and rebuild the assets
zammad run rails zammad:package:post_install

# 4. Restart Zammad so the new code is loaded
systemctl restart zammad
```

Step 2 creates the table `ticket_participants`, the column `groups.participants_enabled`, the
settings and the overview *Tickets I participate in*. A search index rebuild is not needed:
tickets are indexed again whenever a participant is added.

## Check that it is installed

```bash
zammad run rails r 'puts Package.pluck(:name, :version, :state).inspect'
# => [["TicketParticipants", "0.5.2", "installed"]]

zammad run rails r 'puts ActiveRecord::Base.connection.table_exists?(:ticket_participants), Group.column_names.include?("participants_enabled")'
# => true, true
```

Then, in the browser (reload once with Ctrl+F5):

- *Manage → Groups →* edit a group: the field **Participants** is there.
- *Channels → Email → Settings*: the two **Cc recipients** settings are there.

Nothing changes for users yet: the feature is off for every group.

## Switch it on

1. **Group:** *Manage → Groups →* edit the group *→ Participants: yes*. Only do this for groups
   whose tickets may be shared with additional customers.
2. **Check with one ticket** of that group: the sidebar shows the *Participants* tab; add a
   customer; log in as that customer and confirm they see the ticket and can reply.
3. **Optional – "My Tickets" shows participating tickets too:** *Settings → Ticket → Allow
   expert conditions: yes*, then *Manage → Overviews → My Tickets*, switch the conditions to
   expert mode and combine *Customer is current user* **OR** *Participants is current user*.
   Deactivate *Tickets I participate in* afterwards if you do not want both.
4. **Optional – Cc auto-add:** *Channels → Email → Settings*: enter the allowed email domains
   (your own, e.g. `example.com`) first, then switch *Add Cc recipients as ticket participants*
   on. Only list domains whose users can log in (LDAP/SSO).
5. **Optional – state changes:** triggers offer the email recipient *Participants*. A
   participant who gets a trigger mail for an article gets no second mail from the package.

## Roll back

Switching the feature off for a group is enough to stop it there: participants keep being
stored but have no access and get no mail.

To remove the package completely:

```bash
zammad run rails zammad:package:uninstall TicketParticipants
zammad run rails zammad:package:post_install
systemctl restart zammad
```

**This deletes all participants**: uninstalling drops the table `ticket_participants`, the
column `groups.participants_enabled`, the settings and the shipped overview. A changed *My
Tickets* overview and triggers that use *Participants* must be reverted by hand **before**
uninstalling, or they stop matching anything.

If Zammad does not start after the install, restore the backup of `/opt/zammad` and the
database taken before step 1.

## Updating Zammad later

The package is tied to Zammad 7.2.2. Before any Zammad update:

1. Run the package's specs against the new Zammad version (see `README.md`, "Development").
2. Update Zammad only when they pass, then run:

```bash
zammad run rails zammad:package:reinstall_all
zammad run rails zammad:package:post_install
systemctl restart zammad
```

## Updating the package

Install the newer `.zpm` with the same three install steps and the restart. Existing
participants and settings are kept.
