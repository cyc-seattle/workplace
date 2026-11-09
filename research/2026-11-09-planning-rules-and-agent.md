# Planning: free-text rules, a planning agent that allocates, and engine warnings

Research for [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149). It proposes which planning inputs stay hard settings, where the free-text rules live, what the planning agent does, and which warnings the engine calculates. It ends with a build order by repo. Nothing here is built yet.

## Context

### Sources

- [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149), with the maintainer's quotes from 2026-11-09.
- The maintainer's feedback on the wireframes in [cyc-seattle/sail-team#64](https://github.com/cyc-seattle/sail-team/pull/64), recorded in [cyc-seattle/sail-team#63](https://github.com/cyc-seattle/sail-team/issues/63).
- platform's `docs/planning-engine.md`, `docs/planning-schema.md` and `src/planning/` at 251caccb.
- [2026-10-18-program-financial-model.md](2026-10-18-program-financial-model.md), the data model and engine design, and the trial review in [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6).
- [2026-11-07-sailops-requirements.md](2026-11-07-sailops-requirements.md), and [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) and [#31](https://github.com/cyc-seattle/sail-team/issues/31).

### What the maintainer said

> The planning process should involve using an agent to allocate resources, then calculating the result of that allocation, including possible warnings.

> Guppies may be staffed by a "Level 1 Instructor", using Sailqubes at a 10:1 ratio, but we might write rules for "If there are more than 12 guppies, we need a Junior Instructor" and "Guppies can also use the Harpoon with up to 10 kids instead of Sailqubes". These rules are used by the planning agent who makes hard allocations based on constraints. Then the engine can calculate warnings like "July 13th, the Guppie program is allocated 14 sailqubes, but you only have 12 available".

Settled in the issue:

- A program's hard settings are its **staff level** and **sailors per coach**. A boat class's is **sailors per boat**.
- **RIBs and coaches are allocated to activity blocks.** No ratio derives them.
- Everything else is a **free-text rule**, on a program or plan-wide.
- The **agent** reads settings and rules and writes concrete allocations. The **engine** costs those allocations, and warns where they break a limit.

### How the engine works today

The engine derives staffing. For each activity it calculates coaches from enrollment ÷ `sailors_per_coach`, at least `min_coaches`. It calculates RIBs as coaches × `ribs_per_coach`, and boats from enrollment × (1 − `byob_share`) split across the offering's boat classes by share. Any of these can be pinned with `fixed_coaches`, `fixed_ribs` or `fixed_boats`, on the offering or the activity. Recurring `plan_activity_block_rules` (offerings × weekdays × date range) group activities that share coaches. The engine then works out each date's groups from overlapping times, and fills the group's coaches from salaried positions first. Most of the 624 lines of `staffing.ts` are this derivation.

Two things already exist that this proposal builds on:

- **Rules.** Each plan copy has a free-text `rules` field (decision 25 in [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6)). The planner's AI reads it. The engine never does. It's saved with the Financial Plan.
- **Warnings.** The engine returns `warnings`, and the `saved-versions` hook stores them in `plan_result_warnings` with each Financial Plan's results. Nothing shows them yet.

`plan_formulas`, from the original design, was never built.

## Approach

The model splits in three:

1. **Hard settings:** the few numbers every plan respects and the engine can check.
2. **Rules:** plain text that only the agent reads.
3. **Allocations:** what the agent decides: which staff, RIBs and boats each activity block gets on each date. The engine costs allocations as given.

The engine stops deciding how many coaches, RIBs or boats an activity needs. It prices what's allocated, and warns when an allocation breaks a hard setting or exceeds what the club has.

### Hard settings and rules

| Today's input                                                                                                                                                         | Where              | Proposal                                                                                           |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------- |
| `sailors_per_coach`                                                                                                                                                   | offering           | **Keep, move to the program** (new `plan_programs`)                                                |
| `coach_level_key`                                                                                                                                                     | offering           | **Keep, move to the program** as `staff_level_key`                                                 |
| `min_coaches`                                                                                                                                                         | offering           | **Rule** ("never fewer than 2 on the water")                                                       |
| `required_qualification`                                                                                                                                              | offering           | **Drop.** The program's staff level carries its qualifications                                     |
| `ribs_per_coach`                                                                                                                                                      | offering           | **Drop.** RIBs are allocated                                                                       |
| `byob_share`                                                                                                                                                          | offering           | **Rule** ("about a third bring their own boat")                                                    |
| `fixed_coaches`, `fixed_ribs`, `fixed_boats`                                                                                                                          | offering, activity | **Drop.** The allocation is the count                                                              |
| `coach_position_key`, `coach_position_pay`                                                                                                                            | offering           | **Drop.** A salaried position is allocated to a block like any staff; a rule says who coaches what |
| `plan_offering_boat_classes` (class and share)                                                                                                                        | offering           | **Rule** ("Guppies sail Sailqubes; the Harpoon can take up to 10 instead")                         |
| `plan_activity_block_rules` (offerings, weekdays, dates, level, salaried staff)                                                                                       | Operations Plan    | **Rule** ("J-Pod and K-Pod share coaches on Wednesdays"). The agent writes concrete blocks         |
| `plan_activity_resources`                                                                                                                                             | activity           | **Move to the block**, as a resource allocation                                                    |
| `boat_classes.sailors_per_boat`                                                                                                                                       | catalog            | **Keep**                                                                                           |
| Boat inventory                                                                                                                                                        | none               | **Add** a `quantity` to `plan_boat_rates`, so the engine can check boats against it                |
| `plan_resources.quantity` (RIBs and other equipment)                                                                                                                  | Operations Plan    | **Keep.** It's the inventory the engine checks                                                     |
| `rib_resource_kind_id`                                                                                                                                                | Operations Plan    | **Keep**, only to say that a RIB's hours are its time on the water                                 |
| Offering dates, capacity, `target_enrollment`, `fill_rate`, price, `cogs_rate`                                                                                        | offering           | **Keep**                                                                                           |
| Activity date, times, `on_water_minutes`, setup, put-away, kind, `uses_boats`, trip                                                                                   | activity           | **Keep**                                                                                           |
| Staff levels, salaried positions and bookings, rates, resources' costs, boat rates, pools, revenue charges, bonus owners, closed dates, budget and labor lines, trips | plans              | **Keep.** These are money settings, not allocation                                                 |
| `plan_formulas`                                                                                                                                                       | design only        | **Drop from the design.** Revenue charges cover the percentages, and rules cover the rest          |

What stays hard is what the engine needs to price a plan, or check an allocation against. Everything that's a planner's judgment about staffing becomes a rule.

### Where rules live

Rules live in three places, all free text, all inside a plan copy:

- **On each program:** a new `plan_programs` row in the Program Plan copy, one per program, holding `staff_level_key`, `sailors_per_coach` and `rules`. "If there are more than 12 Guppies, add a Junior Instructor" goes here.
- **On the program area:** the Program Plan copy's existing `rules`, for what spans its programs ("J-Pod and K-Pod share coaches on Wednesdays").
- **On Assumptions:** the Operations Plan copy's existing `rules`, for club-wide rules ("keep one RIB ashore for repairs on summer weekdays").

Versioning comes free. Each is a row or field in a plan copy, so it's copied into each new draft, compared between Financial Plans, and frozen when one is saved, like every other input. `plan_programs` is versioned rather than set on the catalog's `programs`, so two drafts can try different ratios.

Each field is one block of text, read as a list, not a table of separate rule rows. A list of rows would invite tracking which rule made which allocation, which decision 25 ruled out.

### Allocations

Activity blocks become concrete. A block is one or more activities on one date that share staff and boats, such as Guppies and Minnows on the morning of July 13. The agent creates blocks. Nothing derives them.

- **`plan_activity_blocks`:** `date` and `name`. Its time is the span of its activities, with their setup and put-away. Every activity that needs staff or boats is in exactly one block, through a new `plan_activities.block_id`. An activity that sails alone is a block of one.
- **`plan_block_staff`:** `block_id`, then a `staff_level_key` or a salaried `position_key`, a `count`, and for a position, `pay` (`salary` or `hourly`, as `coach_position_pay` works today).
- **`plan_block_resources`:** `block_id`, `resource_key`, `quantity`, and optional `hours`. RIBs are resources of the RIB kind. A RIB's hours default to the block's time on the water, and other resources' to its paid time.
- **`plan_block_boats`:** `block_id`, `boat_class_id`, `count` (the club's boats) and `sailor_owned` (boats the sailors bring). See [Bring-your-own-boat](#bring-your-own-boat).

The engine charges a block's staff, RIBs, boats and resources the way it does today, by hours and rates, and splits them among the block's offerings by enrollment. Trips take their coaches from the staff on their travel-day blocks.

Nothing records which rule made which allocation (decision 25). The agent's report on a run goes in the Financial Plan's note.

### Warnings

The engine checks allocations against hard settings and inventory. New checks:

| Code                      | When                                                                                            | Example                                                                                                                             |
| ------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `over_inventory_boats`    | Boats of one class allocated at the same time on a date exceed the Operations Plan's quantity   | July 13: 14 Sailqubes allocated, 12 available (Guppies 9, Minnows 5)                                                                |
| `over_inventory_resource` | RIBs, or any resource with a quantity, allocated at the same time exceed it                     | July 13: 7 RIBs allocated, 6 available                                                                                              |
| `over_capacity`           | A block's target sailors exceed what its allocation can safely take. See [Capacity](#capacity). | July 13, Guppies: 14 sailors, but the allocation takes 10 (1 Level 1 Instructor at 10 per coach; 7 Sailqubes at 2 per boat take 14) |
| `unallocated_activity`    | An activity other than travel is in no block, or its block has no staff                         | Aug 2, J-Pod practice has no staff                                                                                                  |

These existing checks stay: a salaried position double-booked across overlapping blocks, an activity on a closed date, a boat class with no sailors per boat, and the data warnings (a missing account, a missing row, a program with no area, and the rest). These go away: `unqualified_level` (now part of `over_capacity`) and `no_coach_level` (a staff row always names a level).

#### Capacity

A block's capacity is the lower of two numbers, from its allocation and the hard settings:

- **Staff:** each allocated staff member at a program's staff level, or at a level whose qualifications include it, takes that program's sailors per coach. In a block of several programs, each program's sailors count against its own ratio: the block is over when Σ (a program's sailors ÷ its sailors per coach) is more than its qualified staff.
- **Boats:** Σ (boats × the class's sailors per boat), counting the club's boats and the sailors' own.

When the block's target sailors (each offering's enrollment) are more than its capacity, the engine warns, and names which limit it hit.

#### Bring-your-own-boat

The agent allocates the sailors' own boats, in `plan_block_boats.sailor_owned`, from the program's rule ("about a third bring their own Optis"). They count toward capacity, but not toward inventory, and cost no upkeep.

A program setting that leaves boats out of the capacity check was the other choice. It was rejected because it turns off the boat check for the whole program, when most of its sailors still sail the club's boats, and it brings back a hard setting the maintainer wanted as a rule. With an explicit count, the rule stays text, the agent turns it into a number for each block, and the capacity and inventory checks both stay true.

`plan_result_warnings` gains three columns:

- `version_set_member_id`: the plan it's about, so a program area's page can filter its own.
- `date`: for warnings about a date.
- `category`: `allocation` for the four checks above, plus closed dates and double-booking, or `data` for the rest.

The **Overview** shows a warnings card under its first table: a count by program area, allocation warnings first, each linking to its program area page, which lists them by date. A saved Financial Plan's warnings are frozen with its results, so a board reviewing the active plan sees what it was saved with.

### The planning agent

The agent is a skill in platform's `.agents/skills/`, next to the schema it writes to, so a schema change updates it in the same PR. A planner runs it with their own Claude over Directus's MCP, with their own permissions. This reverses decision 25's "no planning skill in platform" ([cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6)). The rest of decision 25 stands: the engine never reads rules, and nothing tracks which rule made which row.

**Inputs.** It reads, from one draft Financial Plan:

- the hard settings: each program's staff level and sailors per coach, boat classes' sailors per boat, staff levels and positions, and inventory (boat and resource quantities)
- the rules on each program, each Program Plan and the Operations Plan
- offerings with their enrollment, activities, closed dates and trips
- the draft's current warnings

**Loop.**

1. It works in a new draft Financial Plan started from the one the planner names, so the planner's own draft is untouched. The name says it's the agent's ("2027 allocations, Nov 9").
2. For each date, it groups activities into blocks by the rules, then allocates staff, RIBs and boats by the hard settings and rules, including the sailors' own boats.
3. It waits for the hook to recalculate (about a second), reads the warnings, and fixes what it can within the rules.
4. It stops when only warnings it can't fix are left, such as a date that needs more Sailqubes than the club has. It writes a short report in the Financial Plan's note: what it changed, and which warnings are left and why.

It can also run on part of a plan ("re-allocate Summer weeks 3 to 5"), rewriting only those blocks.

**Review and acceptance.** The agent's draft is the proposal. The planner opens it in sail-team, reads the Overview's warnings and the program area pages, and compares it with the plan it started from. To accept it, a Plan Writer saves it, and marks it active if it's the one to run. To reject it, they delete the draft, or tell the agent what to change. This uses what Financial Plans already do, so it needs no approval step of its own.

The agent is non-deterministic, but its output is rows, and the engine calculates only from rows. A saved Financial Plan reproduces exactly, however its allocations were made.

A button in sail-team that runs the agent on the server is left for later. It needs an API key, a queue and a cost limit, and planners can use their own Claude today.

### Existing plans

Nothing is converted. Every existing Financial Plan, saved or draft, is deleted with its plan copies, rows and results, and a fresh one is drafted under the new model. The old fields and `plan_activity_block_rules` are dropped outright.

The `saved-versions` triggers refuse to delete a saved Financial Plan on every path, and prod refuses `backend:savedVersionsDeletable`. So the delete is a one-time Directus migration in `stacks/backend/migrations/` that runs as the database owner with the triggers off for its own transaction. It does nothing on a database with no plans, so it's safe to run again. The maintainer confirms it before it runs in prod.

### The treasurer's workbook import

The workbook types counts, which suits allocation better than ratios:

- The offering table's coach level and sailors per coach become each program's hard settings. Where a program's offerings disagree, the most common goes in the setting, and the rest go in the program's rules.
- Typed coach, RIB and boat counts become each block's allocation as they stand, with no derived counts to compare against.
- The bring-your-own-boat flag becomes a sentence in the program's rules, and the agent allocates those sailors' boats as `sailor_owned`.
- A shared coach typed as a fraction ("1.45 instructors") becomes one block shared by those offerings, with a whole number of staff.

The engine's warnings replace the planned "typed against derived" report. Where the workbook's counts break a ratio or the inventory, the warning is the item to review with the treasurer.

### What changes for sail-team

**[cyc-seattle/sail-team#64](https://github.com/cyc-seattle/sail-team/pull/64)**, once this is approved: the program settings section shows the staff level, sailors per coach and the program's rules. Assumptions shows the Operations Plan's rules, and each program area page its own. The Overview gets the warnings card. RIBs per coach and bring-your-own-boat are already gone from the wireframes.

**[cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)** (planning offerings on screen):

- An offering no longer has a coach level or boat classes. Its kind, dates, capacity, expected sailors and price stay.
- Coach level and sailors per coach are set once per program, and the program's rules are edited beside them.
- Clashes with closed dates are engine warnings, shown on the page, not a check of the editor's own.
- A new need: a view of a program area's blocks by date, with what's allocated and any warning against it. Editing allocations by hand there is optional; the agent does it first.

**[cyc-seattle/sail-team#31](https://github.com/cyc-seattle/sail-team/issues/31)** (settings):

- Add each boat class's quantity beside its upkeep rate, and the quantity of each RIB and resource.
- Add the Operations Plan's rules, as Assumptions' text.
- "Levels" means staff levels, of which instructor and coach are two.

## Alternatives considered

- **Allocations on each activity, with blocks only grouping them.** Rejected. Shared coaching is the reason for a block, and splitting one count across activities is what made typed fractions like 1.45 coaches.
- **Keep recurring block rules, and let the agent only set counts.** Rejected. "Share on Wednesdays except in August" is a rule, and the agent can expand it. Two places for sharing would disagree.
- **Rules as rows, one per rule, linked to the allocations they made.** Rejected by decision 25, and more than the maintainer asked for.
- **Program settings on the catalog's `programs`.** Rejected. They wouldn't be versioned, so two drafts couldn't try different ratios.
- **A program setting that leaves boats out of the capacity check,** for bring-your-own-boat programs. Rejected, as [above](#bring-your-own-boat).
- **Converting existing drafts,** by writing today's derived counts as allocations. Rejected by the maintainer: the plans are deleted and drafted again.
- **A note on each block saying which rule changed it.** Rejected: decision 25 stands on this.
- **Keep the ratio derivation as a fallback for blocks with no allocation.** Rejected. Two sources for one number is what the maintainer wants gone. An unallocated activity warns instead.
- **A server-side agent from the start.** Deferred, as above.

## Decisions

The maintainer settled these on 2026-11-09:

1. **Allocation shape:** dated blocks, one date with one or more activities, holding staff, RIB and boat allocations. They replace `plan_activity_block_rules`.
2. **The planning agent:** a skill in platform's `.agents/skills/`, run with the planner's own Claude over MCP, writing a new draft Financial Plan. This reverses decision 25 in [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) on that point.
3. **Warnings:** warn when more is allocated than the inventory has, and when target sailors exceed the capacity the allocation's staff and boats give, whichever is lower. Bring-your-own-boat sailors are counted through the boats the agent allocates for them ([Bring-your-own-boat](#bring-your-own-boat)).
4. **Existing plans:** no conversion. Every plan is deleted and a fresh one drafted; the old fields and data are dropped. The delete is confirmed with the maintainer before it runs.
5. **No block notes.** Decision 25 stands on tracking which rule made which row.

## Steps

Each step is one PR unless marked. A features step is reviewed before the code that turns it green.

**platform**

1. **Features:** program settings, blocks and allocations, sailor-owned boats, the four new warnings, and the agent's draft being saved like any other, written with the `write-feature` skill.
2. **Delete the plans [maintainer confirms]:** the one-time migration that deletes every Financial Plan, plan copy, row and result, tested in PGlite. It merges first, so the next step's dropped fields hold no data. Dev runs it in the merge queue. Prod runs it on the next deploy, after the maintainer confirms.
3. **Schema and engine together,** since the engine reads the new collections and the old fields go: add `plan_programs`, `plan_activity_blocks`, `plan_block_staff`, `plan_block_resources`, `plan_block_boats` (with `sailor_owned`), `plan_activities.block_id`, `quantity` on `plan_boat_rates`, and the three new columns on `plan_result_warnings`. Drop `plan_activity_block_rules`, `plan_offering_boat_classes`, `plan_activity_resources`, and the offering and activity fields the table marks drop or move, by migration where the apply can't. The engine costs allocations, adds `over_inventory_boats`, `over_inventory_resource`, `over_capacity` and `unallocated_activity`, and loses the ratio, RIB, boat-share, block-rule and fixed-count paths. Update the ER diagrams in `docs/planning-schema.md`, `docs/planning-engine.md`, `test/subtypes.test.ts` if needed, and `mise run schema-types`. `feat!:`, since apps reading the dropped fields break.
4. **The planning agent skill** in `.agents/skills/`, tried on a fresh 2027 draft in dev.
5. **Draft the fresh 2027 plan** in prod with the skill, from the treasurer's workbook as described above **[maintainer]**.

**sail-team**

6. **Wireframes:** add the rules, program settings and Overview warnings to [cyc-seattle/sail-team#64](https://github.com/cyc-seattle/sail-team/pull/64), or a follow-up PR if #64 has merged.
7. **Wire them up:** warnings on the Overview and program area pages, settings and rules read-only, from the stored results.
8. **Update [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) and [#31](https://github.com/cyc-seattle/sail-team/issues/31)** to match, including the blocks-by-date view.

**workplace**

9. **Amend decision 25** in [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6): the planning agent is a skill in platform. Tracking which rule made which row stays out.
