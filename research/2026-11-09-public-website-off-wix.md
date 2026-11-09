# Moving cyccommunitysailing.org off Wix

CYC Community Sailing Center's public website runs on Wix, at about $408 a year. This looks at what the site does today, what a replacement must do, and how to build it on the platform, with its content edited in Directus beside everything else.

Everything here was read from the live site on 2026-11-09: its sitemaps, every page's HTML, and the content Wix embeds in each page. Nothing came from the Wix dashboard, so a few facts (renewal date, form inboxes, subscriber lists, visitor numbers) need someone with a Wix login.

## What the site is today

### Pages

The sitemaps list 31 live pages, plus 34 old event pages from spring 2025.

| Kind             | URL pattern                                                                                                                   | Count | Where its content comes from                                                                                                          |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Home             | `/`                                                                                                                           | 1     | Fixed layout. Category cards come from the CMS.                                                                                       |
| Program category | `/program-category/<slug>`                                                                                                    | 6     | CMS: Summer Sailing Camps, Adult Sailing Classes, Community Boating, Performance Clinics, Junior Race Teams, Adventure Sailing        |
| Program          | `/program/<slug>`                                                                                                             | 14    | CMS: camps, race teams, clinics, Adult Learn to Sail, Summer Sailfest                                                                 |
| Policy           | `/policy/<slug>`                                                                                                              | 7     | CMS: code of conduct, open boating rules, privacy, weather and air quality, sick policy, cancellation and refunds, non-discrimination |
| Fixed pages      | `/contact-us`, `/our-crew`, `/scholarships`, `/donate`, `/sponsorships`, `/newsletter`, `/calendar`, `/corinthian-yacht-club` | 8     | Mostly typed into the page, with CMS lists on Our Crew, Sponsorships and Scholarships                                                 |
| Old events       | `/event-details/...`                                                                                                          | 34    | Wix Events: 32 Opti Green Team practices from spring 2025, a summer camp event, and an instructor-training form                       |

The menu also links to `/program/420-race-team`, which returns a 404 today.

### Content collections (Wix CMS)

The site is built mostly from eight CMS collections. Wix bound each to a page template.

| Collection         | Items | Fields                                                                                                                                                                              |
| ------------------ | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Program categories | 6     | title, short description, top and bottom rich text, card image, banner image, photo gallery, testimonial                                                                            |
| Programs           | 14    | title, category, card subtitle (often ages), card text, card image, card button text and link, banner image, long rich-text description, registration button text and link, gallery |
| Crew               | 24    | name, title, bio, photo, tags (`staff`, `officers`, `coach`, `instructor`)                                                                                                          |
| FAQs               | 6     | heading and rich text, each shown on one category page or the Scholarships page                                                                                                     |
| Policies           | 7     | title, current text, URL                                                                                                                                                            |
| Policy versions    | 7     | policy, title ("… v1"), effective date, text                                                                                                                                        |
| Sponsor levels     | 6     | name (Admiral … Mate), amount, benefits                                                                                                                                             |
| Sponsors           | 2     | name, logo, link, level                                                                                                                                                             |

Rich text is Wix's own JSON format (Ricos), so migrating it means converting it to HTML or Markdown. The pages use about 120 distinct images.

Some facts are typed by hand into rich text that other systems already hold: camp prices ("$650"), race-team prices, the summer camp week-by-week schedule table, clinic dates, and ages. These go out of date, and they're the same facts Clubspot and the planning catalog hold.

### What the site does, beyond showing pages

- **Registration** is a link out to Clubspot (`theclubspot.com/register/camp/<id>/class`), five camps in all. The site takes no money for programs.
- **Contact form** (first name, last name, email, phone, message) is a Wix form. Submissions go to the Wix inbox, and perhaps email.
- **Newsletter signup** (first name, last name, email, consent box) is a Wix form. Where subscribers end up, and what sends the newsletter, isn't visible from outside.
- **Scholarship application** is a Google Form, through the short link `scholarship.cycsailing.center`.
- **Donations** go to a PayPal hosted button. Checks and asset gifts are described in text.
- **Category pages** say when registration is closed and point to the newsletter ("Sign up for updates").
- **Calendar** shows a "Summer camp registration now open" banner and a Wix Events list that's stale.
- **Footer** on every page: address, phone, email, EIN, policy links, Facebook and Instagram, a map link.

Wix apps installed: CMS, Forms, Events & Tickets, Donations, Members Area (with account, wallet, addresses, subscriptions), Online Programs, Pro Gallery, Weather Forecast, ShoutOut (legacy), Facebook server-side events. Only CMS, Forms, Pro Gallery, and the stale Events list show on public pages. The site also has custom Wix code (Velo) turned on, which can't be read from outside.

No Google Analytics tag is on the pages. Wix's own visitor stats are the only analytics.

### Domain and email

- The domain's DNS is at **Porkbun**, not Wix. Wix only serves the web records: the apex `A` to `185.230.63.107` and `www` as a CNAME to `pointing.wixdns.net`. Leaving Wix doesn't involve a domain transfer.
- Email is Google Workspace (`MX` to Google), with SPF for Google and Amazon SES, a Google site-verification record, and DMARC at `p=none`. There's **no Google DKIM record**, which is worth fixing on its own.
- Platform's `infra` stack already creates a Cloud DNS zone for `cyccommunitysailing.org` (`stacks/infra/dns.ts`). It's inert: Porkbun doesn't delegate to it yet, and isthmia's manual setup lists that as unchecked.

## Requirements

"Must" is needed to turn Wix off. "Should" is wanted in the first release. "Later" can follow.

### Visitors

1. **Must** see the same pages with the same content: home, six program categories, every program, seven policies, Our Crew, Scholarships, Donate, Sponsorships, Contact, Newsletter, and the Corinthian Yacht Club page.
2. **Must** keep every current URL working. Every page in the sitemap answers at the same path. `/event-details/*` redirects to the right program category or the home page. `www` and the bare domain both work, and one redirects to the other.
3. **Must** be able to register: every Register button goes to the same Clubspot link it goes to now.
4. **Must** be able to reach the office: send a message from the site, and see the phone number, email and address.
5. **Must** be able to sign up for news, with consent recorded.
6. **Must** be able to donate through the PayPal link, and read how to give by check or in assets.
7. **Must** be able to apply for a scholarship through the existing form link.
8. **Must** work well on a phone, since most families look on one, and meet WCAG 2.1 AA.
9. **Must** load fast. Pages should be under 1 MB on first load, with images resized for the screen.
10. **Must** read each policy with its effective date, at a URL that doesn't change, since registration forms and emails link to them.
11. **Should** see current dates, prices and open spots on program pages, read from Clubspot through the CRM, so no one types them twice.
12. **Should** see a schedule that's generated, not typed: the summer camp week-by-week table, and a calendar of upcoming sessions in place of the stale Wix Events list.
13. **Later** see past versions of a policy.

### Staff who edit the site

14. **Must** be able to change all content in Directus without a developer: every collection above, the text on fixed pages, the footer, the menu, and a site-wide announcement ("Summer camp registration is open").
15. **Must** be able to upload and replace images in Directus, with alt text.
16. **Must** be able to mark a category or program as open, closed, or coming soon, which changes its button.
17. **Must** be able to hide an item without deleting it.
18. **Must** see their change on the live site within minutes, by pressing a publish button or saving.
19. **Should** be able to preview a change before the public sees it.
20. **Must** have only the access they're given. Editing the website gives no access to CRM records, and the website can never show CRM data that isn't meant for the public.

### Search, sharing, and measurement

21. **Must** keep each page's title and description, and show a picture when a link is shared (Open Graph).
22. **Must** publish `sitemap.xml` and `robots.txt`, and keep Google Search Console verified.
23. **Should** describe the organization, and events, to search engines in structured data.
24. **Should** count visits without cookies or a consent banner.

### Running it

25. **Must** keep working when Directus is down. Visitors keep seeing the last published site.
26. **Must** run on the platform: built and deployed from git, on the GKE cluster, behind the shared Gateway, with its DNS records in Pulumi.
27. **Must** not break email when DNS changes.
28. **Must** keep a copy of everything in Wix before it's cancelled: CMS collections, images at full size, form submissions, contacts and newsletter subscribers, and the custom code.
29. **Must** cut over before the Wix plan renews, and before spring registration opens.
30. **Should** alert the maintainer if the site is down or its certificate is close to expiry.

## Design

### Content model in Directus

Website content gets its own collections, in a new `website` schema package in platform, prefixed `website_`. The public site never reads CRM collections directly, which keeps requirement 20 simple to check.

| Collection                                    | Replaces                    | Notes                                                                                                                                                                                          |
| --------------------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `website_settings` (singleton)                | Footer, menu, typed text    | Address, phone, email, EIN, social links, announcement banner and its link                                                                                                                     |
| `website_pages`                               | Fixed pages                 | Slug, title, description, share image, and rich-text sections. Fixed layouts in code, editable words in Directus.                                                                              |
| `website_categories`                          | Program categories          | Adds `status` (open, closed, coming soon) and sort order                                                                                                                                       |
| `website_programs`                            | Programs                    | Adds `status`, and an optional link to catalog `programs`, many to many, for Clubspot dates and prices later. One page can cover several catalog programs, like Opti Race Team's three fleets. |
| `website_faqs`                                | FAQs                        | Question and answer per row, attached to a category or page, instead of one rich-text blob                                                                                                     |
| `website_profiles`                            | Crew                        | Name, title, bio, photo, groups (staff, board, coaches, instructors). Not linked to CRM `people`, so a public bio can't pull private fields.                                                   |
| `website_policies`, `website_policy_versions` | Policies and versions       | The current version is the latest one whose effective date has passed                                                                                                                          |
| `website_sponsor_levels`, `website_sponsors`  | Sponsor levels and sponsors |                                                                                                                                                                                                |

Images live in a Directus folder, `Website`. The site's build reads with its own Directus user, whose policy can read only `website_*` collections and files in that folder. Staff who edit the site get a `Website Editor` policy, granted through a Google Group like the other policies ([access.md](https://github.com/cyc-seattle/platform/blob/main/docs/access.md)).

This follows the financial model's rule that "website categories stay fields owned by the applications that use them" ([2026-10-18-program-financial-model.md](2026-10-18-program-financial-model.md)).

### How pages are built and served

There are two real choices.

**A. Static site, rebuilt when staff publish (recommended).** An Astro site reads Directus when it builds, and writes plain HTML, CSS and resized images. A Caddy container serves the files, the way sail-team serves its bundle. Visitors never touch Directus.

- Publishing: a Directus Flow adds a **Publish website** button. It calls GitHub's `repository_dispatch`, and an Actions workflow builds the site and deploys the new image. A nightly run picks up Clubspot changes. A publish takes about 3–5 minutes.
- Prod deploys need a maintainer's approval today. A content-only publish needs its own GitHub environment that runs only from `main`, with no reviewer, because it ships the same code with new content.
- Preview: the same build, with drafts included, served at a staff-only address behind Authentik, like the portal.

**B. Server-rendered site.** Astro in server mode, on Node, reads Directus on each request with a short cache. Edits show up within a minute, and Directus's Visual Editor can show the live page while staff edit it.

|                     | A. Static                                   | B. Server-rendered                                                |
| ------------------- | ------------------------------------------- | ----------------------------------------------------------------- |
| Edit to live        | 3–5 minutes, after Publish                  | Under a minute, after Save                                        |
| If Directus is down | Site is fine. Publishing waits.             | Site serves its cache until a pod restarts, then fails            |
| Security surface    | Static files only                           | A Node server to keep patched, with a token that reaches Directus |
| Forms               | Need something else to receive them (below) | The server can receive them                                       |
| Preview             | A second, staff-only build                  | Directus's Visual Editor, live                                    |
| Speed               | Fastest possible                            | Fast, with the cache warm                                         |
| Moving parts        | Flow, Actions workflow, deploy environment  | One server                                                        |

Astro fits here even though platform's UX research rejected it for apps ([2026-11-01-ux-framework.md](2026-11-01-ux-framework.md)): this is a content site with little interactivity, which is what Astro is for. It uses the same Tailwind as sail-team.

Static wins on the things that matter most for a public site: it can't leak data, it survives Directus outages, and there's no server to patch. The cost is a publish step and a separate answer for forms.

### Forms

A static site can't receive a form by itself. Options for the contact form and newsletter signup:

1. **Google Forms behind short links**, as the scholarship form already works. No code. Responses land in a Sheet that emails `info@`. It looks like Google, not the site.
2. **A small form endpoint** in the cluster that writes to a `website_messages` collection and emails `info@` through the Workspace relay Authentik already uses. Needs spam protection, such as a honeypot field and Cloudflare Turnstile (free).
3. **Listmonk's subscribe form**, once Listmonk lands ([cyc-seattle/isthmia#71](https://github.com/cyc-seattle/isthmia/issues/71)). Listmonk takes public signups from any site, with double opt-in.

Recommended: the endpoint (2) for contact, and the newsletter signup on whatever sends the newsletter today until Listmonk replaces it.

### Where the code lives

A new public repo, `cyc-seattle/website`, with its own `stacks/app` like sail-team's. Its audience, framework, and deploy rhythm differ from sail-team's. Repo settings are code in platform's `bootstrap` stack. The `website` schema package lives in platform with the other schemas.

### DNS

Two ways to point the domain at the cluster:

- **Delegate the domain to Cloud DNS** (recommended), so its records are in Pulumi like `cycsail.team`'s. First copy every Porkbun record into the zone (MX, SPF, DMARC, site verification, and any others), compare the two with a script, lower TTLs, then switch name servers at Porkbun. Add Google DKIM while the records are open.
- **Change two records at Porkbun.** Point the apex and `www` at the Gateway's IP. Fewer steps now, but the records stay outside git.

The Gateway needs a Certificate Manager certificate for both names, through a DNS authorization in the external zone, the way `gateway.ts` already does it for `cycsail.team`.

### Migration

A one-off script reads the Wix collections (from the dashboard's CSV export, or the Wix Data API), converts Ricos rich text to HTML, downloads images at full size, and writes it all to Directus. It runs against dev first. Fixed-page text is copied by hand; there are eight pages.

### Phases

1. **Export and DNS prep.** Export everything from Wix (requirement 28). Put the domain's records in the Cloud DNS zone and add DKIM. Delegate the domain while Wix still serves the site, so email is proven before the cutover.
2. **Content model.** The `website` schema and policies in platform, and the migration into dev, then prod.
3. **Site.** The website repo, matching today's pages, deployed to dev.
4. **Publishing.** The Flow, the workflow, and preview.
5. **Forms.**
6. **Cutover.** Point the web records at the Gateway, resubmit the sitemap in Search Console, watch for 404s for two weeks, then cancel Wix.
7. **Later.** Dates, prices, and open spots from Clubspot. A generated calendar and camp schedule. Visit counts.

## Costs

### Running costs

| Item                       | Per year             | Basis                                                                                                                                                                            |
| -------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Wix today                  | **$408**             | Today's bill                                                                                                                                                                     |
| Two Caddy replicas         | ~$45                 | GKE Autopilot bills requested resources. At sail-team's request of 50m CPU and 64 MiB, and about $0.0445 per vCPU-hour and $0.0049 per GiB-hour, one pod is about $1.85 a month. |
| Preview site, one replica  | ~$22                 | Same size                                                                                                                                                                        |
| Form endpoint, one replica | ~$22–45              | Same size, or a bit more memory for Node                                                                                                                                         |
| Cloud DNS zone             | ~$2.40               | $0.20 a month. The zone already exists.                                                                                                                                          |
| Certificate                | $0                   | Certificate Manager's first 100 certificates are free                                                                                                                            |
| Network egress             | ~$10–30              | Depends on traffic, which Wix's stats would show. Assumes 5–20 GB a month of resized images.                                                                                     |
| Builds                     | $0                   | GitHub Actions is free for public repos                                                                                                                                          |
| Image storage              | Pennies              | About 120 images in the existing Directus bucket                                                                                                                                 |
| **New total**              | **~$100–145**        |                                                                                                                                                                                  |
| **Savings**                | **~$265–310 a year** |                                                                                                                                                                                  |

The shared Gateway, the cluster fee, and Cloud SQL are already paid for, so the site adds only its own pods. Option B (server-rendered) would replace the Caddy and preview pods with Node pods of about the same size, so it costs about the same.

### One-off costs

- Building it: about six pull requests across platform and the new repo, written by agents and reviewed by the maintainer.
- Migration and checking every page against Wix: a few hours of a staffer's time.
- Learning a new editor: staff who edit Wix today learn Directus. They'll already use it for the rest of the data.

### The cost that doesn't show on a bill

On Wix, anyone with a login can drag a new section onto a page. Here, words and pictures are editable in Directus, but a new kind of page or a layout change needs a code change. That trade is the main one this move makes.

## Risks

| Risk                                    | Effect                                                          | How to lower it                                                                                                                                                  |
| --------------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Email breaks when DNS moves             | Workspace mail bounces                                          | Delegate in phase 1, before the site moves. Script a record-by-record comparison. Lower TTLs first. Do it off-season.                                            |
| Search ranking drops                    | Fewer families find the site                                    | Keep every URL, redirect old ones, resubmit the sitemap, keep titles and descriptions, watch Search Console                                                      |
| Data lost at cancellation               | Form messages, subscribers, or originals gone                   | Export checklist in phase 1, checked off before cancelling                                                                                                       |
| Private data reaches the public site    | A leak of CRM data                                              | Separate `website_*` collections, a build user that reads only those, profiles not linked to `people`, and a test that the build user can't read CRM collections |
| Crew profiles of minors                 | Youth instructors' names and photos are public, as they are now | Keep first names only for minors, as today. Write down who approves a profile.                                                                                   |
| Only one maintainer knows the code      | Layout changes stall                                            | Plain Astro, documented in the repo's `AGENTS.md`. Content needs no developer.                                                                                   |
| Cluster outage takes the site down      | Site offline                                                    | Two replicas. Cloud CDN could be added later if needed.                                                                                                          |
| Wix renews before cutover               | Another year paid                                               | Know the renewal date. Turn off auto-renew now if the plan allows a monthly extension.                                                                           |
| Unknown Velo code does something needed | A feature quietly disappears                                    | Read the code in the Wix editor during the export                                                                                                                |

## Sources

- The live site, its sitemaps, and DNS, read on 2026-11-09.
- [GKE Autopilot pricing](https://cloud.google.com/kubernetes-engine/pricing), with rates cross-checked against [CloudChipr](https://cloudchipr.com/blog/gke-pricing) and [Finout](https://www.finout.io/blog/gke-pricing-tiers). Check the official page before relying on the figures.
- [Certificate Manager pricing](https://cloud.google.com/certificate-manager/pricing).
- [Wix plan prices](https://www.websitebuilderexpert.com/website-builders/wix/wix-pricing/), for context on what $408 buys.
