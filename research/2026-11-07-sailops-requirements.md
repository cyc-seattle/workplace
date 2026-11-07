# Requirements from SailOps

SailOps is the live version of project-two, another volunteer's staff app for a youth sailing program. [2026-10-19-erp-and-frontend.md](2026-10-19-erp-and-frontend.md) and [2026-10-18-program-financial-model.md](2026-10-18-program-financial-model.md) say what we already took from its code. This file goes tab by tab through what it does and writes each tab down as needs a CSC staffer has, not as SailOps's screens. For each tab it says what our platform and sail-team already cover.

Terms follow ours. A dated practice, race day or travel day is an **activity**. One program sold for a dated period is an **offering**. The year's whole plan, every program area and the Operations Plan together, is the **Financial Plan**. SailOps groups by "season" (a year and a term) and calls a planned offering a "program plan". Its "club" is whichever organization uses it. Below, that's CSC.

## How this was made

- SailOps's latest source (the project-two repository as of 2026-11-06) and its requirements document.
- The live site on 2026-11-07, signed in as a club admin, looking only. Every tab and sub-tab a club admin sees matched the source. Settings, Directory, Users and Design send a club admin back to Sources, so those four sections come from the source alone.
- Prod is set up for CSC: its organization is CSC, and its cost structure is CYC and CSC's.
- Nothing here comes from SailOps's data: no names, figures or counts. Rule constants (a 40-hour week, a minimum of 5 entrants) are the app's settings, not data.

## The tabs

SailOps's top navigation, in order: **Marketing, Families, Programs, Calendar, Staff, Inventory, Sources**, then **Settings, Directory, Users** and **Design**, which only super admins see. The app opens on Sources. Two roles exist: a super admin, and a "club admin" scoped to their own organization's programs. Sign-in is Google only.

## What platform and sail-team cover today

- **platform** ([cyc-seattle/platform](https://github.com/cyc-seattle/platform)) is the backend: Directus, the schemas, the syncs and the planning engine.
  - The CRM ([docs/crm-schema.md](https://github.com/cyc-seattle/platform/blob/main/docs/crm-schema.md)): people, guardians and emergency contacts, offerings and registrations. clubspot-sync fills it from Clubspot's API every hour, billing included ([docs/syncs.md](https://github.com/cyc-seattle/platform/blob/main/docs/syncs.md)).
  - Planning ([docs/planning-schema.md](https://github.com/cyc-seattle/platform/blob/main/docs/planning-schema.md), [docs/planning-engine.md](https://github.com/cyc-seattle/platform/blob/main/docs/planning-engine.md)): the catalog, program area plans, the Operations Plan, saved versions, and the engine that calculates one year's P&L. Actuals, scenarios and baselines are designed but not built.
  - Access ([docs/access.md](https://github.com/cyc-seattle/platform/blob/main/docs/access.md)): four roles (Community, Team, Crew, Admin) and groups. Sign-in is through Authentik.
- **sail-team** ([cyc-seattle/sail-team#1](https://github.com/cyc-seattle/sail-team/issues/1)) is the staff and family web app. Today it has Plans (each plan's P&L, versions, and the year's Financial Plan) and Rosters.
- Planners build plans through their own AI over Directus's MCP ([cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6), decision 24). No staff screen edits a plan yet.

| Tab       | Covered today                                                                                                           |
| --------- | ----------------------------------------------------------------------------------------------------------------------- |
| Marketing | No. The registration and billing data it needs is in the CRM.                                                           |
| Families  | Partly. People and guardians are in the CRM, merged by hand in the Data Studio. No family view, scores or review queue. |
| Programs  | Partly. Plans, the engine and P&L pages exist. No editing screens, actuals, forecast, reconciliation or attendance.     |
| Calendar  | Barely. Closed dates live in plans, and calendar-sync copies a spreadsheet into Google Calendar.                        |
| Staff     | Partly. Plans cost staff by level. No list of named coaches.                                                            |
| Inventory | Barely. Boat classes, resource kinds and boat rates exist. No boat register.                                            |
| Sources   | Mostly, differently. clubspot-sync replaces the CSV uploads. No event-source watching or recommendations import.        |
| Settings  | Mostly, as data. The catalog and plan rates hold these inputs. They're edited in the Data Studio.                       |
| Directory | No.                                                                                                                     |
| Users     | Yes, differently. Directus roles and Authentik.                                                                         |
| Design    | Yes, differently. sail-team's Storybook.                                                                                |

## Needs that cross tabs

- A staffer's correction survives the next sync. SailOps's main lesson: Clubspot's data is lossy, and a human ruling has to be keyed to something the next import reproduces, never to a row that gets recreated. platform's person matcher already works this way.
- Every number on a screen says how it was worked out, in a popover or a line under it.
- Every list a staffer works through remembers its filters and sort, and the page you came from.
- No page shows a family's private details to someone who can't already read them. Directus decides; the app only hides what Directus refuses.

## Marketing

Program directors and whoever does outreach use it to judge how the program is doing and to work lists of families to contact.

- A program director can see, on one row of tiles: active sailors in the latest term, retention term to term and year to year (each the average of the last three), annualized net sales, typical tenure, the summer-camp-to-fall conversion rate counting only first-time converts, and how many families make up a fifth, half and four-fifths of income.
- They can filter every chart by sailing pathway (learn to sail, adventure, singlehanded, double-handed).
- They can see retention as a cohort grid: each row a first term, each column N terms later, unknown future cells blank, never zero.
- They can see net sales by term with a trailing-year line and same-term growth. Net sales is collected minus refunds and credits, before card fees. Growth hides when last year's base is too small to mean anything.
- They can see which schools send sailors, credited to the sailor's school at their first registration.
- They can see the paths sailors take through programs (a flow chart by each sailor's 1st, 2nd, 3rd registration) and where they leave, with each exit labelled with the share that left there.
- They can see which earlier programs feed each program, ranked by how many terms the sailors they send stay, and how sailors move between pathways.
- They can work a **camp-to-season** list: summer campers who never joined a seasonal program, one row per family, with a likelihood tier measured from past campers of the same age and keenness, a suggested program by age, siblings already sailing, and the instructor's recommendation.
- They can work a **bring-back** list: families whose sailors left a seasonal program, grouped by how long ago.
- On either list they can filter, mark a family contacted for the coming term (and undo it), copy the emails, and log one message against many families. Whether it worked is read from the next term's registrations, never entered.
- They can keep a list of **leads**: families who asked about sailing and haven't registered. Each lead has its contact details, sailors, interests, an owner, a status (new, contacted, engaged, registered, lost with a reason), a next follow-up date, and a timeline of messages. Overdue and due-today leads come first. A new lead is checked against existing leads for duplicates.
- They can book a lead's sailor into a practice as a trial or a visit, and the coach sees it on that day.

**Covered:** none of the pages. The CRM holds registrations, people and billing to build them from ([docs/crm-schema.md](https://github.com/cyc-seattle/platform/blob/main/docs/crm-schema.md)). There's nowhere to store a lead, a contact log, a "contacted" mark or a school. [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) leaves leads and outreach to the CRM.

## Families

Staff use it to answer questions about one family and to fix what the data gets wrong.

- A staffer can browse every family (siblings and their guardians together) with sailors, terms, programs, net spend and an engagement score, filtered by pathway and by window (last term, last year, all time), searched and sorted.
- They can see where families come from on a map by ZIP area, never by street address, with small areas folded into "elsewhere".
- They can open a family and see its homes, its sailors (age, not birth date; school; other spellings; how many records were combined), every registration including waitlisted and cancelled ones struck through, and a log of messages sent.
- They can fix a family: add a parent, correct a postal code or email, merge two homes or split one out, combine two records of the same child, mark a teenager as registering for themselves, and undo any of it back to what the import said.
- They can work a queue of records that need a decision: unreadable names, unclear birth dates, suspected duplicates, automatic merges that weren't obvious. Each comes with its evidence, and each ruling holds through later syncs.
- Every identity change is audited.

**Covered:** partly. The CRM has people, guardian and emergency-contact links, and a cautious matcher whose staff merges hold ([Person identity and merging](https://github.com/cyc-seattle/platform/blob/main/docs/crm-schema.md#person-identity-and-merging)). Merges are done in the Data Studio. There's no household or family entity, no family page, no review queue and no scores. sail-team's Rosters shows a family its own people, not a staff view.

## Programs

Program directors plan each term's offerings, see what they cost and earn, track how the term is going, and take attendance.

- A program director can plan an offering from its type (weekly program, clinic, regatta support, private lessons, charter equipment, boat storage), level, boat classes, coach or coach level, price, expected and maximum sailors, and its schedule.
- They can give a weekly program one or more sets of weekdays and times, each ending at a fixed time or at dusk, whichever is earlier. Dusk is the venue's sunset less a buffer.
- They can see where an offering's activities clash with holidays, school breaks, regattas and closures, and choose which to skip. A clash is a warning, not a block.
- They can copy an offering into a new term, keeping its times, boats, coach level and price.
- They can cancel an offering, archive it, and restore it, without losing its history.
- They can see each offering's cost in three parts: variable direct (coach pay, RIBs, boat wear, travel, incidentals, payroll tax), fixed direct shared by MTDC, and G&A, with its break-even number of sailors and net.
- They can see what one more activity and one more sailor would cost.
- They can see the term's offerings on a calendar or as a list, and move from one offering to the next.
- They can see each term three ways: **planned** (the budget), **current** (money collected and cost incurred to date), and **forecast** (collected plus the spots still sellable, against the full cost).
- They can see each term's income and costs by month, line by line.
- They can see coach pay for the term, overtime after 40 hours a week counted across every offering a coach works, and profit share.
- They can match Clubspot's billing to offerings, by a rule that keeps applying to new payments, and see expected against actual for each.
- A coach can take attendance by boat class and day: present or absent for each registered sailor, drop-ins from other programs, and walk-ins. A program director can see attendance rates by month and term, and each regatta's registered sailors, present, absent and drop-ins.
- They can see a year's charts: sailors, income, program hours with cost per hour, and price per hour with how full the offerings were.

**Covered:** partly. The planning schema and engine hold offerings, activities, staff levels, rates, pools, MTDC, revenue charges, trips, closed dates, boats and profit share, for a year at a time ([docs/planning-engine.md](https://github.com/cyc-seattle/platform/blob/main/docs/planning-engine.md)). sail-team shows each plan's P&L and the Financial Plan. Not built: screens to edit a plan, a dusk rule, the "+1" figures, anything by month, actuals and the forecast ([Actuals](https://github.com/cyc-seattle/platform/blob/main/docs/planning-schema.md#actuals) is designed only), billing reconciliation, and attendance.

## Calendar

Race and program staff use it to see the regattas and clinics coming up, and the holidays around them.

- A staffer can see Opti and ILCA regattas and clinics, month by month, as a calendar or a list, each marked confirmed (dates posted, or a notice of race or registration link), projected (from last year's pattern), last year, or cancelled.
- They can filter by boat class, area, organizer and event type, and show or hide projections.
- They can mark a notice of race, correct an event's details, delete a wrong one, and adopt an event as one CSC supports.
- They can show federal holidays and school no-school days on the same calendar, each in its own colour, apart from the racing events.
- They can keep their own named calendars of dates, such as closures or training days, that offering schedules check for clashes.

**Covered:** barely. Plans hold closed dates (`plan_closed_dates`). calendar-sync copies a spreadsheet of events into Google Calendar ([docs/syncs.md](https://github.com/cyc-seattle/platform/blob/main/docs/syncs.md#calendar-sync)). There's no racing calendar.

## Staff

Program directors use it to keep the list of coaches they assign to offerings.

- A program director can keep a list of coaches, each with a level, whether they get profit share, and whether they're active. Archived, never deleted.
- They can assign a named coach to an offering, and see that coach's hours and pay across every offering in the term.
- They can link a salaried position to a person.

**Covered:** partly. Plans cost coaches by staff level and salaried position, not by person ([docs/planning-schema.md](https://github.com/cyc-seattle/platform/blob/main/docs/planning-schema.md)). People and their program roles are in the CRM.

## Inventory

Program directors use it to track CSC's boats and what they cost each program.

- A program director can keep a register of boats: class, sail and hull numbers, bought or donated, value, dates, owner (CSC or private), and where it's stored.
- They can see each boat's value wear down over a charter life and then a beginner life, counted in terms used, so an idle boat costs only storage.
- They can record which sailor charters which boat each term, with the agreement and fee.
- They can log damage: date, boat, repair cost, amount charged to the sailor, status.
- They can keep racks and deck areas, with how many boats each holds and its footprint, and see each program charged for the space its boats use.
- They can sell storage to sailors who own their boats, with agreements that start and end.
- They can filter boats by stage and class, and see each boat's wear to date and remaining value.
- They can close a term so its boat costs stop changing.

**Covered:** barely. `boat_classes`, `resource_kinds`, `plan_resources` and `plan_boat_rates` let a plan cost boats by class and rate. There's no boat register, depreciation, charter assignment, damage log or storage.

## Sources

Whoever loads data uses it to get Clubspot's data in and to keep watch on regatta organizers' pages.

- A staffer can see every term's data at a glance: which offerings have registrations and billing, and which are missing something.
- They can fix import problems: a registration with no class, a sailor with no usable identity, a payment that matches no registration. Each fix holds through the next import.
- They can classify each Clubspot class by level, boat class, kind and pathway, once, and have it stick.
- They can load instructors' recommendations for each sailor.
- They can keep a list of organizer and school calendar pages, see which have changed or haven't been checked in two weeks, and apply or ignore what changed.

**Covered:** mostly, differently. clubspot-sync reads Clubspot's API every hour, so there are no files to upload, and it keeps billing in `clubspot_registration_billing` ([docs/syncs.md](https://github.com/cyc-seattle/platform/blob/main/docs/syncs.md#clubspot-sync)). Programs are linked to Clubspot classes by hand. Not covered: a view of what's missing per term, fixing a payment's match, instructors' recommendations, and watching organizer pages.

## Settings

Admins use it to set the rates and costs every plan uses.

- An admin can set the year's direct-cost rates: coach pay by level, overtime, per-diem, mileage, incidentals, RIB hours and fuel, boat wear per hour, payroll taxes, workers' comp, and B&O tax.
- They can set fixed direct costs and G&A, each with a yearly amount and how it's shared out (by MTDC, by area, by floor space, or not at all), and choose whether G&A is shared by MTDC or charged as a share of sales.
- They can set the boat lives and how much each life recovers.
- They can keep the lists of levels and boat classes.
- Any staffer can set their own display name.

**Covered:** mostly, as data. The catalog (`accounts`, `products`, `program_areas`, `boat_classes`, `qualifications`, `resource_kinds`) and each Operations Plan version's `plan_rates`, `plan_pools`, `plan_revenue_charges` and staff levels hold these. They're edited in the Data Studio or by an agent. The catalog screens are planned in [2026-10-19-erp-and-frontend.md](2026-10-19-erp-and-frontend.md), step 18.

## Directory

Admins use it to keep the organizations and venues other pages refer to.

- An admin can keep a list of organizations (yacht clubs, class associations, regional organizers), with type, website and logo.
- They can keep a list of venues, with address, location and time zone, so the dusk rule and the racing calendar know where things are.
- An organization or venue in use can't be deleted.

**Covered:** no. `organizations` holds only our own organization's fiscal year.

## Users

Admins use it to decide who can sign in and what they see.

- An admin can see everyone who can sign in, with their role and last sign-in.
- They can give someone access, and take it away.

**Covered:** yes, differently. Directus holds users, roles and policies, and Authentik handles sign-in ([docs/access.md](https://github.com/cyc-seattle/platform/blob/main/docs/access.md)). An admin changes roles in the Data Studio. No sail-team page for it.

## Design

SailOps's Design page is a living catalog of its components and tokens. sail-team's Storybook is ours ([cyc-seattle/sail-team#1](https://github.com/cyc-seattle/sail-team/issues/1), step 5). Nothing to add.
