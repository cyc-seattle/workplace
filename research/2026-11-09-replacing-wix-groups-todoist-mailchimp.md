# Replacing Wix, Google Groups, Todoist, and Mailchimp

CYC Community Sailing Center uses Google Workspace for email and documents, Wix for its website, Google Groups for email lists, Mailchimp for its newsletter, and Todoist for tasks and projects. Workspace stays. This looks at self-hosted replacements for the other four, with keeping each one as an option, as of November 2026.

Three issues already plan part of this: [cyc-seattle/platform#150](https://github.com/cyc-seattle/platform/issues/150) (the website), [cyc-seattle/isthmia#68](https://github.com/cyc-seattle/isthmia/issues/68) (Todoist), and [cyc-seattle/isthmia#71](https://github.com/cyc-seattle/isthmia/issues/71) (Listmonk for the newsletter). The website has its own research, [2026-11-09-public-website-off-wix.md](2026-11-09-public-website-off-wix.md).

## Recommendation

| Today         | Recommendation                                                                                       |
| ------------- | ---------------------------------------------------------------------------------------------------- |
| Wix           | Replace, with a static site built from Directus content (platform#150)                               |
| Google Groups | Keep. Move one-way announcements to the newsletter tool, and leave Groups for discussion and sharing |
| Mailchimp     | Replace with Listmonk, sending through Amazon SES (isthmia#71)                                       |
| Todoist       | Replace with Vikunja, if the people using Todoist can live without a native phone app                |

## What every self-hosted app costs

Each app here would run on the platform: a container on the GKE cluster, a database on the Cloud SQL instance, and sign-in through Authentik. The cluster, the Gateway, and Cloud SQL are already paid for, so a small app adds only its own pods, about $2–5 a month each at sail-team's size, more for heavier apps.

The larger cost is time. Each app is another thing to upgrade, back up, and watch for security fixes. Vikunja alone had several published vulnerabilities in 2026, fixed in 2.3.0. Prefer apps that:

- store their data in **Postgres**, so they share the Cloud SQL instance and its backups. Ghost, WordPress, and Mautic need MySQL, which would mean a second database server.
- support **OpenID Connect (OIDC) sign-in in the free version**, so people sign in through Authentik. Plane, Planka, and OpenProject now charge for it.
- are **open source under a standard license**, not "fair-code" or source-available.

### Email from the platform

Google Cloud blocks outgoing connections on port 25, so nothing on the cluster can send mail directly. Mail goes out through a relay on port 587 or 465: the Workspace SMTP relay (the platform's NAT address is already registered with it) or Amazon SES. Workspace's relay has daily limits per user and isn't meant for bulk sending, so a newsletter needs SES or another bulk sender. SES costs about $0.10 per 1,000 emails.

Receiving mail is harder. An app that receives mail directly (Mailman) needs its own mail domain, an MX record, and a TCP load balancer on port 25, about $18 a month. An app that reads a mailbox (Discourse, FreeScout) can poll a Workspace mailbox instead.

## Website (Wix)

The full analysis is in [2026-11-09-public-website-off-wix.md](2026-11-09-public-website-off-wix.md). In short:

| Option                                | For                                                                                                                                                                      | Against                                                                                                                                                     |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep Wix** (~$408 a year)           | Anyone with a login can change a page's layout. Nothing to run.                                                                                                          | Prices, dates, and the camp schedule are typed in twice, once in Wix and once in Clubspot and the catalog. Content sits apart from everything else.         |
| **Static site from Directus** (Astro) | Staff edit content in Directus with the rest of the data. Schedules and prices come from the catalog. Static files keep working when Directus is down. ~$100–145 a year. | A new kind of page or a layout change needs a developer. Staff learn Directus's editor.                                                                     |
| **WordPress**                         | The editor most volunteers already know. Thousands of themes and plugins.                                                                                                | MySQL only, so a second database. Plugins are the usual way WordPress sites get hacked, and need constant updates. Content is separate from Directus again. |
| **Ghost**                             | Clean editor, and a built-in newsletter, so it could replace Mailchimp too                                                                                               | Production needs MySQL 8. Self-hosted newsletters send only through Mailgun. Built for blogs and newsletters, not program catalogs.                         |
| **Payload CMS or Decap CMS**          | Payload is on Postgres and gives developers full control. Decap keeps content in git, with no database.                                                                  | Payload is a second content system next to Directus. Decap's editors need GitHub accounts, or a gateway in front.                                           |

The static site from Directus is still the best fit, because the site's main content (programs, prices, schedules) already lives in the catalog.

## Email lists (Google Groups)

Google Groups does more here than send email. gsuite-sync keeps program groups' membership in step with the CRM every hour, nests class groups under program groups, and uses senders groups so announcements reach every class ([google-groups-nesting.md](https://github.com/cyc-seattle/platform/blob/main/docs/google-groups-nesting.md)). Groups are also how Drive folders, shared calendars, and Sites are shared. A self-hosted list server can replace the email, but not the sharing, so the groups would stay in Workspace either way.

| Option                                              | For                                                                                                                                                                              | Against                                                                                                                                                                                                                                                              |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep Google Groups**                              | Free with Workspace. Already synced from the CRM. Same groups share Drive, Calendar, and Sites. Google handles delivery and spam. Families already use it.                       | Nesting rules surprise people ([cyc-seattle/isthmia#158](https://github.com/cyc-seattle/isthmia/issues/158)). The web interface is dated. Announcements and discussion share one channel.                                                                            |
| **Mailman 3** (GPL, Postgres)                       | The standard open-source list server. Archives (HyperKitty), moderation, digests. No per-member cost.                                                                            | Needs a mail server (Postfix) beside it, an MX record on a new domain such as `lists.cyccommunitysailing.org`, a port 25 load balancer (~$18 a month), and a relay for sending. No official Kubernetes setup. Groups still needed for sharing, so two sets of lists. |
| **Discourse** (GPL, Postgres and Redis)             | A forum that also works by email: each post can arrive as an email, and replies by email become posts. Reads incoming mail from a mailbox, so no MX needed. Good for discussion. | Heavy: about 2 GB of memory, Redis, and its own Docker setup. Families must learn a forum. Its OIDC plugin works, but the official install expects its own launcher, not Kubernetes.                                                                                 |
| **Listmonk for announcements, Groups for the rest** | Splits one-way announcements (newsletter-style, with unsubscribe and stats) from discussion and sharing. isthmia#71 already plans this.                                          | Two places to send to. Staff have to know which to use.                                                                                                                                                                                                              |

Keep Google Groups. The reason to leave would be the email itself, and the self-hosted options bring a mail server and a second set of lists to keep in step, while Groups stays for sharing anyway. Moving announcements to Listmonk fixes the part that hurts most.

## Newsletter (Mailchimp)

Mailchimp's free plan dropped to 250 contacts and 500 sends a month in early 2026. Paid plans are priced by contacts, counting unsubscribed ones and duplicates across audiences, and the nonprofit discount is 15%. The bill depends on the list's size, which isn't known here.

| Option                        | For                                                                                                                                                                                                    | Against                                                                                                                                                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep Mailchimp**            | Drag-and-drop editor and templates staff know. Mailchimp handles deliverability, bounces, and spam rules. Nothing to run.                                                                              | Cost grows with the list. The list is kept apart from the CRM and synced by hand.                                                                                                                                    |
| **Listmonk** (AGPL, Postgres) | One small Go program on Postgres. OIDC sign-in, with roles and per-list permissions, since v5. Lists can be filled from the CRM by SQL or its API. Sends through SES for about $0.10 per 1,000 emails. | The editor is plainer than Mailchimp's: rich text, HTML, Markdown, and a visual builder, but fewer templates. CYC owns deliverability: SPF, DKIM and DMARC, bounce handling through SES, and its sending reputation. |
| **Keila** (AGPL, Postgres)    | Similar to Listmonk, with a friendlier editor                                                                                                                                                          | Smaller project, fewer contributors. Written in Elixir, which nobody here knows.                                                                                                                                     |
| **Mautic** (GPL)              | Full marketing automation: journeys, scoring, landing pages                                                                                                                                            | MySQL only. Much heavier, and more than a newsletter needs.                                                                                                                                                          |
| **Ghost newsletters**         | Website and newsletter in one                                                                                                                                                                          | Self-hosted Ghost sends only through Mailgun, and needs MySQL 8. Only makes sense if Ghost also runs the website, which it shouldn't (above).                                                                        |

Listmonk is the best fit. It runs on the Cloud SQL instance and reads lists straight from the CRM, so "every family registered for summer camp" becomes a query, not an export. Before switching, set up SPF, DKIM and DMARC for the sending domain and warm the domain up with SES. The website's newsletter signup form should then post to Listmonk.

## Tasks and projects (Todoist)

The only integration was [cyc-seattle/todo-manager](https://github.com/cyc-seattle/todo-manager), which made Todoist projects from Clubspot camp sessions, and it's archived. Todoist Business costs about $8 per user a month, billed yearly, after a late-2025 price rise. Nothing confirms a nonprofit discount.

| Option                       | For                                                                                                                                                                                                            | Against                                                                                                                                                                 |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep Todoist**             | Excellent phone and desktop apps, quick capture, reminders that just work. Nothing to run.                                                                                                                     | Paid per user, and not behind CYC's sign-in, so removing someone is a separate step. Nothing links tasks to programs or camps.                                          |
| **Vikunja** (AGPL, Postgres) | The closest to Todoist: projects, lists, kanban, table and Gantt views, teams, sharing by link, CalDAV, and quick-add text like Todoist's. Free OIDC sign-in. Imports from Todoist directly. Small Go program. | No official phone app: a web app you install from the browser, plus third-party apps. Several security fixes in 2026, so it needs prompt upgrades. One main maintainer. |
| **Plane** (AGPL, Postgres)   | Polished, Linear-style projects, cycles, and docs                                                                                                                                                              | OIDC sign-in needs a paid self-hosted plan with a 10-seat minimum. Heavy: Postgres, Redis, RabbitMQ, and object storage. Built for software teams.                      |
| **OpenProject** (GPL)        | Mature project management: Gantt, time tracking, budgets                                                                                                                                                       | OIDC is an Enterprise add-on. Heavy, and a lot more than a task list.                                                                                                   |
| **Planka**                   | Simple Trello-style boards                                                                                                                                                                                     | "Fair-code" license, not open source. OIDC moved to the paid Pro tier in 2.2.0.                                                                                         |
| **Kanboard** (MIT)           | Tiny, stable, Postgres                                                                                                                                                                                         | Dated interface, OIDC through a plugin, little active development                                                                                                       |
| **Google Tasks, or Sheets**  | Already in Workspace, free, nothing to run                                                                                                                                                                     | Too thin for shared projects: no real assignment, views, or project history                                                                                             |

Vikunja is the only option that's open source, light, Postgres-backed, and free to sign in through Authentik. The question is whether the people who use Todoist will accept a web app on their phones. Have them try a Vikunja instance with an imported copy of their projects for a few weeks before deciding.

## Order

1. **Newsletter.** Lowest risk, and it unblocks the website's signup form. Set up SES and domain authentication, deploy Listmonk, import Mailchimp's subscribers with their consent records, and send one issue from both before cancelling.
2. **Website**, as platform#150 plans, before the Wix plan renews.
3. **Todoist**, after a trial with its real users.
4. **Google Groups** stays. Revisit only if Listmonk doesn't solve the announcement problem.

## Open questions

1. How many subscribers does the Mailchimp list have, and which plan is it on? That sets what Mailchimp costs and how fast SES needs to warm up.
2. Who uses Todoist, and how many seats are paid? Do they rely on its phone apps?
3. Does anyone use Google Groups' web archive or discussion, or only the email?
4. Is anyone willing to own upgrades for each new app, or should the platform's renovate setup and CI cover them?

## Sources

- [Vikunja 2.3.0 changelog](https://vikunja.io/changelog/whats-new-in-vikunja-2.3.0/) and [Vikunja vs Planka](https://vikunja.io/compare/planka)
- [Plane editions](https://developers.plane.so/self-hosting/editions-and-versions), [Plane seat minimums](https://forum.plane.so/t/new-seat-minimums-on-self-hosted-commercial-and-air-gapped-starting-april-24/96), and [Authentik's Plane guide](https://integrations.goauthentik.io/chat-communication-collaboration/plane/)
- [Planka: OIDC moves to Pro](https://github.com/plankanban/planka/issues/1754) and [About Planka](https://docs.planka.cloud/docs/about-planka)
- [OpenProject: OpenID providers (Enterprise add-on)](https://www.openproject.org/docs/system-admin-guide/authentication/openid-providers/)
- [Listmonk](https://www.listmonk.app), [Listmonk OIDC](https://listmonk.app/docs/oidc/), and [Listmonk v5.1.0](https://newreleases.io/project/github/knadh/listmonk/release/v5.1.0)
- [Ghost newsletters](https://docs.ghost.org/newsletters)
- [Mailman 3 in Docker](https://gnu-mailman.readthedocs.io/en/latest/install/docker.html)
- [Discourse for nonprofits](https://meta.discourse.org/t/discourse-installs-for-non-profit-and-education/12878)
- [Mailchimp pricing in 2026](https://mailmeteor.com/blog/mailchimp-pricing) and [Mailchimp nonprofit pricing](https://blog.groupmail.io/mailchimp-nonprofit-pricing/)
- [Todoist pricing in 2026](https://routine.co/blog/posts/todoist-pricing)
- [Amazon SES pricing](https://aws.amazon.com/ses/pricing/)
- [Google Cloud: sending email from an instance](https://cloud.google.com/compute/docs/tutorials/sending-mail)
