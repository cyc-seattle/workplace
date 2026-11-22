# Roadmap

What we're building to help run CYC Community Sailing Center (CSC), and where each piece stands. It's a map of issues across every cyc-seattle repo. An issue is still the source of truth for its own plan. This page only says what exists, what's next, and what's missing.

Update it when an issue opens, closes, or changes priority. Keep each line to one sentence and a link.

**Status:** ✅ shipped · 🚧 in progress · 📋 captured in an issue, not started · 💡 idea, no issue yet

## Dates that drive the work

The 2027 season sets the order. These come from CSC's 2027 strategic plan.

| When        | What has to be ready                                                                          |
| ----------- | --------------------------------------------------------------------------------------------- |
| Dec 1, 2026 | The 2027 Financial Model built in sail-team's Planning, to show the board                     |
| Dec 15      | Board sets 2027 direction: priorities, program schedule and capacity, pricing, capital list   |
| Dec 23      | Website updated with 2027 Summer and Adult Learn to Sail programs and prices                  |
| Jan 2027    | Board approves the 2027 budget. Instructor applications open                                  |
| Feb 2027    | Launch go/no-go: pricing live, registration tested, households told, staff hired, boats ready |
| Feb 22      | Summer camp and spring race team registration opens. Parent roster live for the season        |
| Summer 2027 | Camp runs: coaches need rosters, attendance, and medical information on the dock              |

## Website launch, Dec 23

The public website leaves Wix with the 2027 programs and prices. Its pages come from the platform's own data, and its forms reach tools CSC runs itself ([cyc-seattle/platform#150](https://github.com/cyc-seattle/platform/issues/150)). Everything below is P1. Backups ([cyc-seattle/platform#170](https://github.com/cyc-seattle/platform/issues/170)) aren't needed by then. The preview is at csc-website.web.app.

1. ✅ Crew tracks volunteers and staff, and the site's Our Crew and Meet Our Crew come from it ([cyc-seattle/platform#263](https://github.com/cyc-seattle/platform/issues/263)). Splitting the coaches into doublehanded and singlehanded lists is left.
2. ✅ Program pages keep the site's structure and link to one catalog of offerings, with three team categories ([cyc-seattle/platform#332](https://github.com/cyc-seattle/platform/issues/332)).
3. 🚧 Dates, prices, ages, spots and Register come from the catalog and Clubspot ([cyc-seattle/platform#333](https://github.com/cyc-seattle/platform/issues/333)). The 2027 offerings go in after the Dec 15 vote, then the Clubspot camps are made from them.
4. 🚧 FreeScout runs in prod as the shared inbox ([cyc-seattle/platform#182](https://github.com/cyc-seattle/platform/issues/182)). Left: the inbox@ user, buying its modules, and connecting info@.
5. 🚧 Listmonk runs on the platform for the newsletter ([cyc-seattle/platform#180](https://github.com/cyc-seattle/platform/issues/180)). Left: the AWS account and SES, the DNS move, and importing Mailchimp's list.
6. ✅ The contact form emails info@, and the newsletter form signs up to Listmonk ([cyc-seattle/csc-website#9](https://github.com/cyc-seattle/csc-website/issues/9)). They work on the public domain once DNS moves.
7. 📋 DNS in Cloud DNS with Google DKIM ([cyc-seattle/platform#210](https://github.com/cyc-seattle/platform/issues/210)), then the domain moves to the new site and Wix is cancelled ([cyc-seattle/platform#211](https://github.com/cyc-seattle/platform/issues/211)).
8. ✅ The site publishes on each content change ([cyc-seattle/csc-website#8](https://github.com/cyc-seattle/csc-website/issues/8)). 📋 The Google Analytics tag ([cyc-seattle/csc-website#10](https://github.com/cyc-seattle/csc-website/issues/10)).

## Where things stand

### Planning and finance

- ✅ Planning model, engine, and saved plan versions in Directus ([cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) phase 2).
- ✅ Planning pages in sail-team: each plan's P&L, versions, compare, live draft numbers, reports on real data ([cyc-seattle/sail-team#58](https://github.com/cyc-seattle/sail-team/issues/58), [cyc-seattle/sail-team#67](https://github.com/cyc-seattle/sail-team/pull/67)).
- 🚧 Build the 2027 plan with a planner's agent. This is the MVP's last step ([cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) step 13).
- 🚧 Planning as a set of easier reports ([cyc-seattle/sail-team#63](https://github.com/cyc-seattle/sail-team/issues/63)).
- 📋 Free-text rules and a planning agent that assigns staff and boats ([cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149)).
- 📋 A QuickBooks Online sync into `actuals`, the step before tracking against the plan ([cyc-seattle/platform#274](https://github.com/cyc-seattle/platform/issues/274)).
- 📋 Plan offerings on screen, and track each term against its plan ([cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)). The Tracking page's journeys are written and pending ([cyc-seattle/sail-team#37](https://github.com/cyc-seattle/sail-team/pull/37)).
- 📋 Screens for the rates and shared costs every plan uses ([cyc-seattle/sail-team#31](https://github.com/cyc-seattle/sail-team/issues/31)).
- ✅ Two kinds of planners: Plan Admin sets the rules (Operations Plan, freezing, plans active from a date), and Plan Writers plan programs ([cyc-seattle/platform#251](https://github.com/cyc-seattle/platform/issues/251)).
- 📋 Safety rules, such as coach boats per sailboat, set by the finance committee ([cyc-seattle/platform#249](https://github.com/cyc-seattle/platform/issues/249)).
- ✅ Count boats and coach boats by class from the asset list, by date, with charters by the day ([cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126), which takes in [cyc-seattle/platform#206](https://github.com/cyc-seattle/platform/issues/206)).
- ✅ Allocate for a full program and check capacity at max, with breakeven figures ([cyc-seattle/platform#250](https://github.com/cyc-seattle/platform/issues/250)). A block costs every coach and boat it's given ([cyc-seattle/platform#287](https://github.com/cyc-seattle/platform/issues/287)).
- ✅ One plan model: a Financial Plan holds its plans, freezing is one-way, and notes are short ([cyc-seattle/platform#276](https://github.com/cyc-seattle/platform/issues/276)).
- ✅ The plan list edits in place: Active dates, Freeze, and drafts and archived plans on toggles ([cyc-seattle/sail-team#102](https://github.com/cyc-seattle/sail-team/issues/102)).
- 📋 A draft's numbers are worked out again when a new engine deploys ([cyc-seattle/platform#284](https://github.com/cyc-seattle/platform/issues/284)).
- ✅ Winter programs that cross the year sit whole in one plan ([cyc-seattle/platform#252](https://github.com/cyc-seattle/platform/issues/252)).
- ✅ A P&L per term, and bonuses paid per term ([cyc-seattle/platform#255](https://github.com/cyc-seattle/platform/issues/255)).
- 📋 Show revenue as enrollment × fee, with the card fees families pay shown apart ([cyc-seattle/platform#328](https://github.com/cyc-seattle/platform/issues/328)).
- 📋 Check the 2026 model against the treasurer's workbook ([cyc-seattle/platform#145](https://github.com/cyc-seattle/platform/issues/145)).
- 📋 Planning fixes: [cyc-seattle/platform#208](https://github.com/cyc-seattle/platform/issues/208), [cyc-seattle/platform#139](https://github.com/cyc-seattle/platform/issues/139), [cyc-seattle/platform#138](https://github.com/cyc-seattle/platform/issues/138).

### Households and registrations

- ✅ clubspot-sync copies people, households, registrations, and billing from Clubspot every hour.
- ✅ Household page: a guardian can change names, phones, schools, and whether to share contact details ([cyc-seattle/sail-team#34](https://github.com/cyc-seattle/sail-team/issues/34)).
- ✅ Team rosters, searchable and usable on a phone ([cyc-seattle/sail-team#49](https://github.com/cyc-seattle/sail-team/issues/49)).
- 📋 A household sees its own registrations and medical information ([cyc-seattle/sail-team#40](https://github.com/cyc-seattle/sail-team/issues/40)).
- 📋 Manage waivers from the Household page ([cyc-seattle/sail-team#59](https://github.com/cyc-seattle/sail-team/issues/59)).
- 📋 Preferred names beside legal names ([cyc-seattle/platform#168](https://github.com/cyc-seattle/platform/issues/168)).
- 📋 A staff view of each household, and a list of records to fix ([cyc-seattle/sail-team#29](https://github.com/cyc-seattle/sail-team/issues/29)).
- 📋 See what's missing in each term's data, and fix what the sync can't ([cyc-seattle/platform#127](https://github.com/cyc-seattle/platform/issues/127)).
- 📋 Say once what each program is: level, boat class, kind, and pathway ([cyc-seattle/platform#228](https://github.com/cyc-seattle/platform/issues/228)).
- 📋 Sync fixes: [cyc-seattle/platform#157](https://github.com/cyc-seattle/platform/issues/157) (P1), [cyc-seattle/platform#158](https://github.com/cyc-seattle/platform/issues/158), [cyc-seattle/platform#169](https://github.com/cyc-seattle/platform/issues/169), [cyc-seattle/platform#196](https://github.com/cyc-seattle/platform/issues/196).

### Programs, coaches, and staff

- 📋 Program rosters for coaches: attendance, medical information, and contacts ([cyc-seattle/sail-team#39](https://github.com/cyc-seattle/sail-team/issues/39)).
- 📋 A list of named coaches to assign to offerings, with hours and pay ([cyc-seattle/platform#125](https://github.com/cyc-seattle/platform/issues/125)).
- 📋 Sync Clubspot administrators into Directus ([cyc-seattle/platform#162](https://github.com/cyc-seattle/platform/issues/162)).

### Boats and facilities

- 📋 A register of CSC's boats, charters, damage, and storage, with each program charged for what it uses ([cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126)).

### Calendar and directory

- 📋 Regattas, clinics, and school holidays on one calendar ([cyc-seattle/platform#124](https://github.com/cyc-seattle/platform/issues/124)).
- 📋 The organizations and venues other pages refer to ([cyc-seattle/platform#128](https://github.com/cyc-seattle/platform/issues/128)).

### Marketing, website, and email

- ✅ Short links at cycsailing.center, managed in sail-team ([cyc-seattle/sail-team#55](https://github.com/cyc-seattle/sail-team/issues/55)).
- ✅ gsuite-sync keeps class and program Google Groups up to date from the CRM.
- 🚧 Public website off Wix, built from Directus ([cyc-seattle/platform#150](https://github.com/cyc-seattle/platform/issues/150), [cyc-seattle/platform#210](https://github.com/cyc-seattle/platform/issues/210), [cyc-seattle/platform#211](https://github.com/cyc-seattle/platform/issues/211), [cyc-seattle/csc-website#8](https://github.com/cyc-seattle/csc-website/issues/8), [cyc-seattle/csc-website#9](https://github.com/cyc-seattle/csc-website/issues/9)). See [Website launch, Dec 23](#website-launch-dec-23).
- 📋 Program pages link to the catalog programs they cover ([cyc-seattle/platform#332](https://github.com/cyc-seattle/platform/issues/332), P1), with dates, prices and Register from Clubspot ([cyc-seattle/platform#333](https://github.com/cyc-seattle/platform/issues/333), P1).
- 📋 How the programs are doing, and lists of households to contact ([cyc-seattle/sail-team#28](https://github.com/cyc-seattle/sail-team/issues/28)).
- 📋 Newsletter on Listmonk and Amazon SES, in place of Mailchimp, by Dec 23 ([cyc-seattle/platform#180](https://github.com/cyc-seattle/platform/issues/180), P1).
- 📋 Newsletter subscribers become People in the CRM, after the launch ([cyc-seattle/platform#339](https://github.com/cyc-seattle/platform/issues/339)).
- 📋 Shared inbox on FreeScout, in place of Google's Collaborative Inbox, by Dec 23 ([cyc-seattle/platform#182](https://github.com/cyc-seattle/platform/issues/182), P1).
- 📋 Replace Todoist with a self-hosted task manager ([cyc-seattle/platform#181](https://github.com/cyc-seattle/platform/issues/181)).
- 📋 Read Clubspot's events, messages, e-signatures, and accounting ([cyc-seattle/clubspot-sdk#11](https://github.com/cyc-seattle/clubspot-sdk/issues/11)).

### Volunteers

- 📋 Volunteer sign-ups without signing in, with hours kept for employer matching ([cyc-seattle/sail-team#66](https://github.com/cyc-seattle/sail-team/issues/66)).

### Signing in and access

- ✅ Four roles (Community, Team, Crew, Admin) and groups for extra access ([platform docs/access.md](https://github.com/cyc-seattle/platform/blob/main/docs/access.md)).
- 📋 A clearer sign-in page, with tests so it stops breaking ([cyc-seattle/platform#152](https://github.com/cyc-seattle/platform/issues/152), P1), and Google sign-in fixes ([cyc-seattle/platform#201](https://github.com/cyc-seattle/platform/issues/201), [cyc-seattle/platform#204](https://github.com/cyc-seattle/platform/issues/204)).
- 📋 Crew: volunteers and staff, with committees, positions, terms, qualifications such as first aid and SafeSport, and public profiles for the website, by Dec 23 ([cyc-seattle/platform#263](https://github.com/cyc-seattle/platform/issues/263), P1).
- 📋 Permissions from Crew's committees and positions, kept in sync, after the launch ([cyc-seattle/platform#334](https://github.com/cyc-seattle/platform/issues/334), P2).
- 📋 Links shown only to the people they're for, so role-only tools leave the account menu ([cyc-seattle/platform#272](https://github.com/cyc-seattle/platform/issues/272)).
- 📋 More than one login for a person, such as a personal and a work email, each with the person's access ([cyc-seattle/platform#329](https://github.com/cyc-seattle/platform/issues/329), P2).

### Keeping it running

- 📋 Backups outside Cloud SQL, a restore drill, and uptime checks ([cyc-seattle/platform#170](https://github.com/cyc-seattle/platform/issues/170), P1).
- 🚧 Lower the cloud bill: paid metrics off, pods right-sized, old images deleted, a $150 budget alert, and dev dropped once tests run in CI ([cyc-seattle/platform#171](https://github.com/cyc-seattle/platform/issues/171)).
- 📋 Run the platform on one Talos VM instead of GKE, after the launch work merges ([cyc-seattle/platform#360](https://github.com/cyc-seattle/platform/issues/360), P2).
- 📋 Drop the merge queue: `main` deploys to dev after each merge, integration tests run after each deploy, and only maintainers merge while contributors push branches ([cyc-seattle/platform#280](https://github.com/cyc-seattle/platform/issues/280), P1).
- ✅ A style guide in sail-team's Storybook and a ux-review skill ([cyc-seattle/sail-team#101](https://github.com/cyc-seattle/sail-team/issues/101)), a schema-review skill ([cyc-seattle/platform#275](https://github.com/cyc-seattle/platform/issues/275)), and a docs site for platform ([cyc-seattle/platform#278](https://github.com/cyc-seattle/platform/issues/278)).
- 📋 Engineering upkeep lives in each repo's P2 and P3 issues and isn't listed here.

## Ideas without an issue yet

These came from comparing the issues above with how CSC actually runs: the 2027 strategic plan's milestones, the monthly finance checklist, the season's household emails, and boat and trailer upkeep. Each one builds on data the platform already has.

- ✅ A fast merge queue: the queue only deploys to dev, a nightly run tests it and files an issue on failure, and both repos take turns on dev ([cyc-seattle/platform#161](https://github.com/cyc-seattle/platform/issues/161), P1; [cyc-seattle/.github#34](https://github.com/cyc-seattle/.github/issues/34), [cyc-seattle/.github#35](https://github.com/cyc-seattle/.github/issues/35)).

### Before registration opens (Feb 2027)

- 💡 **Season launch checklist.** One page per program per season: prices approved, website updated, Clubspot registration set up and tested, households told, staff hired, boats ready. The February go/no-go becomes a page the board can read, instead of a meeting full of status updates. It's also a template that makes each season repeatable without the chair.
- 💡 **Scholarships.** An application form, decisions made against a written method, and awards tracked against the scholarship share in the plan. Today requests are reviewed by hand each week, and the website's scholarship page is hard to find.
- 💡 **Scheduled emails to households.** Emails sent on a schedule from registrations: two weeks before a session, the week before, and what to bring. Today each camp week's emails are a separate to-do. This needs the Listmonk and SES work in [cyc-seattle/platform#180](https://github.com/cyc-seattle/platform/issues/180), which is only about the newsletter today.
- 💡 **Where registrations came from.** Tag short links and QR codes by campaign, and count the registrations each one led to. The monthly Google Ads review then has real numbers behind it.

### Before summer camp

- 💡 **Safety records.** Incident and near-miss reports, a daily log of who went out on which boats and the weather call, and a flag on the coach roster for sailors with rescue medication (EpiPen, inhaler). It fits beside [cyc-seattle/sail-team#39](https://github.com/cyc-seattle/sail-team/issues/39).
- 💡 **Hiring instructors.** Applications, offers, visa deadlines, and certifications in one place, which become the coach list in [cyc-seattle/platform#125](https://github.com/cyc-seattle/platform/issues/125) once someone is hired. Visa delays caused the most slippage in 2026.
- 💡 **Boat repairs and readiness.** A repair list for each boat, pre-season checks, a parts shopping list, and trailer titles and registrations with renewal dates. [cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126) records the boats and their cost, but not the work to keep them sailing.
- 💡 **Enrollment against plan.** Each offering's sign-ups and waitlist compared with the plan's expected sailors, with a note when one fills early or is short a few weeks out. Program directors can then add a section or push marketing in time. [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) tracks money against plan, not sign-ups.

### For the board and the year

- 💡 **Monthly close and board report.** The monthly finance checklist (Clubspot payouts, bank, PayPal and Venmo, scholarships, donations, B&O tax) as a guided page that records actuals, then produces budget vs. actuals and the board report. Actuals are designed in the planning model but not built.
- 💡 **Operating goals.** The goals spreadsheet each program updates monthly, kept in the platform with owners and dates, and shown on the board report.
- 💡 **Program reviews.** A short survey to households after each session, and each season's "high tide, low tide, asks" review stored with that season's numbers. Next year's plan can start from them.
- 💡 **Donations and grants.** Donors, gifts, grant deadlines, and employer matches in one place. The planning model already shows fundraising and capital separately, but nothing records where the money comes from. Volunteer hours in [cyc-seattle/sail-team#66](https://github.com/cyc-seattle/sail-team/issues/66) feed employer matches too.
- 💡 **Who does what.** A list of every recurring job (check info@, update the mailing list, reconcile the bank, send the community meeting invite) with its owner and how often it happens. The 2027 plan's goal is to make the chair role lighter, and this shows what has to be handed off. It could be the first use of the Todoist replacement.

## Clean-up found while researching

- [cyc-seattle/sail-team#1](https://github.com/cyc-seattle/sail-team/issues/1) has steps 4–17 unchecked, though Planning and Rosters have shipped. Check them off or close it.
- [cyc-seattle/sail-team#65](https://github.com/cyc-seattle/sail-team/issues/65) is from the isthmia era: it describes the portal and Authentik groups. Team rosters shipped in [cyc-seattle/sail-team#38](https://github.com/cyc-seattle/sail-team/pull/38) and [cyc-seattle/sail-team#49](https://github.com/cyc-seattle/sail-team/issues/49). Close it or rewrite it for school rosters.
- [cyc-seattle/platform#181](https://github.com/cyc-seattle/platform/issues/181) still depends on isthmia issues and mentions oauth2-proxy. platform's `docs/architecture.md` still links the isthmia copies under "Later".
- Most feature issues have no P0–P3 label, so priority only shows for engineering upkeep. Labeling the features above would make this page's order match the labels.
