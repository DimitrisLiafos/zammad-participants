# Staging rehearsal: test the install on a clone of the production VM

Rehearse `README.production.md` on a clone of the production server (Ubuntu package install
of Zammad running in a virtual machine) before touching production. A rehearsal on a clone
catches what the specs cannot: differences between the development setup and a package
install, and conflicts with your own configuration (see "No ticket field named
`participants`" in the runbook).

**The clone is a full copy of production and believes it is production.** Unless it is
isolated before it gets network access, it will:

- fetch mail from the real mailboxes (fetched mails are removed there and never reach prod),
- send notifications and trigger mails to real customers and agents,
- write to a shared Elasticsearch index, run LDAP sync, fire webhooks,
- run the package migrations on the production database, if PostgreSQL is not local,
- do whatever else the server does outside Zammad under the production identity: rotate a
  domain machine password, write backups to a shared target, report to monitoring.

Follow the steps in order. Do not connect the network before step 6.

Web consoles of hypervisors often paste unreliably (multi-line text may arrive as one line).
The commands of steps 1–5 are kept short to type them by hand; use SSH from step 6 on.

## 0. Clone the VM

Clone the VM with your hypervisor's clone function, or copy the disk of the powered-off VM
into a new VM. Make sure the clone's network adapter is **not connected at power on**. If
there is an isolated or test network, attach the clone to it.

## 1. First boot: console only, no network

Zammad starts at boot but cannot reach anything (failing mail fetches or token refreshes in the
log are expected). Stop it:

```bash
sudo systemctl stop zammad
sudo systemctl disable zammad
```

## 2. Confirm nothing external is shared

```bash
sudo grep -A8 production: /opt/zammad/config/database.yml
sudo zammad run rails r 'puts Setting.get("es_url")'
```

`database.yml` must have no `host:` (local socket), `localhost` or `127.0.0.1`; `es_url` must
point to `localhost`. If either points to another host, **stop**: the clone would work on
production data.

Note the FQDN as well, it is needed in step 7:

```bash
sudo zammad run rails r 'puts Setting.get("fqdn")'
```

## 3. Make Zammad harmless

One command per line:

```bash
sudo zammad run rails r 'Channel.where(active: true).each { |c| puts "off: #{c.id} #{c.area}"; c.update!(active: false) }'
sudo zammad run rails r 'Webhook.update_all(active: false)'
sudo zammad run rails r 'Setting.set("ldap_integration", false)'
sudo zammad run rails r 'puts Channel.where(active: true).count'
```

The last command must print `0`. Channels of cloud mail providers can talk to the provider
over HTTPS, which step 5 allows. If you use them, also block their endpoints on the clone,
for example:

```bash
echo '0.0.0.0 graph.microsoft.com login.microsoftonline.com outlook.office365.com smtp.office365.com' | sudo tee -a /etc/hosts
echo '0.0.0.0 oauth2.googleapis.com imap.gmail.com smtp.gmail.com' | sudo tee -a /etc/hosts
```

## 4. Give the clone its own identity

```bash
sudo hostnamectl set-hostname <prod-hostname>-test
sudo nano /etc/hosts
sudo nano /etc/netplan/<file>.yaml
sudo rm /etc/machine-id
sudo systemd-machine-id-setup
```

- `/etc/hosts`: point the production FQDN and short name to `127.0.0.1`, add a line
  `<test-IP> <prod-hostname>-test.<domain> <prod-hostname>-test`.
- netplan: replace the production IP with a free test IP (check from another machine that it
  does not answer a ping). Remove a `macaddress:` match if there is one: the clone usually gets
  a new MAC. If the file is `50-cloud-init.yaml`, disable cloud-init's network config first
  (`echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`).
- Do not run `netplan apply` yet.

## 5. Firewall: block all outbound traffic

In this order (the `ACCEPT` rules before the `DROP` policy). It allows only loopback and
replies to incoming connections, i.e. your SSH session:

```bash
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT
sudo iptables -P OUTPUT DROP
sudo ip6tables -A OUTPUT -o lo -j ACCEPT
sudo ip6tables -P OUTPUT DROP
sudo iptables -S OUTPUT
```

Check the output: it must say `-o lo`, not `-o -lo`. A wrong loopback rule blocks Zammad's own
connections to Elasticsearch and Redis.

These rules are **not persistent**. After a reboot of the clone, enter them again before
starting Zammad (it stays disabled, so it does not start on its own).

## 6. Connect the network

```bash
sudo netplan apply
```

Connect the clone's network adapter in the hypervisor. `ip -br addr` shows the test IP. From
now on, work over SSH: `ssh <user>@<test-IP>`. Then allow DNS and HTTPS, which `post_install`
needs for the npm registry, and test:

```bash
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT && sudo iptables -A OUTPUT -p tcp -m multiport --dports 53,443 -j ACCEPT
curl -sI https://registry.npmjs.org | head -1; nc -zvw3 smtp.example.com 587
```

Expected: `HTTP/2 200`, then a failing SMTP connection (use your real mail server's name).
Then start Zammad:

```bash
sudo systemctl start zammad
```

## 7. Rehearse the runbook

Copy the `.zpm` with `scp` and follow `README.production.md` completely: checks, install,
verification, switching it on for one group, the test with a customer login.

- **Browser:** nginx and Zammad only answer to the production FQDN from step 2 (another name
  shows the nginx default page, and live updates fail on a mismatched origin). Add
  `<test-IP> <prod-fqdn>` to the hosts file **of your workstation** (`/etc/hosts`, or
  `C:\Windows\System32\drivers\etc\hosts` on Windows; flush the DNS cache and restart the
  browser). **Remove the entry afterwards**, or you keep landing on the clone.
- **Logins:** if users log in via LDAP or SSO, they cannot log in on the isolated clone. Give
  the agent and the test customer a local password on the clone (it only exists there):

  ```bash
  sudo zammad run rails r 'u = User.find_by(login: "LOGIN"); u.update!(password: "<temporary password>", login_failed: 0)'
  ```

- **Customer test:** use a customer outside the ticket's organization, see the runbook.
- **Mail** cannot be tested: `Channel defined for email address id '…' is not active!` in the
  log is expected.
- **Log:** check for errors after each step:

  ```bash
  sudo grep -E 'ERROR|FATAL' /opt/zammad/log/production.log | tail -5 | cut -c1-200
  ```

Time `zammad:package:post_install` (`time sudo zammad run rake zammad:package:post_install`):
together with the restarts it gives the real maintenance window.

## 8. Clean up

Remove the hosts file entry on your workstation, power off the clone and delete it.
