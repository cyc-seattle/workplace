---
tags: [research, planning, catalog, directus, website]
---

# How an approved plan gets into the catalog

Research for the 2027 offerings in [cyc-seattle/platform#332](https://github.com/cyc-seattle/platform/issues/332) ("Left"),
which the website launch on Dec 23 depends on ([cyc-seattle/csc-website#18](https://github.com/cyc-seattle/csc-website/issues/18)).
Read from `platform`'s `main` on 2026-11-27: `schemas/planning.yaml`, `schemas/core.yaml`, `schemas/crm.yaml`,
`schemas/clubspot.yaml`, `docs/planning-schema.md`, `docs/syncs.md`, `docs/access.md`, `src/planning/`,
`stacks/backend/frozen-plans.cjs`, `stacks/backend/policies.ts`, `src/syncs/clubspot/offerings.ts`, and sail-team's
`src/directus/`. Prod's data wasn't read. Every decision below is the maintainer's, from 2026-11-27.

## The design in short

- The catalog holds the **actual** entities, separate from the plan's. Actuals, such as enrollment and expenses, hang
  off catalog rows, which don't move the way a plan does.
- **Plan rows link to catalog rows**, not the other way. Each plan offering links to its catalog offering, which must
  exist first. The catalog row is what makes two Financial Plans' offerings "the same offering".
- **No plan keys.** Every row has one identifier, its `id`, and every `*_key` reference becomes `*_id`.
- A **sync**, from a button in Sail Team, compares the frozen plan in force with the catalog and shows every difference.
  The person ticks the ones to apply.
- An offering has a **schedule**: a list of the weekdays and times it meets, such as Tue & Thu 4:15–7:30 pm. The
  website shows it, and doesn't work it out from activities.
- The catalog gets **activities**: one dated, timed event of an offering, with both times required, no name, no kind
  and no dusk field. Clubspot has no activities, only camps with sessions and classes; "session" means only Clubspot's.

Earlier rules that still hold: soft delete is `archived_at`; no arbitrary enums; no derived or mirror copies between
collections except where the maintainer chose one, as here; the data model stores facts and inputs, not results.

## What's there today

**Plan side.** A Financial Plan holds an Operations Plan and a Program Plan per program area. Every plan row has an
`id`, new in each copy of a Financial Plan, and a `key`, which stays the same across copies. A Financial Plan is a
draft or frozen. The one **in force** on a day has the latest `effective_from` on or before it (`planInForce`).

**Catalog side.** `offerings` (in `core`) are one kind since
[cyc-seattle/platform#347](https://github.com/cyc-seattle/platform/pull/347): `program_id` (required), `name`,
`registration_form_id`, `starts_on`, `ends_on`, `price_cents`, `capacity`, `archived_at`, plus `clubspot_class_id` and
`clubspot_session_id` (linked by hand) and `confirmed_count` (clubspot-sync counts it). A registration form is one
Clubspot camp, with `opens_on`. CRM `registrations` point at offerings. Nothing links a catalog offering to a plan
offering.

**What the website reads** (`WEBSITE_CATALOG_READS`): programs' name and ages; unarchived offerings' program, name,
form, dates, price, capacity and confirmed count; unarchived forms' name, opening date and camp; public camps' flags.

### What a plan row's `key` does today

1. **Links between plans in one Financial Plan.** The triggers refuse a foreign key to a row in another plan, so a
   Program Plan row names an Operations Plan row by key: `term_key` (offerings, bonuses), `position_key` (block staff,
   bonuses), and a line's `cost_center_key`, which names an offering or a pool by key, or a product or area by id.
2. **The subject of a result:** `plan_result_pnl.subject_key`, `plan_result_positions.position_key`,
   `plan_result_capital.item_key`, `plan_result_bonuses.bonus_owner_key`, warnings' `subject_key`.
3. **Copying into a draft.** `copyParent` keeps each key and remaps real links (`offering_id`, `block_id`, `trip_id`)
   through one map of old ids to new.

Nothing compares two Financial Plans row by row by key: not the engine, not Sail Team.

## No plan keys

- Every row has one identifier, its primary key `id`. The `key` column goes, and each `*_key` becomes `*_id`:
  `position_key` → `position_id`, `term_key` → `term_id`, `bonus_owner_key` → `bonus_owner_id`, `item_key` →
  `item_id`, `program_area_key` → `program_area_id`, `subject_key` → `subject_id`.
- A cost center stays a cost center: `cost_center_type` + `cost_center_id`, polymorphic, on lines and result lines. A
  warning's subject stays polymorphic too. Nothing else is redesigned.
- The trigger rule "a plan row can only link to rows in its own plan" becomes "in its own Financial Plan".
- `copyParent` remaps ids through its old-to-new map. A `cost_center_id` that names a plan row (an offering or a pool)
  is remapped through the same map; one that names a catalog row is copied as it is.

## What links to the catalog

- **Products stay the catalog's parent entity**, with programs as the first product type (the subtype pattern).
  Catalog schemas are added as features need them.
- `plan_programs` keeps `product_id`, a product that's a program. The engine and every other plan row (cost centers,
  bonus products, salaried bookings) address products by product id, so a `program_id` would name the same thing twice.
- **Catalog offerings belong to products.** `offerings.program_id` becomes a required `product_id`, so a charter,
  storage lease or merchandise product has offerings too. Program-only fields (registration form, Clubspot class and
  session, schedule) stay optional. The website build, clubspot-sync, gsuite-sync, rosters and Sail Team's Catalog
  read the program through the product.
- **`plan_offerings.offering_id` is required** for every plan offering. `plan_offerings.product_id` and `name` are
  dropped: the engine and Sail Team read them from the catalog offering.
- **Plan activities don't link** to catalog activities. A day can be planned before its times are known, and the
  catalog never holds an activity without them. The sync matches them by catalog offering, date and start time.
- Terms, salaried positions, pools, bonus owners, capital items, rates, closed dates, blocks, block staff and boats,
  and trips stay plan rows, with no catalog counterpart. There are no catalog terms.

### Where catalog offerings come from

- **Only Catalog Writers create catalog offerings.** Plan Writers plan against offerings that already exist, and
  can't add one.
- **Starting a Financial Plan from another year's**, which only a Plan Admin does, makes the new year's catalog
  offerings for the copied plan offerings, with the same product and name, and links the copies to them. Starting from
  the same year's keeps the links.
- So a Plan Admin needs Catalog Writer. The policies stay separate, named for what they grant, and Plan Admin is
  **given with** Catalog Writer, as a Medical policy is given with a CRM policy. The `frozen-plans` hook writes past
  Directus's permissions, so it checks that the person starting the Financial Plan holds Catalog Writer before it
  makes offerings, and refuses otherwise.
- **The website shows only offerings on an unarchived registration form,** so next year's offerings stay off the site
  until a Catalog Writer puts them on one. Today it shows every unarchived offering.

## Field by field

"Sync" means the plan's value is compared with the catalog's and pushed when the person applies it. "Plan only" means
the catalog never gets it. "Catalog only" means the sync never touches it.

### Offerings (`plan_offerings` → `offerings`)

| Plan field          | What it is                          | Decision                                                       |
| ------------------- | ----------------------------------- | -------------------------------------------------------------- |
| `offering_id`       | Its catalog offering (new)          | Required link from the plan.                                   |
| `key`               | Stable id across Financial Plans    | Dropped.                                                       |
| `product_id`        | The product sold                    | Dropped from the plan; the catalog offering names the product. |
| `name`              | Such as "Week 3"                    | Dropped from the plan; the catalog offering's.                 |
| `term_key`          | Its term, such as Summer 2027       | Plan only, as `term_id`. Registration forms group the catalog. |
| `starts_on`         | First day                           | Sync.                                                          |
| `ends_on`           | Last day                            | Sync.                                                          |
| `capacity`          | Most sailors                        | Sync. Clubspot's cap is built from it.                         |
| `price_cents`       | Price per sailor                    | Sync. The board sets it Dec 15.                                |
| `target_enrollment` | Sailors the plan expects            | Plan only. The actual is `confirmed_count`.                    |
| `cogs_rate`         | Cost of goods as a share of revenue | Plan only. Actual costs come from QuickBooks.                  |
| `note`              | Planner's note                      | Plan only.                                                     |
| —                   | Schedule                            | Sync, from the plan's activities (below).                      |
| —                   | Registration form                   | Catalog only.                                                  |
| —                   | Clubspot class and session          | Catalog only, linked by hand (or by the Clubspot push, later). |
| —                   | `confirmed_count`, `archived_at`    | Catalog only, but for an archive the person applies.           |

### Activities (`plan_activities` → new `activities`)

A catalog activity has `offering_id`, `date`, `start_time` and `end_time`, all required, and `archived_at`: a rained-out
practice is archived, not deleted. The website can show them on a calendar
([cyc-seattle/csc-website#19](https://github.com/cyc-seattle/csc-website/issues/19)).

| Plan field                                             | What it is                        | Decision                                                                                                                 |
| ------------------------------------------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `offering_id`                                          | Its plan offering                 | Sync, as that plan offering's catalog offering.                                                                          |
| `date`                                                 | The day                           | Sync. Part of the match.                                                                                                 |
| `start_time`                                           | When it starts                    | Sync. Part of the match. A plan activity without both times is skipped.                                                  |
| `end_time`                                             | When it ends                      | Sync.                                                                                                                    |
| `kind`                                                 | practice, regatta, clinic, travel | Plan only. [cyc-seattle/platform#394](https://github.com/cyc-seattle/platform/issues/394) may drop it from the plan too. |
| `on_water_minutes`, `setup_minutes`, `putaway_minutes` | Coach and boat time               | Plan only.                                                                                                               |
| `uses_boats`, `block_id`, `trip_id`                    | Allocation and travel             | Plan only.                                                                                                               |

### Everything else

| Plan entity                                                    | Decision                                                                                                                  |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Programs, products, program areas                              | Already catalog rows that plans link to.                                                                                  |
| `plan_programs` (staff level, ratio, indirect rate, notes)     | Plan only. Costing inputs a draft can vary.                                                                               |
| `plan_terms`                                                   | Plan only.                                                                                                                |
| `plan_trips`                                                   | Plan only. Actual trip costs come from QuickBooks.                                                                        |
| `plan_activity_blocks`, `plan_block_staff`, `plan_block_boats` | Plan only. Actual staffing, if tracked, is its own later design.                                                          |
| `plan_closed_dates`                                            | Plan only.                                                                                                                |
| Budget and labor lines, rates, pools, bonuses, capital         | Plan only. Actuals come from QuickBooks ([cyc-seattle/platform#274](https://github.com/cyc-seattle/platform/issues/274)). |
| Plan offerings of charters, storage, merchandise               | Linked to catalog offerings of their products, like any other.                                                            |

## An offering's schedule

The race team schedule shows each team's practice days Monday to Sunday with a time in each day's cell, and Adult
Learn to Sail shows kinds of class such as "Tue & Thu" and "Sat & Sun". A team may meet at different times on different
days.

A child collection, `offering_schedule` (`offering_id`, `weekday` 1–7, `start_time`, `end_time`, all required), edited
inline on the offering's form as its `schedule` field. One row per day of the week it meets, such as J Pod on Tuesday
and Thursday 4:15–7:30 pm and Saturday 10 am–2 pm. Weekday is the fixed ISO range, not an arbitrary enum. The sync
fills it in from the plan's activities, and a Catalog Writer checks it.

Ruled out: three fields (weekdays, one start and one end time), which can't give different days different times; and
free text, which the site can't place in a day grid.

## The plan-to-catalog sync

- **Which plan:** the Financial Plan in force for the year, and it must be frozen. After the Dec 15 vote a Plan Admin
  freezes it and sets its `effective_from`. The sync refuses a draft, so it never brings in numbers the board didn't
  approve. When a later Financial Plan comes into force, the next sync compares with that one.
- **What it covers:** the whole plan in force, every time.
- **What it shows:**
  - each synced offering field that differs from the linked catalog offering;
  - the schedule, compared whole: the plan's pattern (each weekday and time most of the offering's plan activities
    share) beside the catalog's; applying it replaces the catalog's;
  - activities, matched by catalog offering, date and start time: an unmatched plan activity with both times is an add,
    a matched one with another end time a change, an unmatched catalog activity an archive; plan activities without
    both times are listed as skipped;
  - archives: a catalog offering some Financial Plan for the year links to, but the plan in force doesn't, such as a
    week the board cut.
- **Edits in the catalog since the last sync:** there's no stored base and no dismissal. A difference shows on every
  sync until the plan and the catalog agree, and the person decides each time. Dismissals like `audit_findings`'
  fingerprints can come if the list gets noisy.
- **The review**, in Sail Team on Catalog → Offerings, behind a "Sync from plan" button, groups the differences by
  program area, then registration form ("no form yet" is a group), then offering. The person ticks a row, an offering
  or a group, can filter to one area, and applies. Applying some leaves the rest for the next sync.

It reads like the deployed syncs (`docs/syncs.md`), which split each pass into a pure plan function and a thin
executor, and whose audits report and never prune:

- **platform:** a pure function in the published package that takes the plan's rows and the catalog's and returns the
  difference, per row and field. Unit tests, and an integration feature for the rules. No new deployed service.
- **sail-team:** reads the plan in force and the catalog with the person's own token, shows the difference, and writes
  what they tick, as them. Directus's revisions record who applied what.

## Clubspot, registrations and actuals

- **Clubspot.** Unchanged: a form is one camp; an offering links to its class, and to its session when weekly. Staff
  link them by hand until the push exists, which could write the schedule into a session's description. Activities have
  no Clubspot counterpart.
- **Enrollment.** Registrations already point at catalog offerings, and `confirmed_count` counts them.
- **Expenses and revenue** ([cyc-seattle/platform#274](https://github.com/cyc-seattle/platform/issues/274)). An `actuals`
  row's cost center, for an offering, is the catalog offering. Comparing with a plan finds the plan offering that links
  to it, in whichever Financial Plan is compared. A catalog offering no plan offering links to, such as a clinic added
  in June, counts as unplanned.

## How Clubspot's camps, sessions and classes map to the catalog

The maintainer's mapping: a Clubspot **camp** is like a plan **term**, a **class** is a **program**, and one class in one
**session** (a class-session) is one **offering**. Read from prod on 2026-11-27, read-only.

| Clubspot        | Catalog and plan                       | Prod today                                                                                                                                                                                                |
| --------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Camp            | A registration form; within a term     | One form per camp: all 25 forms have a camp. A term holds several camps: Summer 2026 has Summer Sailing Camps, Summer Singlehanded Race Teams, Summer High-performance programs and Summer 420 Race Team. |
| Class           | A program                              | A class's offerings share one program, and clubspot-sync sets the class's `program_id` from them.                                                                                                         |
| Session         | A dated part of a camp, such as a week | 371 sessions. Every registration entry names its session.                                                                                                                                                 |
| Class × session | An offering                            | 125 of 147 offerings link a session. 22 link only a class and cover all its sessions.                                                                                                                     |

**Why 2026 has season-long offerings.** clubspot-sync's CRM offerings followed Clubspot's caps: a class with a cap that
covers every session (a cap with no session) became one offering for the whole camp
(`clubspotOfferings` in `src/syncs/clubspot/offerings.ts`), and
[cyc-seattle/platform#347](https://github.com/cyc-seattle/platform/pull/347) kept those rows. In 2026's Summer Sailing
Camps, Guppies, Youth Beginner, Teen Sailing and Youth Intermediate have such a cap (Guppies 10) and a cap in each
session (Guppies 11 or 12), so each became one season offering while Youth Advanced, Teen Adventure and Teen Advanced,
with session caps only, became one per week. Adult Learn to Sail (cap 30, and 7 to 9 a session) and Open Boating went
the same way.

**Registrations know their session.** All 685 registrations on the 22 class-wide offerings come from an entry with a
session. Guppies' 126 span all 10 weeks, Youth Beginner's 222 the same, Adult Learn to Sail's 39 its 8 sessions.

**How a registration finds its offering.** clubspot-sync looks up the class's whole-camp offering first, then the class
and session's (`offeringIdOf`). A changed link moves a registration on the next run; it never deletes one.

**Where it differs from the mapping:**

- 22 offerings are a class for a whole camp, not a class-session.
- The sync prefers a class's whole-camp offering to its class-session one, and `offering_differs` compares a class with
  a session-less cap as one offering.
- A camp isn't a term: a term holds several camps. A registration form already stands for one camp in the catalog.
- The plan's offerings don't always follow sessions: Adult Learn to Sail is planned by month ("Weekend May"), where
  Clubspot has two- to three-week sessions ("Tuesdays & Thursdays 5:00-8:00", May 12 to 28).

**Decided (M1):** an offering is always one Clubspot class in one session; once linked, it links both. No offering
covers a whole camp. A registration form is the catalog's camp, one each, so there's no catalog table for camps or
terms. A class is a program: every offering of one class is of one program.

**Decided (M2):** a reviewed migration splits each whole-camp offering into one offering per session its class is
offered in, with the same program, form and price, the session's dates, name and cap, linked to the class and the
session. Each registration moves to the offering for its entry's session, and the emptied whole-camp offering is
deleted. It ships as its own platform PR right after step 1, with the clubspot-sync change that stops making and
preferring whole-camp offerings.

**Decided (M3):** the mapping is settled.

- A plan offering is one class-session too, linking one catalog offering. In one Financial Plan, two plan offerings
  shouldn't link the same catalog offering; Directus can't make the pair unique, so the engine warns, and the sync
  shows it.
- A 2026 plan offering that matches no session, such as Adult Learn to Sail planned by month or "Opti Clinics Summer"
  covering several clinics, gets a catalog offering of its own, linked to no Clubspot class or session, as charters
  and storage are. Frozen plan offerings aren't split or merged.
- The 2026 match list runs again after the split and after a Catalog Writer links the 2027 Winter Singlehanded
  classes. A match is then exact: the same program and the same dates as a class-session. Anything else is reviewed.
- From 2027, planners plan Adult Learn to Sail and clinics as the sessions Clubspot will sell: a practice for the
  `allocate-plan` skill and the docs, not an engine rule.

The order: PR 1 (keys become ids); after step 1, the split PR; the match list again; then PR 2.

## Migrating existing data

One reviewed Directus migration in `stacks/backend/migrations/`, run once at start, tested in PGlite, a no-op when run
again or on a new database. Like `cyc0022`, it changes frozen Financial Plans, so it turns the frozen-plans triggers off
for its own statements, under the table locks `ALTER TABLE` takes.

1. **Catalog offerings belong to products:** fill `product_id` from each offering's program, then drop `program_id`.
2. **A catalog offering for every plan offering.** Plan offerings that share a key across a year's Financial Plans are
   one offering, so each (year, key) gets one catalog offering. 2026's already exist, from the CRM, with their
   registrations. A read-only script proposes matches from prod, the maintainer reviews them, and the migration
   carries the reviewed list. Every other (year, key) gets a new catalog offering, on no form, named from the plan in
   force, or the latest draft.
3. **Keys become ids** within each Financial Plan: `term_key`, `position_key`, a cost center's key (an offering's or
   pool's becomes that row's id), and every result's `*_key`. A frozen plan's results keep their numbers.
4. **Drop** `key` from every plan row, and `name` and `product_id` from `plan_offerings`.

## Order of work

Steps 1 and 3 run in parallel where they don't touch the same files.

1. **platform, the catalog:** `offerings.product_id`, `offering_schedule`, `activities`. The website build reads
   offerings only on an unarchived form, and their schedules. clubspot-sync, gsuite-sync and the rosters read the
   program through the product. This unblocks the website's schedules on its own.
2. **csc-website:** the race team, adult and program page schedules read the offering's schedule.
3. **platform, no plan keys:** schema, the migration, the engine, the `frozen-plans` hook (ids across plans in one
   Financial Plan; a copy from another year makes catalog offerings, after checking Catalog Writer), the triggers,
   results, the `allocate-plan` skill, docs. The published package's types change, so it's a breaking release.
4. **sail-team, planning:** the screens read ids and the catalog offering's name; a draft picks existing offerings.
5. **platform, the sync's difference:** the pure function, unit tests and a feature.
6. **sail-team, the sync:** "Sync from plan" on Catalog → Offerings, the review, and apply.
7. **Access:** Plan Admin given with Catalog Writer, in the groups and `docs/access.md`.

Steps 1 and 2 by Dec 23. Steps 3 to 6 before the board's Dec 15 vote, so the frozen 2027 plan goes into the catalog
through the sync. If they slip, a Catalog Writer enters the 2027 offerings by hand from the approved plan, and the
migration's reviewed list links the plan's offerings to them.

## Ruled out

- **A one-off copy** of the plan into the catalog: the maintainer chose a sync that shows the difference each time.
- **A `plan_offering_key` on catalog offerings,** linking back to the plan: the link goes from the plan to the catalog.
- **Plan Writers creating catalog offerings** as they plan: only Catalog Writers create them.
- **A script** for the sync: it's a button in Sail Team.
- **Catalog terms** now: added when a feature needs them.
- **Splitting the cost center** into one link per kind: it stays polymorphic.

## Follow-ups

- [cyc-seattle/platform#394](https://github.com/cyc-seattle/platform/issues/394) reviews the planning schema for unused
  fields, starting with `plan_activities.kind`.
- [cyc-seattle/csc-website#19](https://github.com/cyc-seattle/csc-website/issues/19) is a calendar of every practice,
  class and camp, from catalog activities.
