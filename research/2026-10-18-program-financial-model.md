# Program planning and financial model: data model and design

A new TypeScript web app on isthmia's Directus. It models CYC's programs and other products, versions and compares a plan for each product, and later measures them against actuals. This draft settles the data model. Where the schemas live is deferred: either they stay in isthmia's merged apply, or the split work in #185 gives each repo its own.

## Context

### Sources

- The treasurer conversation notes ("CYC Financial Model Requirements", a Google Doc).
- The treasurer's workbook, "2026 Program and Financial Model", with the 2025 and 2024 versions for contrast.
- project-two (Puget-Sound-Sailing-Team), the other volunteer's Supabase app. Its programs and cost engine are the closest prior art. Issue #213 records what it holds.
- "Versioned Financial Models: Architecture Notes", from an earlier session.
- isthmia's `crm` and `clubspot` schemas.
- Public material on planning tools (Anaplan, Pigment, Adaptive, Planful, Jirav), the Uniform Guidance cost rules (2 CFR 200.1, 200.414, Appendix IV), and staffing-ratio models.

### Decisions already made

- **Plan shape.** Each product (program, charters, storage) has its own versioned plan, and an Operations Plan holds what products share. "The plan" is the active version set. It rolls forward and is not tied to a year.
- **Reporting** uses the fiscal year, January to December. Programs may cross the year.
- **Forks** are independent copies that record their fork point. Pulling a parent's later changes into a fork is a later feature.
- **Variance** is measured against a frozen baseline, such as the budget the board approved. Re-forecasts are drafts with an "actuals through" date.
- **Shared coaching.** Programs that practice together share coaches only through activity blocks the planner sets up. The planner also sets each block's hourly coach level. The system never infers sharing from overlapping times.
- **Ratios.** The coaching ratio (sailors per coach) belongs to the offering, because younger and less experienced sailors get a lower ratio. Coaches are staffed to enrollment.
- **Salaried hours** are booked three ways: coaching (from the activities the person coaches), management hours entered against a product, and the rest. The rest is spread over programs by MTDC, except for a fixed G&A share.
- **Scope.** The model covers the whole Sailing Center. Club charges (the clubhouse fee, storage) are budget lines. There is no tenant mode, no sales-% club fee and no club-wide MTDC denominator.
- **Offerings** are Clubspot session × class pairs. Summer class-weeks are offerings, generated from a grid, with enrollment from a fill rate.
- **Counts.** Coach, RIB and boat counts are derived from ratios, and any offering, rule or activity can pin a fixed count. The first import shows the sheet's typed counts against the derived ones for each offering.
- **The coach bonus** belongs to a bonus owner, which is a role that owns a set of products. It is a percentage of their combined net, when positive.
- **Revenue** has two bases: cash, by registration, and accrual, by delivery.
- **Travel.** Regatta trips expand into travel days. Meals, lodging and mileage scale with the derived coaches.
- **Overtime** isn't modelled.
- **Cash and capital.** The cash position, runway and capital wish list stay in the sheet for now.
- **Volunteers** fill coach requirements at no cost, and their hours aren't valued.
- **Depreciation** is a budget line for now.
- **Editing.** Several people can edit the same draft at once. The last write to a field wins, with no conflict handling.
- **Backend and data.** The backend is isthmia's Directus. The app's code is public, but its data (wages, real figures) is not.
- **Domains.** The org-wide catalog belongs in a new `core` domain. `programs` moves there from `crm` and becomes the `program` kind of `products`.
- **Terms.** Product, program, offering, activity block, cost center, plan, version and version set, as defined below. The treasurer's familiar finance terms win over coined ones.
- **Actuals.** Expense actuals will come from QuickBooks Online, which Clubspot registrations already flow into. Reconciliation comes later; modelling comes first.

### How the treasurer's workbook works

- **Programs.** The workbook has one sheet per revenue account: Singlehanded, LTS, Adventure, Doublehanded, Summer and High Performance.
  - Each sheet has an offering table with typed constants per offering: sessions per week, hours, capacity, coach level and count, RIBs, boats, and a bring-your-own-boat flag.
  - Below that is a monthly block per offering with enrollment, revenue and cost lines.
- **Costs.**
  - Hourly labor is sessions × hours × the wage for the coach level.
  - Salaried coaching is hours × salary ÷ 2080.
  - Fuel and RIB maintenance are charged per RIB-hour, and sailboat maintenance per boat-hour.
  - Storage is allocated by area.
  - Payroll tax, scholarships, card fees and B&O are percentages.
- **Staffing.** No formula derives coach or RIB counts. They are typed in, and a shared coach is typed as a fraction ("1.45 instructors").
- **Overhead** is allocated in two steps:
  1. The program-admin share of the director's salary is spread over "MTDC before admin".
  2. The G&A pool is then spread over each program's total "MTDC".

  The treasurer's MTDC includes rent and storage, so it is not the federal MTDC.

- **Scenarios** are whole-file copies ("417 budget", "382 budget", "weak downside"), compared by typing numbers into a table. Actuals are typed in too.

### The workbook's bugs

The app should not reproduce these. The treasurer should see each one before the app's numbers are compared with the sheet.

1. LTS revenue comes to more than list price: 6 sessions × 3.5 hours × (price ÷ 18 hours).
2. B&O tax is counted twice on the PROGRAMS tab: once in the G&A pool, and again at 1.5% of revenue.
3. The program P&Ls don't add up to the org P&L: the program total is well above the org total.
   - The gap is the scholarships, the unallocated storage in item 4 and the double-counted B&O, less a small merchandise profit.
   - Card fees net to zero.
4. Some storage is in the MTDC total but in no program's base, so it is never allocated.
5. Some inputs disagree with each other: Guppies capacity, the number of summer weeks, and the Yardarm amount. None of them feeds a total.
6. The fall single-handed column divides G&A by total MTDC instead of the sum of the program bases, so it gets too little.
7. Accounting fees are an annual amount in ASSUMPTIONS, but the same amount is typed into every month of the SOA, twelve times as much. It's paired with an equal in-kind donation, so the SOA is probably right.
8. HP enrollment is above its capacity.
9. An old revenue-share admin allocation in ASSUMPTIONS is no longer read by anything.
10. The second salaried position is booked September to November on the SH sheet, but October to December on the SOA.
11. Opti Green boat-hours are typed as 2 instead of 2 × 3 hours.
12. Self storage is entered as an annual amount but booked as 8 months.

### What project-two contributes

- **Worth reusing:**
  - Pure cost functions over integer cents, where every line carries a kind, a readable explanation and warnings.
  - A per-coach "sweep line" that merges overlapping sessions. Explicit activity blocks replace it here, but it shows the problem shared coaching solves.
  - A menu of allocation methods, with an MTDC denominator that doesn't depend on itself.
  - Profit share as a percentage of a positive net.
  - Break-even, marginal +1 sailor and +1 practice, and forecast timing classes.
- **What to avoid:**
  - Coach counts are typed in, so there are no ratio-driven step costs.
  - Its "scenarios" switch the active overhead regime instead of comparing plans.
  - Copying a plan keeps no link to its source.
  - The "planned" budget isn't frozen, so editing a plan mid-season changes the budget.
  - Inputs that matter are buried in a `schedule_config` JSON column.

## Approach

### Terms

The word "session" means three different things today:

- In the treasurer's notes, it is the thing CYC sells (Spring J-Pod).
- In Clubspot, a _camp_ is a season, a _session_ is a dated instance inside it, and a _class_ is an age or skill group.
- In isthmia, `programs` is the lasting catalog entry.

The app uses these terms, which are also defined in `docs/planning-schema.md`:

- **Product:** a lasting thing CYC sells, such as J-Pod Race Team, boat charters or storage leasing.
- **Program:** a product of kind `program`.
  - Each application groups programs its own way: the website by category, finance by revenue account, Google Workspace by Group. So there is no single program hierarchy, and each grouping is a field owned by the application that needs it.
  - isthmia's `programs` becomes the `program` kind of `core.products`.
- **Offering:** a product sold for a period, such as J-Pod Spring 2027 or summer 2027 charters.
- **Activity:** one dated, timed event that consumes resources. Examples: the Wednesday 16:00–18:30 J-Pod practice on 2027-04-07, or day 1 of a regatta CYC runs.
- **Activity block:** activities from different offerings that share coaches and boats, such as J-Pod and K-Pod on Wednesdays.
- **Cost center:** what a money line belongs to: an offering, a pool (G&A, program admin, facilities), or the org (fundraising, capital, unrestricted gifts).
  - Strictly, a revenue-earning offering is a profit center, and something answerable only for revenue is a revenue center.
  - One `cost_center` field covers all three kinds, as most nonprofit treasurers and ERPs use the term.
- **Plan:** a separately versioned part of the whole.
  - A **product plan** holds one product's offerings. It is called a Program Plan, Charter Plan and so on, after the product's kind.
  - The **Operations Plan** holds what products share.
- **Version:** a snapshot of one plan. It is either the draft being edited, or saved and immutable.
- **Version set:** one version per plan.
  - The **active version set** is "the plan".
  - A **scenario** is the active version set with some versions swapped, added or dropped.
  - A **baseline** is a frozen version set kept for variance, such as "FY27 budget as approved".

### Plans

The whole is split by who owns what. A product's own choices sit in its product plan. Anything two products share sits in the Operations Plan.

**A product plan** holds one product's offerings, with their prices, ratios, schedules and direct budget lines. It rolls: the J-Pod plan gains Fall 2027 when someone adds it, and its old offerings stay as history.

**The Operations Plan** holds:

- rates and assumptions, with effective dates (see below)
- staff levels and salaried positions, with their hour bookings
- the resource fleet
- G&A, fundraising and capital lines
- pools and formulas
- activity block rules, which name offerings in two product plans by their stable keys

**A version set** picks one Operations Plan version and one version of each product plan. The engine evaluates that combination. G&A allocation depends on every product's MTDC, so results belong to a version set, not to a single version. Results are cached per saved version set, keyed by its pinned versions.

**Rates carry effective dates.** A plan that rolls across years needs this year's wage and next year's in the same Operations Plan version. So rates and assumptions carry `effective_from`. That is valid time inside one version, which is not the same thing as versioning.

### Catalog collections (`core`)

These describe the org. They are unversioned, edited in the Data Studio, and hold identity and descriptions only, never rates.

- `products (name, kind: program|charter|storage_lease|merchandise|event_hosting|other, revenue_account)`. These are today's `crm.programs` plus the non-program products.
  - `crm` keeps people, contacts and role assignments, which point at program products.
  - Website categories and Google Groups stay fields owned by the applications that use them.
- `accounts`: the chart of accounts.
  - Fields: `number`, `name`, `type` (revenue, expense, asset, liability, net_assets), `form_990_part` and `form_990_line`, `default_function`, and `retired`.
  - The list is append-only, so past versions keep resolving. Retire an account rather than delete it.
- `qualifications`: what a coach is cleared to coach, such as single-handed dinghy, double-handed dinghy, keelboat or powerboat. `qualification_covers (qualification, covers)` records that one qualification can fill another's requirement.
- `boat_classes`: Opti, ILCA, 420, FJ, Harpoon and so on, with `sailors_per_boat`.
- `resource_kinds`: RIB, clubhouse, dinghy float, dry storage. These are kinds only; quantities and rates are per version.
- `offering_external_refs (offering_key, clubspot_camp_id, clubspot_class_id)`: maps an offering to Clubspot, for actual enrollment. It is keyed by the offering's stable key, so every version shares it. It is used in the actuals step, not before.

### Versioning collections

```
plans               (id, kind: product|operations, product_id, name, archived)
plan_versions       (id, plan_id, parent_version_id, status: draft|saved,
                     message, saved_by, saved_at)
version_sets        (id, name, kind: active|scenario|baseline, base_set_id,
                     actuals_through, frozen_at, frozen_by)
version_set_members (version_set_id, plan_id, version_id)   -- one row per plan
plan_activations    (plan_id, version_id, activated_at, activated_by)
```

**Drafts and saving.** A plan has at most one draft, its head. Saving freezes the draft. The next edit opens a new draft whose parent is the saved version. Forking a version starts a new draft branch from it. The versions form a tree, as in git, and every saved node in it is immutable.

**The active version set** is the one row in `version_sets` with `kind = active`. Activating a version does two things:

- It changes that set's member for the version's plan.
- It appends a row to `plan_activations`, which answers "what was the plan on 2027-03-01?".

**A scenario** has `base_set_id` pointing at the active version set. Its own members override the base. Examples:

- Swap J-Pod to draft 3.
- Add a new 420 team plan.
- Drop L-Pod, with a member row whose version is null.

A scenario can mix drafts and saved versions, so it can't be frozen.

**A baseline** is a version set whose members all point at saved versions. Freezing copies the resolved members and sets `frozen_at`. After that the baseline never changes, and variance is measured against it.

**Every version-scoped collection** has three keys:

- `id`: the Directus primary key. It is deterministic: `uuid_generate_v5(version_id, key)`.
- `version_id`: the version the row belongs to.
- `key`: a stable lineage id, the same in every copy of the row. A new row gets a fresh key.

Foreign keys inside a version point at `id`. Because the `id` can be computed from `(version_id, key)`, forking stays a plain `INSERT … SELECT` per collection, foreign keys included. Directus can't model composite keys, and this avoids needing them.

References across plans use the stable `key`, not `id`. An activity block rule, for example, names J-Pod's Spring 2027 offering by its key. The engine resolves those keys within the version set it evaluates. A key that doesn't resolve raises a warning; it doesn't stop the evaluation.

### ER diagrams

The ER diagrams live in `docs/planning-schema.md`.

### Product plan collections

**Offerings**

`plan_offerings` holds what is sold. A program offering is one Clubspot session × class, which is the unit Clubspot caps enrollment on. J-Pod Fall 2027 is one offering, and so is each summer class-week ("Guppies, week 3"). A summer grid UI generates the class-week offerings. Its fields:

- **Identity:**
  - `product_id`: the product this offering sells.
  - `name`, `season_term`, `starts_on` and `ends_on`.
  - `note`.
- **Selling:**
  - `capacity`, `price`, and `price_basis` (per season, per session, per hour, per unit).
  - `target_enrollment`, or `fill_rate` × capacity. Summer uses a fill rate, which can inherit from an assumption.
  - `units`, for leases, charters and merchandise.
  - `registration_curve`: the share of enrollment that registers in each month. It drives the cash view.
- **Staffing:** `sailors_per_coach`, `min_coaches`, `coach_level`, `required_qualification`, and `ribs_per_coach` (default 1).
- **Boats:** `byob_share` (0–1, the fraction who bring their own boat). `plan_offering_boat_classes (offering, boat_class, share)` lists the classes, because regatta support can cover several.
- **Overrides:** `fixed_coaches`, `fixed_ribs` and `fixed_boats` pin a count instead of deriving it. The same overrides exist on schedule rules and activities, for days such as K-Pod's practices with 1 coach and 2 RIBs.
- **Merchandise:** `cogs_rate`.

`plan_offering_prices (offering, tier, price, share)` is optional. It brings back member and non-member pricing (the 2024 model had it), sibling discounts or early-bird prices, as a weighted mix. When it's empty, `price` applies.

**Schedule**

- `plan_schedule_rules` is the pattern, such as "Mon and Wed 16:00–18:30, March–June". Its fields:
  - `offering`, `weekdays[]`, `start_time`, `end_time`, `starts_on`, `ends_on` and `skip_dates[]`.
  - `on_water_fraction`, `setup_minutes` and `putaway_minutes`.
  - `kind`: practice, regatta, clinic or camp_week.
  - `uses_boats`, plus the count overrides.
- `plan_trips` describes regatta travel. Its fields:
  - `offering`, `starts_on` and `ends_on`, plus `external_event_ref`.
  - The travel days before and after, travel hours per day, and trailer load and unload minutes.
  - `nights`, `airfare_cents` and `miles`.

  The engine expands a trip into `travel` activities. They are paid hours, but not on-water, RIB or boat time. Meals, lodging, mileage and incidentals are offering formulas over the trip and the derived coach count. Examples: `meals = meal_per_diem * coach_days`, and `lodging = nights * lodging_rate * coaches`.

- `plan_activities` are generated from rules and trips. Their fields: `offering`, `schedule_rule`, `trip`, `date`, `start_time`, `end_time`, `on_water_minutes`, `setup_minutes`, `putaway_minutes`, `kind`, the count overrides, and `overridden`.
  - Editing a rule regenerates its activities, except the ones marked `overridden`.
  - The planner can add one-off activities or cancel single days.
- `plan_activity_resources (activity, resource_key, quantity, hours)` holds extra resources a single activity uses, such as two hours of the clubhouse for a regatta debrief.

**Direct money and labor**

- `plan_budget_lines` whose cost center is one of this plan's offerings or its product. Examples: instructor gear, the summer head instructor's visa, or a program's depreciation (flagged `is_non_cash`).
- `plan_labor_lines (name, cost_center, staff_level | hours | hours_formula, phasing, account, function)` holds labor that isn't tied to an activity: head-instructor weeks, supervisor hours and training.
  - It is priced at a staff level.
  - It counts toward the `wages` and `paid_hours` metrics, so payroll tax and L&I see it.

### Operations plan collections

**Rates and assumptions** (each with `effective_from`)

- `plan_assumptions (name, value, unit, note)` holds named scalars: FICA %, unemployment %, L&I per hour, B&O %, card fee %, scholarship %, wage increase %, the summer fill rate, meal and lodging rates, and the loaded-cost factor. Formulas and the engine read them by name.
- `plan_staff_levels (name, pay_type: hourly|volunteer, hourly_rate, qualifications[])` is the hourly coach ladder (tiers 1–5), plus a volunteer level with a zero rate. Plans staff by level, not by named person, which keeps per-person wages out of the model.
- `plan_salaried_positions` describes a role, not a person. Its fields:
  - `name`, `annual_salary`, `paid_hours_per_year` and `qualifications[]`.
  - `ga_share`: the fixed G&A fraction.
  - `remainder_pool`: the pool that takes unbooked hours, which is program admin, spread by MTDC.
  - `form_990_line`: an override, because the director's salary goes on 990 line 5, not line 7.
  - `effective_from` and `effective_to`. Cost is prorated for a role that starts or ends partway through the year.
- `plan_resources (resource_kind, name, quantity, cost_per_hour, cost_per_day, fuel_per_hour, maintenance_per_hour)`. `quantity` is the fleet size, such as two RIBs. A scenario that buys a RIB changes this row. A rented RIB is a row with a per-day rate.
- `plan_boat_rates (boat_class, maintenance_per_boat_hour)`.

**Salaried hour bookings**

`plan_salaried_bookings (position, product_id, starts_on, ends_on, kind: management, hours)` holds management hours, such as 300 hours managing the double-handed race team. The dates let a booking cover only the fall, or only the spring. A position's paid hours split four ways:

1. **Coaching hours**, worked out from the activity blocks and offerings the position coaches. They are charged to those offerings.
2. **Management hours**, from these bookings. They are charged to the product, and spread over its offerings active in the booking's dates by their MTDC.
3. **The G&A share:** `ga_share` × hours, which goes to the G&A pool.
4. **The remainder,** which goes to `remainder_pool`.

Each hour costs `annual_salary ÷ paid_hours_per_year`. If coaching, management and the G&A share together exceed the paid hours, the engine warns about over-booking.

**Activity blocks**

`plan_activity_block_rules (name, offering_keys[], weekdays[], starts_on, ends_on, coach_level, salaried_positions[])` records that J-Pod and K-Pod share on Wednesdays.

- The planner sets the block's hourly coach level, because the programs in it decide what coaching it needs.
- `salaried_positions` lists the salaried roles who coach in the block.
- Activities that match on the same date with overlapping times form one activity block.
- An activity in no block is a block of one. It uses its offering's `coach_level`, plus any salaried position assigned through a solo block rule.

**Bonus owners**

`plan_bonus_owners (role_name, bonus_rate, account, starts_on, ends_on)` and `plan_bonus_owner_products (owner, product)` record which role owns which products. One example is "Single-handed head coach" owning the single-handed products. The bonus is `bonus_rate × max(0, the combined net of the owned products)`, so a loss on one owned product offsets gains on another.

**Org money, pools and formulas**

- `plan_budget_lines` carry these fields:
  - `name`, `account` and `function` (program, management or fundraising).
  - The cost center: an offering, a product, a pool or the org. A product line also has a `spread` (by MTDC, by revenue, even, or by months) that pushes it down to that product's offerings.
  - `amount` or `formula`, and `fiscal_year`.
  - `phasing_mode` (annual_split or monthly_rate) and `phasing`.
  - The flags `is_participant_support`, `is_capital`, `is_non_cash` and `excluded_from_base`.
  - `note`.

  These hold the lump sums the sheet types in:
  - insurance and the clubhouse fee
  - the Clubspot and QuickBooks fees
  - grants and gifts
  - fundraising events and their costs
  - capital purchases

- `plan_formulas` are named line items in a small spreadsheet-like language, over assumptions and engine metrics. Their fields: `name`, `dimension` (none, offering, product or month), `expression`, `account`, `function`, `cost_center_type`, `applies_to_filter`, `excluded_from_base` and `note`.
  - The metrics include `revenue`, `wages`, `coach_hours`, `paid_hours`, `rib_hours`, `boat_hours`, `enrollment`, `coaches`, `coach_days` and `travel_days`.
  - Examples: `scholarships[offering] = -scholarship_rate * revenue[offering]` and `payroll_tax[offering] = -payroll_tax_rate * wages[offering]`.
  - Formulas are parsed on save, and their dependencies are stored in `plan_formula_deps`. That catches cycles at save time, and answers "what depends on the fill rate?".
- `plan_pools` define the overhead pools. Their fields are `name`, `step_order`, `method`, `base`, `base_categories[]`, `targets_filter`, `denominator_quantity`, `unit`, `remainder_pool` and `phasing`.
  - **Methods** are `base_share`, `fixed_shares`, `area` and `formula`.
  - **Bases** are metrics computed per offering: CYC MTDC, coach-hours, RIB-hours, boat-hours, revenue, enrollment or sailor-hours. A base's membership comes from cost categories, so whether storage counts toward MTDC is a version setting, not code.
  - **Order.** Pools run in `step_order`: storage first, then program admin, then G&A over a base that includes them. A base never includes the pool's own allocation, or anything flagged `excluded_from_base`.
  - **Area pools** divide by `denominator_quantity`, the club's capacity, not by the sum of the shares. Unclaimed space then flows to `remainder_pool`, which for storage is G&A. That fixes workbook bug 4 by construction.
  - **Phasing** says how an allocated amount lands by month: by the base's months, evenly, or over the target's active months.
- `plan_pool_shares (pool, target_type: offering|product, target_key, share | quantity | amount, starts_on, ends_on)` holds fixed shares, areas and dollar amounts. Because shares carry dates, summer can take 100% of the float in June to August while linear feet split it the rest of the year.

Changing how G&A is allocated is a one-row change in one Operations Plan version, and it shows in a diff. That is the structural fork the architecture notes ask for.

### ER diagrams

The ER diagrams live in `docs/planning-schema.md`.

### Why the core is typed, not a pure formula graph

The architecture notes proposed storing the whole model as a formula graph. That works for line items, allocations and the bonus. It fits activities, activity blocks and step costs badly. "Block these activities together, add each offering's coach load per qualification, round up, fill from salaried staff first, charge the rest at the block's level" is a small program, not a cell formula. Writing it as formulas would put a hard-to-read model in front of board members.

So the core (activities, activity blocks, staffing, resources, revenue) is typed data computed by engine code. Every place the treasurer makes a policy choice is data: assumptions, formulas, pools and bases, and the cost-category membership of each base. A fork can change any of those. A fork can't change how a coach load is rounded without a code change.

### The calculation

The engine is a pure TypeScript package. It takes a resolved version set and returns results. The same package runs in two places: in the browser, for instant recalculation while editing, and in the Directus extension, for caching saved version sets. It follows project-two's shape: integer cents, and every line carries a `kind`, an explanation and warnings.

1. **Resolve.** Load the version set's Operations Plan version and product plan versions. Resolve the keys that cross plans, and the rates in effect on each activity's date.
2. **Activities.** Expand schedule rules and trips into activities, keeping the overridden ones. Enrollment is `target_enrollment`, or `fill_rate` × capacity.
3. **Activity blocks.** Form each block from its rule. A lone activity is a block of its own.
4. **Coach requirement,** for each activity block and qualification.
   - Each offering's load is `enrollment ÷ sailors_per_coach`.
   - The required count is `ceil(Σ load)`, and never below the largest `min_coaches` among the offerings.
   - A fixed count on the activity, rule or offering replaces the derived count, checked in that order.
   - Example: 5 J-Pod sailors at 1:8 plus 7 K-Pod sailors at 1:12 is 0.63 + 0.58 = 1.21, which needs 2 coaches. At a shared 1:12 it is 1.0, which needs 1 coach.
5. **Filling the requirement.**
   - Fill first from the block's salaried positions, then from volunteers. Use `qualification_covers` in a greedy pass from the most specific requirement outward.
   - The rest are hourly coaches at the block's level. Overtime isn't modelled.
6. **Coach cost.**
   - Cost is coaches × (activity minutes + setup + putaway) × rate. Travel activities count too.
   - A salaried coach's hours are priced at salary ÷ paid hours, and count as that position's coaching hours.
   - Each offering's share of the block's cost is its share of the block's load.
   - The engine also prices each offering as if it sailed alone, so the UI can show what sharing saves.
7. **RIBs.**
   - Required RIBs are coaches × `ribs_per_coach`, or the fixed count, for the on-water minutes.
   - Concurrent RIB demand across all activity blocks is checked against the fleet `quantity`. Going over raises a warning, not a cost.
   - RIB-hours × (fuel + maintenance) is charged using the same shares. A rented RIB is charged per day.
8. **Boats.**
   - Boats per class are `ceil(enrollment × class share × (1 − byob_share) ÷ sailors_per_boat)`, or the fixed count. A rule with `uses_boats = false` has none.
   - Boat-hours are charged at the class's maintenance rate.
9. **Other resources and labor lines.** Each activity's extra resources are charged at their rates. Labor lines are priced at their staff level.
10. **Revenue** is price × enrollment, or price × units, weighted by price tier. It is booked on two bases:
    - **accrual:** by delivery, spread over the offering's activities or months
    - **cash:** by the registration curve

    The workbook's per-hour LTS proration is a `price_basis` choice, not a hidden formula.

11. **Salaried split.** Coaching hours come from step 6 and management hours from the dated bookings. The G&A share follows, and the remainder goes to its pool.
12. **Budget lines and formulas** are evaluated in dependency order. Product-level amounts are spread to offerings by their `spread` rule.
13. **Pools** are allocated in `step_order`, separately for each fiscal year.
    - The pool is that year's budget, plus any remainder handed down from earlier pools.
    - The base is each offering's metric within that year. Dated pool shares apply only in their windows.
    - An offering that runs from November to February gets a share of both years' G&A.
    - Allocated amounts are phased by month, according to the pool's `phasing`.
14. **Bonus.** Each bonus owner's bonus is `bonus_rate × max(0, the combined net of its products)`. It's kept out of every base, so G&A never depends on it.
15. **Reconciliation.** The product P&Ls plus every pool's unallocated remainder must equal the org P&L to the cent. A mismatch is an error, not a footnote. Non-cash lines (depreciation) are reported below operating income, and count only in full-cost recovery.

**Results** are rows of `(version_set_key, cost_center_type, cost_center_key, account, function, basis, month, amount_cents, line_key, explanation)`. Metrics such as coach-hours, paid hours, RIB-hours, boat-hours, wages and enrollment sit in a sibling table.

These rows already have the shape actuals will have. Plan vs plan, plan vs actual and the 990 functional-expense matrix are each one grouped query. Fiscal-year reports filter on month. Saved version sets (baselines) cache their results in `plan_results`. Drafts and scenarios are computed on demand.

**Views** built from those results, matching what the treasurer uses now:

- each offering's P&L, rolled up by product and by any application's grouping, per fiscal year
- the monthly statement of activities, on the accrual basis
- monthly revenue on the cash basis
- Planned (the baseline), Current (to date) and Forecast (a scenario with `actuals_through`)
- the cost recovery rate, and full-cost recovery after depreciation
- G&A as a share of revenue and of MTDC
- each salaried position's hour split, and the bonus per owner
- derived vs fixed coach, RIB and boat counts per offering
- break-even enrollment and price, by re-evaluating at enrollment ±1. Coach counts step, so there is no closed form, and the view shows where each step falls.
- marginal +1 sailor and +1 practice, by the same re-evaluation
- standalone vs pooled cost for each activity block

### Versions in Directus

- **Endpoints.** Fork, save, activate, freeze, evaluate and diff are endpoints in a Directus endpoint extension.
  - Fork, save and freeze use Knex in one transaction, with `INSERT … SELECT` and the deterministic id remap. The plain REST API can't span requests in a transaction.
  - Ordinary edits go through Directus (`ItemsService` or REST). That keeps permissions working, and `directus_revisions` records who changed what in a draft.
- **Immutability.**
  - A Postgres trigger rejects any write to a row whose version is `saved`. It also rejects any change to a frozen version set.
  - A Directus permission filter on `version_id.status = draft` tells the UI the same thing. Custom permission rules need a licensed instance (#172), though, so the trigger is the real guard.
- **Concurrent editing.** A Directus PATCH sends only the fields that changed, so two editors on different fields don't overwrite each other. Two edits to the same field are last-write-wins. Directus WebSocket subscriptions push changes to the other editors' screens.
- **Diff.**
  - Two version sets are compared by which version each plan uses, then field by field inside every plan that differs. That's a full outer join on `key` per collection.
  - Results are compared by a join on `(cost_center_key, account, month)`.
  - Because `parent_version_id` is stored, a three-way "pull changes from the parent" can be added later without a schema change.
- **Forecasts and variance.**
  - A forecast is a scenario with `actuals_through` set. Once actuals exist, the engine replaces months up to that date with actuals, and replaces offering enrollment with Clubspot's confirmed count.
  - Variance is measured against a chosen baseline.

Directus Content Versioning isn't used. It versions single items, not a whole model with lineage.

### Permissions

The plan data includes wage rates, bonuses and full program economics. Today `staffPermissionRules` grants Staff full CRUD on every collection in the merged schema (`packages/infrastructure/src/crm/index.ts:88-118`). Coach reads `programs` with no field limit.

- The planning collections need a carve-out from Staff, and a Planning policy of their own.
- No planning data should sit on `products` as an extension field, because coaches can read every field there.
- Moving `programs` into `core.products` doesn't change who can read program products. The Coach and Community rules move with it.

### The app

The front end is a separate TypeScript web app, built like the portal: an Authentik session against Directus, through the Directus SDK. Its screens:

- the active version set, with each plan's version history
- scenarios and baselines
- the offering editor
- schedules and activity blocks on a week grid
- results views
- the compare view
- the formula editor, which validates as you type

The Data Studio stays the editor for the `core` catalog.

## Alternatives considered

- **One plan for everything,** where "per program" is only a view. Rejected. The org thinks of a plan per program, and switching one program's plan would mean forking the whole org's.
- **Overlay or delta tables,** where a child stores only its overrides. Rejected:
  - Every read resolves up a chain.
  - A parent's edit silently changes its children.
  - The Data Studio can't show resolved values.
- **Dolt or Doltgres.** These were the architecture notes' fastest prototype. Rejected because Directus already runs on Cloud SQL Postgres. Dolt branches the whole database, including Directus's own tables, and comparing plans would need queries across branches that Directus doesn't understand.
- **Neon or Supabase branching.** Rejected. These are developer branches of a whole cluster, with no data diff, and with quotas.
- **Event sourcing.** Rejected for now. It makes rebase natural, but every read needs a projection, and Directus can't edit through it. `directus_revisions` already gives the change log.
- **Temporal tables for branching.** Rejected. They track one timeline, and scenarios are parallel timelines. Valid time is used, but only inside a version, for effective-dated rates.
- **A pure formula graph,** from the architecture notes. Rejected for the activity and staffing core, and kept for line items, allocation and the bonus.
- **Copying project-two's engine.** Rejected. It lacks ratio step costs, resources and versioning, and its staffing inputs live in JSON. Its cost-line shape, profit share, trip model and forecast timing are worth reusing.
- **Inferring activity blocks from overlapping times.** Rejected. The planner sets blocks explicitly.
- **Tenant mode** (project-two's club fee as a % of sales, or MTDC against a club-wide denominator). Rejected. The model covers the whole Sailing Center.
- **Weekly overtime.** Not modelled. The sheet doesn't have it, and plans staff by level, not by person.
- **Calling an offering a "session".** Rejected. A Clubspot session holds several classes, and coaches already use "session" for a practice day.
- **Program as the period-bound thing, with no lasting entity.** Rejected. A product plan, management hours, the bonus and isthmia's role assignments all need the lasting product.

## Open questions

1. **Activation.** Does activating a product version need approval from the treasurer or the board, or can any planner do it? Variance uses baselines, so activation can stay lightweight.
2. **Scholarships** are a percentage at org level in the sheet, outside every program and outside MTDC. The draft charges them per offering, which lowers each program's P&L by that percentage. Does the treasurer agree?
3. **Payroll tax.** Is it a direct cost in the MTDC base, as in the sheet, or G&A? The sheet applies one blended rate to every wage dollar.
4. **The boat-hours base.** Is it on-water minutes or the whole activity? The sheet uses session hours for most programs, and a fraction of them for summer.
5. **Merchandise.** Does it get its own offering cost center and a share of G&A, or stay at org level as in the sheet?
6. **Schema location.** `core`, `crm` and the planning package each need a home. That depends on the schema-split decision.

## Out of scope for planning

These project-two features belong elsewhere:

- **CSV import, the billing mirror and reconciliation rules:** clubspot-sync and the actuals import.
- **Identity hashing, named staff, outreach and leads:** the CRM.
- **Regatta scrapers and calendars:** a calendar service. Planning reads it only to anchor trips.
- **Attendance and rosters.**
- **The per-boat asset register** (boats, racks, assignments, damage, the usage ledger): a later asset domain. When it arrives, planning reads fleet counts from it for usage-driven depreciation.

## Later

- The cash position, payables and receivables, reserve months, runway, and the capital wish list. These stay in the sheet for now.
- Usage-driven boat depreciation (charter life, then beginner life, scaled by peak same-day use) and derived storage areas from boat footprints.
- Venues with dusk end times, and checking activities against holidays and the regatta calendar.
- A three-way "pull from parent", and Shapley or marginal splits if anyone disputes shared-cost shares.

## Steps

- [ ] Review this model with the treasurer. Start with the workbook findings, the CYC MTDC definition, the salaried hour split, and derived vs typed counts.
- [ ] Engine package: a pure TypeScript engine with unit tests. Write Gherkin features for the staffing rules (including the J-Pod and K-Pod example), the salaried split, allocation by fiscal year, the bonus and reconciliation.
- [ ] Golden test: encode the 2026 workbook as fixture data and match its numbers. Document each deliberate fix as a known difference. The treasurer's trust depends on this test.
- [ ] `core` domain: create the catalog collections, and move `crm.programs` into `products`. Then update gsuite-sync, clubspot's `classes.program_id`, role assignments, and the permission rules that read it.
- [ ] Planning schema: plans, versions, version sets, version-scoped collections, the immutability trigger, the Planning policy and the Staff carve-out.
- [ ] Directus extension: endpoints for fork, save, activate, freeze, evaluate (with the results cache) and diff.
- [ ] Web app: the active version set and history, scenarios, the offering, schedule and activity block editors, P&L views, compare and the formula editor.
- [ ] Import the 2026 workbook as the first saved versions (one per product, plus the Operations Plan). Import the typed counts as fixed overrides, and report them against the derived counts. Activate the versions, and freeze them as the FY26 baseline.
- [ ] Actuals: Clubspot enrollment through `offering_external_refs` and isthmia's registrations, plus forecasts with `actuals_through`.
- [ ] Actuals: a QBO expense import by account, class and month, with QBO-to-Clubspot reconciliation after it.
