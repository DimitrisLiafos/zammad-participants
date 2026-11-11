# Zammad Ticket Participants

Jira-style participants for Zammad tickets: additional customers who get the same access as the
ticket customer and are notified about every public reply.

Targets **Zammad 7.2.2**. The package prepends Zammad internals (see below), so every Zammad
update must be re-verified by running the specs against the new version before upgrading.

## Behavior

- **Access** – a participant has exactly the ticket customer's access: sees the ticket and its
  public articles, may reply, may reopen as far as the group's follow-up setting allows. Internal
  articles and agent-only fields stay hidden.
- **Managing** – only agents with `change` access to the ticket's group add or remove
  participants. A participant may remove only themselves (which also removes their access).
  Participants must be customers (not agents) and not the ticket customer.
- **Notifications** – every new non-internal article (email, note, phone, web, from anyone)
  mails all participants, except:
  - the author of the article,
  - the ticket customer (triggers already handle them),
  - addresses already in From/To/Cc of the article,
  - addresses mailed by a trigger/scheduler/macro article sent after it,
  - inactive users and users whose mail delivery recently failed.

  Each address is mailed once. Mails go through the notification channel with `Reply-To` set to
  the group's email address, and the ticket hook in the subject, so replies become follow-ups.
- **Merge** – participants of the merged ticket move to the target ticket (duplicates and the
  target's customer are dropped). **They thereby gain access to the target ticket's complete
  public history**, without anyone adding them there explicitly. This is intended; the agent who
  merges is responsible for it. Remove participants before merging if they must not see the
  target ticket.
- **Triggers** – triggers and schedulers offer *Participants* as an email recipient. Use them
  for state changes and other non-article events; the package itself only notifies replies.
- **Cc auto-add** – optional (*Channels → Email → Settings*, off by default): Cc recipients of
  incoming customer emails become participants if their email domain is in the allowed list.
  Without a listed domain nobody is added; subdomains must be listed separately. On follow-ups
  only a sender who already has access to the ticket (its customer, a participant, a member of
  its shared organization) can bring in others. Zammad does not verify the `From` address of
  an email, so somebody who forges the address of such a sender can add Cc recipients of an
  allowed domain; keep the domain list to domains you trust.
- **Leaving** – a participant removes themselves in the ticket (API today, UI planned) or asks
  an agent. Emails deliberately carry no leave link: a link that works without login would end
  up in the ticket whenever a reply quotes the email, where others could use it.
  **This assumes participants can log in.** Zammad creates the users for Cc recipients without
  a password. Where the allowed domains are covered by a login source such as LDAP or SSO they
  can sign in right away; otherwise they have to use *Forgot password* first, or ask an agent
  to remove them. Limit the allowed domains accordingly.
- **API** – `GET|POST /api/v1/tickets/:ticket_id/participants`,
  `DELETE /api/v1/tickets/:ticket_id/participants/:id`. Email addresses of participants are
  only returned to agents of the ticket.
- **Search** – participants find their tickets via Elasticsearch (`participant_ids`).

## Patched internals

| Target | Why |
|---|---|
| `TicketPolicy#customer_access?` (private) | grants customer access to participants |
| `TicketPolicy::BaseScope#resolve` | adds participating tickets to all ticket scopes |
| `Ticket.search_query_extension` | adds participating tickets to the customer ES filter |
| `Ticket#search_index_attribute_lookup` | indexes `participant_ids` |
| `Ticket#merge_to` | moves participants on merge |
| `User` `before_destroy` | removes participations before core's reference check |
| `Ticket::PerformChanges::Action::NotificationEmail#recipients_by_type` (private) | adds the *Participants* trigger recipient |
| `App.UiElement.ApplicationAction.recpientVariables` (CoffeeScript) | offers it in the trigger editor |

## Development

Link the package into a Zammad 7.2.2 checkout (e.g. inside the devcontainer, where
`/workspaces` is the parent directory of both checkouts):

```bash
cd /workspaces/zammad-7.2.2
bundle exec rails r 'Package.link("/workspaces/zammad-participants")'
RAILS_ENV=test bundle exec rails zammad:package:migrate   # devcontainer sets CI_SKIP_DB_RESET
bundle exec rails zammad:package:migrate                  # development database
```

Run the specs:

```bash
RAILS_ENV=test VITE_TEST_MODE=1 bundle exec rspec \
  spec/models/ticket/participant_spec.rb \
  spec/models/ticket_participants \
  spec/models/channel/filter/ticket_participants_cc_spec.rb \
  spec/models/transaction/ticket_participant_notification_spec.rb \
  spec/policies/ticket/participant_policy_spec.rb \
  spec/policies/ticket_policy/participant_access_spec.rb \
  spec/requests/ticket_participants_spec.rb
```

Elasticsearch examples are tagged `searchindex: true` and need `ES_URL`.

## Build & install

Build the installable `.zpm` (file contents embedded as Base64) outside the package directory,
so the result is not linked into Zammad:

```bash
python3 -c 'import json,base64,sys; p=json.load(open("TicketParticipants.szpm"))
for f in p["files"]: f["content"]=base64.b64encode(open(f["location"],"rb").read()).decode()
json.dump(p, open(sys.argv[1],"w"), indent=2)' ../TicketParticipants-0.2.0.zpm
```

Install it via *Admin → System → Packages*, or:

```bash
zammad run rails r 'Package.install(file: "/path/to/TicketParticipants-0.2.0.zpm")'
zammad run rails zammad:package:migrate
zammad run rails zammad:package:post_install
zammad run rake zammad:searchindex:rebuild
```

Restart Zammad afterwards (initializers are loaded on boot).
