# Planning for two kinds of planners: the finance committee and program directors

Research for the maintainer's review with the volunteer building SailOps (2026-11-13). It covers how Planning in sail-team, and the planning model in platform, serve the finance committee, who set the rules, and program directors, who plan within them: roles and permissions, the screens, and how a fiscal year's plan changes as directors re-plan seasons. The maintainer's decisions of 2026-11-13 are folded in. Nothing here is built.

## Context

### What the maintainer said

> There are 2 somewhat different users here. On one hand, members of the board - and specifically the finance committee - who are responsible for planning out the whole fiscal year and, importantly, balancing the allocation of resources across programs which may compete with them. On the other hand we have program directors who are responsible for planning programs - possibly one term or season at a time, and are not as concerned with the overall organization-level.

> The finance committee needs to be in charge of creating new plans, freezing them, and making them active. And - importantly - setting the rules that govern the allocation process. The directors then can update their program plans, and use the platform to calculate costs so that they can figure out how to best price and fill their programs - and decide what programs to run. However, they shouldn't be able to change hard and fast rules.

> One group sets the rules of the game. The other group plays within them.

> Up until now I've been building the planning feature in Sail Team as if it serves both users - because in previous years the finance committee has also been the ones planning programs. This has changed with us hiring a program director who is financially motivated to fill his own programs.

### Sources

- platform `origin/main`: `docs/planning-schema.md`, `docs/access.md`, `stacks/backend/policies.ts`, `schemas/planning.yaml`.
- sail-team `main` at fb4ff3a3: `src/directus/access.ts`, `src/routes/plans/`.
- [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) (decisions 17–29), [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30), [#31](https://github.com/cyc-seattle/sail-team/issues/31), [#63](https://github.com/cyc-seattle/sail-team/issues/63), [#73](https://github.com/cyc-seattle/sail-team/issues/73), [#82](https://github.com/cyc-seattle/sail-team/issues/82), [cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126), [#149](https://github.com/cyc-seattle/platform/issues/149), [#206](https://github.com/cyc-seattle/platform/issues/206), [#208](https://github.com/cyc-seattle/platform/issues/208), [#139](https://github.com/cyc-seattle/platform/issues/139), [#138](https://github.com/cyc-seattle/platform/issues/138).
- [2026-11-07-sailops-requirements.md](2026-11-07-sailops-requirements.md) and [2026-11-09-planning-rules-and-agent.md](2026-11-09-planning-rules-and-agent.md).
- Draft PRs [cyc-seattle/platform#230](https://github.com/cyc-seattle/platform/pull/230) (coaches), [#231](https://github.com/cyc-seattle/platform/pull/231) (calendar) and [#232](https://github.com/cyc-seattle/platform/pull/232) (coaching recommendations).

### What exists today

**Lifecycle.** A Financial Plan (`version_sets`) is CSC's plan for one fiscal year. It holds one Operations Plan copy and at most one Program Plan copy per program area. Its `status` is `draft`, `saved` (the app says "frozen") or `active`. Only a frozen plan can be marked active, and an organization's year has at most one. A new Financial Plan starts as a copy of a parent, so drafts branch like git. Freezing saves every copy and the results together, and nothing changes afterwards, even for an admin (hook plus database triggers). A draft's results are worked out again about a second after any change, from any path.

**Program Plans are per area per year**, not per season. A season is only `plan_offerings.season_term`, free text. An offering's money falls in the plan year it starts in.

**Access.** Roles give base access, and groups give extra policies, which admins keep as data. Planning has two policies, both whole collections with no row filters or hidden fields:

| Policy      | Gives                                                                                         |
| ----------- | --------------------------------------------------------------------------------------------- |
| Plan Reader | Reads every plan, wages and bonus rates included, the catalog, and users' names               |
| Plan Writer | Changes every planning row in any draft, freezes a Financial Plan, marks one active, archives |

So today whoever can edit a program can also change payroll tax, the G&A pool and their own bonus rate, and freeze or activate the year's plan.

**Rules and choices.** Who should own each input, with the maintainer's decisions applied:

| Input                                                                           | Where it lives                                                                                                                                                             | Owner                                                     |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| Rates: payroll tax, lodging, mileage, coach-boat kind (`plan_rates`)            | Operations Plan                                                                                                                                                            | Committee                                                 |
| Staff levels and their hourly rates                                             | Operations Plan                                                                                                                                                            | Committee                                                 |
| Salaried positions: salary, G&A share, bookings                                 | Operations Plan                                                                                                                                                            | Committee                                                 |
| Resource and boat costs (per hour, per day, upkeep)                             | Operations Plan                                                                                                                                                            | Committee                                                 |
| How many boats and coach boats CSC has                                          | Moving from the Operations Plan to the `boats` list, counted per day by what's in service ([cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126)) | Whoever keeps the boat list                               |
| Pools (G&A, program admin) and their lines                                      | Operations Plan                                                                                                                                                            | Committee                                                 |
| Storage rent each area pays (dinghy float and dry storage)                      | Moving from each Program Plan to the Operations Plan, still charged to each area                                                                                           | Committee                                                 |
| Charges set as a share of revenue: scholarships, program buffer, B&O, card fees | Operations Plan                                                                                                                                                            | Committee                                                 |
| Bonuses: rate and basis                                                         | Operations Plan only (no longer in a Program Plan)                                                                                                                         | Committee                                                 |
| Closed dates, ranked capital, non-program offerings                             | Operations Plan                                                                                                                                                            | Committee                                                 |
| How shared costs are split (MTDC)                                               | Engine code                                                                                                                                                                | Platform                                                  |
| Accounts, products, areas, boat classes and their max capacity                  | Catalog                                                                                                                                                                    | Catalog Writer                                            |
| Safety rules, such as coaches per boat                                          | A separate "policy" feature, filed by the maintainer                                                                                                                       | Committee                                                 |
| A program's staff level and sailors per coach (its quality)                     | Program Plan (`plan_programs`)                                                                                                                                             | Director                                                  |
| Offerings: which run, season, dates, capacity, expected sailors, price, COGS    | Program Plan                                                                                                                                                               | Director                                                  |
| Activities, blocks and what each block is given                                 | Program Plan                                                                                                                                                               | Director                                                  |
| Trips, lines, free-text rules                                                   | Program Plan                                                                                                                                                               | Director, with a warning on lines that move costs (below) |

## Approach

The split is structural, not field by field. Directors change any Program Plan in any draft and can start drafts. Only the committee changes the Operations Plan, freezes a plan, and makes one active. Anything else a director could do to shift money, the engine shows as a warning before the committee activates the plan.

### a. Roles and permissions

**Split today's Plan Writer in two. Directors get Plan Writer; the committee gets Plan Writer and a new Plan Approver.**

|                                                   | Finance committee           | Program director                   | Board (not on the committee) |
| ------------------------------------------------- | --------------------------- | ---------------------------------- | ---------------------------- |
| Group gives                                       | Plan Writer + Plan Approver | Plan Writer                        | Plan Reader                  |
| Reads                                             | All of Planning             | All of Planning, salaries included | All of Planning              |
| Starts a draft (a copy of any plan)               | Yes                         | Yes                                | No                           |
| Changes any Program Plan in any draft, every area | Yes                         | Yes                                | No                           |
| Changes the Operations Plan                       | Yes, in a draft             | No: shown, read-only               | No                           |
| Freezes, makes active, archives                   | Yes                         | No                                 | No                           |

- **Plan Writer** (narrowed): reads all of Planning; creates `version_sets` drafts and deletes drafts; writes every planning row whose copy is a Program Plan. On collections that both kinds of plan use (offerings, budget and labor lines), the row rule is one many-to-one path, `version_id.plan_id.kind` equal to `program_area`. Collections only the Operations Plan uses (`plan_rates`, staff levels, salaried positions, resources, pools, revenue charges, bonus owners, closed dates, capital) get no write rule. On `version_sets` it writes `name`, `message` and `parent_id`, not `status` or the effective date.
- **Plan Approver** (new): writes the Operations Plan's rows, `version_sets.status`, the effective date and `archived_at`, and adds or takes out a draft's plans.
- **No per-area access.** Every director reads and writes every area, so `program_area_role_assignments` isn't used for access, and no read rule changes. The query guard has nothing new to refuse, and sail-team's queries keep working.
- **What stays in the database, for everyone:** a frozen plan never changes, and the plan in force can't be archived. The archive rule is today's "an active plan can't be archived" ([cyc-seattle/sail-team#82](https://github.com/cyc-seattle/sail-team/issues/82)) restated for dates: one check against today's date, so it's kept rather than new machinery.
- The program director is paid staff, so they're on the Staff role, which gives nothing in Planning; the group gives the rest, as decision 19 of [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) has it.

**Warnings instead of field rules.** Three things in a Program Plan move money between areas or off programs. Anyone can set them, and the engine warns about each line that does, naming it, so the committee sees them before it makes a plan active:

1. `excluded_from_mtdc` on a line, which shrinks the area's MTDC so the pools land on other areas.
2. A line charged to a pool or to the organization.
3. A line booked to an asset account, which the engine already moves to capital, with a warning.

Today the only Program Plan lines that do any of this are each area's storage rent ("Storage (dinghy float and dry storage, by area)": excluded from MTDC, charged to the area). That rent moves to the Operations Plan (below), so the warnings fire only when a director really moves a cost, and they stay ordinary warnings, with no kind of their own. Lines in the Operations Plan never get them: it's the committee's.

**Alternative considered:** per-area write rules from `program_area_role_assignments`, and field locks on `plan_programs` and on the three line fields. Rejected by the maintainer: more rules to keep, and the warnings show the same things.

### b. Screens

**Everyone lands on the same Planning list. The difference is what's editable.**

```
Planning                                     [Year 2027 ▾] [Status ▾]
┌─────────────────────────────────────────────────────────────────────┐
│ Name                    Status            Revenue   Expenses   Net   │
│ 2027 re-plan for fall   Active since Aug 1  $412k    $399k   $13k [⋯]│
│ 2027 budget             Frozen, Mar 1–Jul 31 $405k   $390k   $15k [⋯]│
│ Fall pricing try-out    Draft                $420k   $404k   $16k [⋯]│
└─────────────────────────────────────────────────────────────────────┘
```

- The list shows operating revenue, expenses and net only. Fundraising and capital stay on the plan's own reports.
- A plan's menu shows Freeze, Make active and Archive only to the committee, and Duplicate to everyone who can start a draft (sail-team already decides from `/permissions/me`).

**A plan's reports show the plan itself**, as they do today. Its warnings include the lines that move costs, for the committee to review before making it active:

```
2027 re-plan for fall · Overview
  Warnings (5) ▸  includes 3 lines that move costs (review before making active)
  Area           Revenue    Expenses   Net
  Summer         …
  Doublehanded   …
  Operating net  …
```

**A program area's report adds a season filter.** It's where a director spends their time:

```
Doublehanded · 2027 re-plan for fall                  [Season: Fall ▾]
  Assumptions ▸   J-Pod: Level 2 coach, 8 sailors per coach ✎   Rules ✎
  Shared rates and costs: set by the finance committee (read-only) ▸
  Money
  Revenue      $51,200
  Direct       $31,000
  Gross        $20,200
  Indirect     $12,300   ← share of the pools, split by MTDC
  Net          $ 7,900
  Offerings (Fall)
  #  Offering     Season  Dates          Max  Expected  Fee      Fee/day
  1  J-Pod fall   Fall    Sep 8–Nov 20   16   14 ✎      $1,450 ✎  $48
```

- Season filters offerings (winter, spring, summer, fall, or All). Programs with no season, such as Adult Learn to Sail, show under All.
- The Operations Plan's Assumptions show read-only for a director, saying who sets them.
- Indirect costs say they're a share of the pools, because a director's net moves when another area changes.

**A Storage tab, right after Assumptions.** It shows the Operations Plan's storage costs: what each area pays, and what's left in the shared costs, with the total. It's the committee's; directors see it read-only.

```
2027 re-plan for fall · Storage
  Area / who pays                                  Account            Amount
  Summer             Storage (float and dry)       7350 Occupancy     $9,824
  Doublehanded       Storage (float and dry)       7350 Occupancy     $6,995
  …
  Shared (G&A)       Dry storage (paid to the Port) 7350 Occupancy    $5,100
  Shared (G&A)       Self storage facility          7350 Occupancy    $1,728
  No program pays    Storage not allocated to programs                $13,070
  Total                                                               $…
```

- **Which lines are storage.** In the 2026 plans, storage shares account 7350 Occupancy/Rent with the clubhouse fee, so the account alone can't pick them out. Recommended: a Storage sub-account under 7350 in the catalog (`accounts.parent_id`), which the tab reads, with no schema change. Alternative: the tab shows every Operations Plan line on 7350 and calls itself Occupancy and storage, which needs no new account but isn't only storage.
- **[cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126)'s parked storage items** (racks, deck space by boat class, charging each program for the floor space its boats use, storage sold to sailors) land on this tab when they're built: worked-out amounts then replace the typed ones, and storage leases, already Operations Plan offerings, join it. Nothing of that is needed now.
- The Non-program report keeps showing shared costs and how they're split, storage among them; the Storage tab is the one place to see all of storage.

**Alternative considered:** a director landing on their own area. Dropped: there are no per-area permissions to say which area is theirs, and one list is simpler.

### c. Factoring: the fiscal year and the seasons

**One Financial Plan per year, with a Program Plan per area inside it. A plan is in force from its effective date; the board freezes a plan when it approves it.**

How a year runs:

1. The committee and directors build the year's draft. The board approves it; the committee freezes it and makes it active from a date, such as the start of the fiscal year.
2. When a director needs to re-plan a season, they (or the committee) start a draft from the plan in force and change their area. Directors can try ideas in their own drafts the same way.
3. When the committee wants a draft in force, it makes it active from a date. **An active plan can be a draft**: directors keep changing it while it's in force, and its results keep updating.
4. When the board approves it, the committee freezes it. It stays in force; freezing only stops it changing.

**Effective dates replace the single active flag.** Making a plan active gives it an effective-from date. The plan in force on a day is the one with the latest effective date on or before that day, for that organization and year, and it's in force until the next one's date. This gives:

- **History:** which plan was in force on any day, without Directus revisions.
- **Scheduled hand-offs:** a plan can be made active from a future date.
- **Tracking by date:** real activities come from the plan in force. Which plan a month is reported against is a question for budget-against-actuals tracking ([cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)), not this work.

The committee can change any effective date, past or future, to fix a mistake.

**What frozen protects:** every plan the board approved never changes. A draft in force is live, and changes while it's in force until the board approves and the committee freezes it.

**Seasons are a filter, not a structure.** Season becomes a fixed list on offerings: winter, spring, summer, fall, or none, matching [cyc-seattle/platform#232](https://github.com/cyc-seattle/platform/pull/232). The engine splits the pools across every area by MTDC, so the year's areas have to be in one Financial Plan for anyone's indirect costs to be right. A season that runs into the next fiscal year books to the year it starts in, as today.

**Alternatives considered:**

- **Separate Program Plans inside a fiscal-year envelope,** each with its own lifecycle, assembled by the committee. Needs per-copy saving, a submit step and assembly, and shared costs are wrong until assembled.
- **Per-season Program Plans.** Plans gain a season, and areas with no seasons need a placeholder. Shared costs still need the whole year together.
- **A separate forecast mark beside the active plan.** Replaced by drafts that can be active, which needs no second flag.

### What changes in platform

- `version_sets`: an effective-from date, set and changed by Plan Approver at any time. Status keeps `draft` and `saved`; "active" is derived from the date, not a status. The rules that refuse marking a draft active, and the partial unique index on active, go. In their place: one effective date per organization, year and date, and the plan in force can't be archived.
- Policies: Plan Writer narrowed to Program Plans and drafts; Plan Approver added.
- `plan_bonus_owners` and `plan_bonus_owner_products` leave Program Plans: only the Operations Plan holds bonuses.
- `plan_offerings.season_term` becomes a choice of winter, spring, summer, fall or none.
- Storage rent moves from each Program Plan to the Operations Plan, as a line charged to the area, as before. The engine already allows it: a line's cost center decides where it's charged, not which plan holds it, so an Operations Plan line charged to a program area is split among that area's offerings by MTDC, and its results belong to the area's Program Plan, as today. No engine change. Only drafts can be changed: in each draft, the line moves to the Operations Plan copy. Frozen plans keep theirs, and their results never change, so they don't gain the new warnings either.
- Engine warnings for Program Plan lines excluded from MTDC, charged to a pool or the organization, or booked to an asset account.
- Boat and coach-boat counts come from the `boats` list ([cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126), being built separately).

### Changes to earlier decisions

- [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149): Planning has no agent of its own. A planner's agent is their own Claude, with exactly the access they have, so it needs no design of its own. The premise that "the agent writes a new draft Financial Plan, and keeping it accepts it" no longer shapes the model: drafts work the same for a person and their agent.
- [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30): "the active plan" becomes the plan in force on a date. It gains an open question: which plan a month is reported against when a hand-off falls mid-month.
- [cyc-seattle/sail-team#82](https://github.com/cyc-seattle/sail-team/issues/82): "an active plan can't be archived" becomes "the plan in force can't be archived".

### Overlap with open work

- [cyc-seattle/platform#230](https://github.com/cyc-seattle/platform/pull/230) (coaches): the coach list sits under the CRM policies. If directors keep it, they'd need CRM Writer, which gives far more; a narrower coach-list policy for directors may be wanted there. Its `plan_salaried_positions.person_id` is on the Operations Plan, so it's the committee's.
- [cyc-seattle/platform#231](https://github.com/cyc-seattle/platform/pull/231) (calendar): its Calendar Writer policy, for program staff's groups, fits the directors' group.
- [cyc-seattle/platform#232](https://github.com/cyc-seattle/platform/pull/232) (coaching): the season list offerings now share.
- [cyc-seattle/platform#126](https://github.com/cyc-seattle/platform/issues/126) (boats): boat counts leave the Operations Plan, as above.
- The maintainer's separate issue for safety rules ("policy" feature, with its own permissions): coaches per boat and similar rules move there.

## Decisions (maintainer, 2026-11-13)

1. No forecast mark. An active plan can be a draft. The board freezes a plan when it approves it; to change one, someone starts a draft from it, and that draft becomes active. Reports show the plan itself, with no comparison.
2. Plans get an effective-from date when made active, replacing the single active flag. The plan in force on a day is the one with the latest effective date on or before it. The committee can change any effective date, past or future.
3. Directors read and write every program area. No per-area permissions.
4. Directors can change any draft, and can start their own. Freezing and making active stay with the finance committee.
5. Directors see salaries.
6. Staff level and sailors per coach are the director's: the program's quality. Safety rules, such as coaches per boat, are the committee's, in a separate issue.
7. Bonuses live only in the Operations Plan.
8. Anyone can set `excluded_from_mtdc` or charge a line to a pool, the organization or an asset account; the engine warns about each such line. The only structural limits: directors can't change the Operations Plan, and can't freeze or make active.
9. Season on offerings is a fixed list: winter, spring, summer, fall, or none.
10. Everyone lands on the same Planning list.
11. Planning has no agent of its own; a person's agent does what they can do.
12. Boat and coach-boat counts leave the Operations Plan, for the `boats` list.
13. The plan list shows operating revenue, expenses and net only.
14. Storage rent moves from Program Plans to the Operations Plan, still charged to each area, with its own Storage tab. Cost-shift warnings stay ordinary warnings.
15. Storage lines book to a new Storage sub-account under 7350 Occupancy/Rent, which the Storage tab reads.

## Later

- **Which plan a month is reported against**, when a hand-off falls mid-month: a question for budget-against-actuals tracking ([cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)), not this work.

## Steps

1. **platform PR (features):** `features/planning.feature` for effective dates, the plan in force, Plan Writer and Plan Approver, and the new warnings, `@pending`.
2. **platform PR:** effective dates (schema, the saved-versions hook and triggers, a migration that gives the active plan, if any, an effective date), the two policies, bonuses out of Program Plans, the season list, and the warnings. A one-off script, run by hand like `delete-plans`, moves each draft's storage rent into its Operations Plan copy before the warnings ship. `docs/access.md` and `docs/planning-schema.md` updated.
3. **[maintainer]:** the finance committee's group gets Plan Writer and Plan Approver; a Program Directors group gets Plan Writer.
4. **sail-team PR:** the Planning list's in-force dates, Make active with a date, the Storage tab, the season filter, and menus that follow the new policies; screenshots in the PR per AGENTS.md.
