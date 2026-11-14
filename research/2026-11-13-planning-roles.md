# Planning for two kinds of planners: the finance committee and program directors

Research for the maintainer's review with the volunteer building SailOps (2026-11-13). It proposes how Planning in sail-team, and the planning model in platform, serve the finance committee, who set the rules, and program directors, who plan within them. It covers roles and permissions, the screens, and how a fiscal-year plan relates to the seasons directors plan. Nothing here is built.

## Context

### What the maintainer said

> There are 2 somewhat different users here. On one hand, members of the board - and specifically the finance committee - who are responsible for planning out the whole fiscal year and, importantly, balancing the allocation of resources across programs which may compete with them. On the other hand we have program directors who are responsible for planning programs - possibly one term or season at a time, and are not as concerned with the overall organization-level.

> The finance committee needs to be in charge of creating new plans, freezing them, and making them active. And - importantly - setting the rules that govern the allocation process. The directors then can update their program plans, and use the platform to calculate costs so that they can figure out how to best price and fill their programs - and decide what programs to run. However, they shouldn't be able to change hard and fast rules.

> One group sets the rules of the game. The other group plays within them.

> Up until now I've been building the planning feature in Sail Team as if it serves both users - because in previous years the finance committee has also been the ones planning programs. This has changed with us hiring a program director who is financially motivated to fill his own programs.

### Sources

- platform `origin/main`: `docs/planning-schema.md`, `docs/access.md`, `stacks/backend/policies.ts`, `schemas/planning.yaml`.
- sail-team `main` at fb4ff3a3: `src/directus/access.ts`, `src/routes/plans/`.
- [cyc-seattle/workplace#6](https://github.com/cyc-seattle/workplace/issues/6) (decisions 17–29), [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30), [#31](https://github.com/cyc-seattle/sail-team/issues/31), [#63](https://github.com/cyc-seattle/sail-team/issues/63), [#73](https://github.com/cyc-seattle/sail-team/issues/73), [#82](https://github.com/cyc-seattle/sail-team/issues/82), [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149), [#206](https://github.com/cyc-seattle/platform/issues/206), [#208](https://github.com/cyc-seattle/platform/issues/208), [#139](https://github.com/cyc-seattle/platform/issues/139), [#138](https://github.com/cyc-seattle/platform/issues/138).
- [2026-11-07-sailops-requirements.md](2026-11-07-sailops-requirements.md) and [2026-11-09-planning-rules-and-agent.md](2026-11-09-planning-rules-and-agent.md).
- Draft PRs [cyc-seattle/platform#230](https://github.com/cyc-seattle/platform/pull/230) (coaches), [#231](https://github.com/cyc-seattle/platform/pull/231) (calendar) and [#232](https://github.com/cyc-seattle/platform/pull/232) (coaching recommendations).

### What exists today

**Lifecycle.** A Financial Plan (`version_sets`) is CSC's plan for one fiscal year. It holds one Operations Plan copy and at most one Program Plan copy per program area (`version_set_members` → `plan_versions`). Its `status` is `draft`, `saved` (the app says "frozen") or `active`, with at most one active per organization and year. A new Financial Plan starts as a copy of a parent, so drafts branch like git. Freezing saves every copy at once and the results with them, and nothing changes afterwards, even for an admin (hook plus database triggers). Marking one active moves the old active one back to frozen. `archived_at` hides a plan from the list. A draft's results are worked out again about a second after any change, from any path.

**Program Plans are per area per year**, not per season. A season is only `plan_offerings.season_term`, a free-text field; an offering's money all falls in the plan year it starts in. [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) decided tracking isn't split by season, because Adult Learn to Sail has none.

**Program areas already have directors.** `program_area_role_assignments` (CRM) records who holds a role, such as Director, in an area, with dates. Nothing uses it for access today.

**Access.** Roles give base access; groups give extra policies (`group_policies`, kept by admins as data). For planning there are two policies:

| Policy      | Gives                                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------------ |
| Plan Reader | Reads every plan, wages and bonus rates included, the catalog, and users' names                                    |
| Plan Writer | Creates, changes and deletes every planning row in any draft, freezes a Financial Plan, marks one active, archives |

Both are whole collections, with no row filters and no hidden fields. sail-team decides what to show from `/permissions/me`: Planning appears with `canRead("plans")`, and the plan actions with `canWrite("version_sets", …)`. So today anyone who can edit a program can also change payroll tax, the G&A pool, their own bonus rate, and freeze or activate the year's plan.

**Which inputs are rules, and which are choices.** Sorted by who should own them:

| Input                                                                            | Where it lives                                     | Kind                                            |
| -------------------------------------------------------------------------------- | -------------------------------------------------- | ----------------------------------------------- |
| Rates: payroll tax, lodging, mileage, coach-boat kind (`plan_rates`)             | Operations Plan                                    | Rule                                            |
| Staff levels and their hourly rates                                              | Operations Plan                                    | Rule                                            |
| Salaried positions, their salary, G&A share, bookings                            | Operations Plan                                    | Rule                                            |
| Resources and boat rates, and the inventory (`quantity`) every area draws on     | Operations Plan                                    | Rule                                            |
| Pools (G&A, program admin) and their lines                                       | Operations Plan                                    | Rule                                            |
| Charges set as a share of revenue: scholarships, program buffer, B&O, card fees  | Operations Plan                                    | Rule                                            |
| Bonus owners: rate and basis (before or after shared costs)                      | Operations Plan, **or an area's own Program Plan** | Rule                                            |
| Closed dates, ranked capital, non-program offerings                              | Operations Plan                                    | Rule                                            |
| How shared costs are split (MTDC)                                                | Engine code                                        | Rule                                            |
| Accounts, products, areas, boat classes and sailors per boat                     | Catalog (Catalog Writer)                           | Rule                                            |
| A program's staff level and sailors per coach (`plan_programs`)                  | Program Plan                                       | **Rule**, though it sits in the director's plan |
| `excluded_from_mtdc` on a line, and a line charged to a pool or the organization | Program Plan lines                                 | **Rule**, though it sits in the director's plan |
| Offerings: which run, dates, capacity, expected sailors, price, COGS             | Program Plan                                       | Choice                                          |
| Activities, blocks and what each block is given: staff, coach boats, boats       | Program Plan                                       | Choice                                          |
| Trips, and lines charged to the area's own offerings, products or area           | Program Plan                                       | Choice                                          |
| Free-text rules on programs and the Program Plan                                 | Program Plan                                       | Choice (the director's words for their agent)   |

Three things in a director's own plan move money the committee should control:

1. **Their own bonus.** A bonus on one area's products can live in that area's Program Plan (`plan_bonus_owners`), rate and basis included.
2. **Their share of shared costs.** Ticking `excluded_from_mtdc` on their own lines shrinks their area's MTDC, so the pools land on other areas.
3. **Moving costs off the area.** A line in their plan can be charged to a pool or the organization (`cost_center_type`), or to an asset account, which the engine moves to capital that fundraising pays for.

## Approach

### a. Roles and permissions

**Recommendation: a new Program Director policy, given by a group, that reads all of Planning and changes only the director's own area in drafts. The committee keeps Plan Writer.**

|                                                                                       | Finance committee      | Program director                   | Board (not on the committee) |
| ------------------------------------------------------------------------------------- | ---------------------- | ---------------------------------- | ---------------------------- |
| Group gives                                                                           | Plan Writer (as today) | **Program Director** (new)         | Plan Reader                  |
| Reads                                                                                 | Everything in Planning | Everything in Planning, every area | Everything in Planning       |
| Starts, freezes, activates, archives, deletes a Financial Plan                        | Yes                    | No                                 | No                           |
| Changes the Operations Plan (rates, pools, inventory, charges, bonuses, capital)      | Yes, in a draft        | No                                 | No                           |
| Changes a program's staff level and sailors per coach                                 | Yes, in a draft        | No: shown, locked                  | No                           |
| Changes offerings, prices, activities, blocks, trips, the area's lines and rules      | Yes, in a draft        | Their own area's, in a draft       | No                           |
| Sets `excluded_from_mtdc`, charges a line to a pool or the organization, adds a bonus | Yes                    | No                                 | No                           |

How it maps onto platform:

- **Who directs which area is data that already exists**: `program_area_role_assignments` with the Director role, current by its dates. The Program Director policy's write rules filter each planning row by that, through its copy's plan's `program_area_id`. Being in the group gives the policy; the assignment decides which area. Both are app data an admin changes in the Data Studio, so nothing depends on which screen is used. An interim director, or two co-directors, is one more assignment row.
- **Field rules do the locking.** The policy can update `plan_programs.rules` but not `staff_level_key` or `sailors_per_coach`; lines but not `excluded_from_mtdc`, with a validation that `cost_center_type` is offering, product or program area; `version_sets` not at all. Directus's field and validation rules on writes don't touch the query guard, which is about reads.
- **Reads stay whole.** A director reads every plan, so the policy has no read filter and the query guard has nothing to refuse. sail-team's queries, which filter results by `version_set_member_id`, keep working unchanged.
- **Freezing and activating stay with the committee.** The saved-versions hook already keeps a frozen plan from changing for everyone, director or not.
- **Risks to check in a spike:** whether Directus accepts the relational filter from a planning row up through `plan_versions → plans → program_areas` and across to the role assignments (it refuses `_none` in rules; `_some` and many-to-one paths should work). If it doesn't, the saved-versions hook, which already sees every planning write and knows the user, checks the area instead. A booking to an asset account can't be refused by a field rule, since the account's type is a join; the engine's existing warning, which moves it to capital, is the check.

The program director is paid staff, so they're on the Staff role; the role gives nothing in Planning, and the group gives the rest, as decision 19 has it.

**Alternatives:**

- **A director sees only their own area.** Read filters on about 30 planning and result collections. Every one becomes a collection they can't read whole, so the query guard refuses sail-team's filters on them, and the Overview, the Calendar and shared-cost lines need other areas' numbers anyway. Their share of G&A also depends on every other area's MTDC, so hiding the others makes their own numbers unexplainable. It's much more work for privacy CSC mostly doesn't need. The one sensitive part is pay, which is its own decision below.
- **One policy per area** ("Summer Director", "Doublehanded Director"), each declared in code with its area's id. No relational filter, but a new area needs a platform PR, and who directs what lives in two places.
- **Only the finance committee writes; directors read, and send changes by message.** No new policy, but directors can't use the engine to try prices, which is the point.

### b. Screens

**Recommendation: the same reports, opened in two places. The committee lands on the year; a director lands on their area's live plan, with a season filter, and the rules shown locked.**

**Finance committee: sees the year first, and does lifecycle and rules most.**

```
Planning                                         [Year 2027 ▾] [Status ▾]
┌──────────────────────────────────────────────────────────────────────┐
│ Name                        Status      Net        Saved             │
│ 2027 budget                 Active      $12,400    Mar 2 by …   [⋯]  │
│ 2027 forecast               Live draft  $9,100     updated today [⋯] │
│ 2027 option: no Opti RT     Draft       $14,000                 [⋯]  │
└──────────────────────────────────────────────────────────────────────┘

2027 forecast · Overview                    [Freeze] [Mark active] [⋯]
  Warnings (4) ▸   2 of them involve more than one program area
  Area           Budget net   Forecast net   Change
  Summer          $41,000       $38,200     −$2,800  ▸ why
  Doublehanded    $ 6,500       $ 7,900     +$1,400
  Singlehanded    …
  Non-program     …
  Operating net   $12,400       $ 9,100     −$3,300
```

- The Overview compares the forecast with the budget, area by area, because that's the committee's balancing question: which areas moved, and does the year still close.
- Assumptions (rates, staff levels, inventory, pools, charges, bonuses, capital) is where the committee edits the rules ([cyc-seattle/sail-team#31](https://github.com/cyc-seattle/sail-team/issues/31)).
- Warnings that cross areas, such as two areas' blocks taking more FJs than CSC owns on a date, are the committee's to settle, so they're flagged here.

**Program director: sees their own area first, and does offerings, prices and fill most.**

```
Doublehanded · 2027 forecast                      [Season: Fall ▾]
  Assumptions ▸  (set by the finance committee 🔒)
     J-Pod: Level 2 coach, 8 sailors per coach 🔒   Rules: "…" ✎
  Warnings (1)  Sep 16: Summer and Doublehanded take 12 FJs; CSC owns 10.
                Ask the finance committee.
  Money       Budget     Forecast
  Revenue     $48,000    $51,200
  Direct      $30,100    $31,000
  Gross       $17,900    $20,200
  Indirect    $11,400    $12,300   ← shared costs, split by MTDC
  Net         $ 6,500    $ 7,900
  Offerings (Fall)
  #  Offering        Dates          Max  Expected  Fee     Fee/day  Net
  1  J-Pod fall      Sep 8–Nov 20   16   14 ✎      $1,450✎  $48     $2,100
  2  K-Pod fall      …
  [+ Add an offering]
```

- Season is a filter on offerings, not a separate plan: Fall shows the fall offerings and their totals; All shows the year.
- Locked rules show with a lock and "set by the finance committee", so a director sees why a number is what it is without being able to change it. The Operations Plan's Assumptions page is the same page, read-only for them.
- Indirect costs say they're a share of the pools, because the director's net moves when another area changes.
- Breakeven sailors per offering is the obvious next figure to add for pricing, but it should come from the engine, since the app never calculates results.

**Alternatives:**

- **One set of screens for everyone**, with edit controls hidden where the policy refuses them. Least to build, and it's where sail-team is today, but the director has to dig through the year to find their programs, and the committee never sees budget against forecast.
- **A separate director app** (SailOps-style "Programs" section). Clean split, but a second front end over the same data, which is what decision 3's "agents build UIs" and sail-team's single app avoid.

### c. Factoring: the fiscal year and the seasons

**Recommendation: keep one Financial Plan per year with an area-owned Program Plan inside it. Add a budget and a forecast: the active Financial Plan is the budget, frozen; one draft is the year's forecast, which directors keep up to date all year.**

How it works:

1. The committee builds the year's draft, sets the rules, freezes it, and marks it active. That's the **budget** the board approved.
2. The committee starts the **forecast** as a copy of the budget, and marks it the year's forecast (one per organization and year, as with active).
3. Directors change their own area in the forecast whenever they re-plan a season: add a fall clinic, raise a price, drop an offering that won't fill. Its results update in about a second, so they see the effect on their area and on the year.
4. The committee's reports compare forecast with budget. When the committee wants a new approved number, such as a mid-year re-forecast for the board, it freezes the forecast and keeps it as a dated snapshot, and only marks it active if the board re-approves the budget. Then it starts a new forecast from it.

What "frozen" protects: the budget the board approved, and every snapshot, never change. Directors never touch a frozen plan; they edit only the live forecast. That's already true of every frozen Financial Plan today.

Why this fits:

- **No new plan structure.** The forecast is an ordinary draft, its areas are ordinary Program Plan copies, and freezing and activating work as they do. The one new piece is marking which draft is the forecast.
- **Shared costs stay right.** The engine splits the pools across every area by MTDC, so it needs every area in one Financial Plan. A per-season or per-director plan would leave each one with a wrong share.
- **Seasons don't need a structure.** A season is a filter on offerings, as [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) decided for tracking. A season that runs into the next fiscal year books to the year it starts in, as today. Planning spring 2028 in the fall of 2027 happens in the 2028 forecast.
- **It's the comparison SailOps makes** per season, planned against forecast, kept at the year the committee reports in.

What it changes elsewhere:

- [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) says real activities are published from the active plan. With directors re-planning, the forecast holds the newest schedule, so real activities, and coach schedules, should come from the forecast. Money tracking still compares with the budget.
- [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149) has the planning agent write a new draft Financial Plan. For a director, it should write their area in the forecast instead, since a director's private copy of the whole year has no way back into the forecast.

**Alternatives:**

- **Separate Program Plans inside a fiscal-year envelope.** Each director keeps their own versioned area plan with its own lifecycle, submits a version, and the committee assembles the year from chosen versions. It matches "each director plays separately", but needs per-copy saving (today a copy is only ever saved with its Financial Plan), a submit and approve step, and a way to pin a version into the year. The year's shared-cost split is wrong until it's assembled. That's machinery the maintainer's description doesn't ask for.
- **Per-season Program Plans** (an area's plan for Doublehanded Fall 2027). Directors get a plan the size of their re-planning, but plans gain a season, the one-area-one-copy rule becomes one-per-area-per-season, and areas with no seasons, such as Adult Learn to Sail, need a placeholder. Shared costs still need the whole year together, so it only moves the season filter into the schema.
- **No forecast: directors edit drafts, the committee re-freezes and re-activates.** Nothing new at all, but the approved budget gets replaced each time a director changes a price, so there's nothing stable to compare with.

### Overlap with open work

- [cyc-seattle/platform#230](https://github.com/cyc-seattle/platform/pull/230) (coaches): the coach list is kept under the CRM policies, and adds `plan_salaried_positions.person_id`. If directors keep their own coach list, they'd need CRM Writer, which gives far more. A narrower coach-list policy for the director's group may be wanted there. Its new `plan_salaried_positions` field sits in the Operations Plan, so it's committee-owned under this proposal.
- [cyc-seattle/platform#231](https://github.com/cyc-seattle/platform/pull/231) (calendar): its Calendar Writer policy is for "race and program staff's groups", which fits the same Program Directors group.
- [cyc-seattle/platform#232](https://github.com/cyc-seattle/platform/pull/232) (coaching): its `recommendations` use a fixed season list (winter, spring, summer, fall). `plan_offerings.season_term` is free text; using the same list there makes the director's season filter reliable.
- [cyc-seattle/platform#206](https://github.com/cyc-seattle/platform/issues/206) (coach boats) and [#208](https://github.com/cyc-seattle/platform/issues/208) (staff level) don't change this proposal: inventory and staff levels are committee rules either way.

## Machinery this proposal flags as not needed now

- Per-area targets or envelopes set by the committee (a net each area must reach). The budget's per-area net already is the target, and the forecast shows the gap.
- Allocating boats or coach boats to areas ahead of time. The engine's inventory warnings across the year catch the conflicts; the committee settles them.
- Locking a season once it's run. Actuals ([cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)) are where a past season's real numbers come from.
- A submit-and-approve workflow for directors' changes. The forecast is visible to the committee as it changes, and Directus's revisions record who changed what.
- Hiding other areas from directors.

## Decisions for the maintainer

1. **What a director can change.** Recommended: their own area's offerings, prices, activities, blocks, trips, rules, and lines charged inside their area, in drafts only. Alternatives: also their programs' staff level and sailors per coach; or nothing, with directors reading only.
2. **Whether a program's staff level and sailors per coach are the committee's.** Recommended: yes, locked for directors, since the ratio is a safety rule ([cyc-seattle/sail-team#82](https://github.com/cyc-seattle/sail-team/issues/82): "the ratio of kids to coach is required"). Alternative: the director's, with the committee reviewing.
3. **Bonuses only in the Operations Plan.** Recommended: yes; drop an area plan's own `plan_bonus_owners`, so a director's bonus is never in their own plan. Alternative: keep it there and lock the collection for directors.
4. **How a director's area is known.** Recommended: from `program_area_role_assignments` (Director, current by date), with one Program Directors group giving the policy. Alternatives: one policy per area; or a new field on the group naming its area.
5. **Whether directors see every area.** Recommended: yes, all of Planning, read-only outside their own. Alternative: only their own area, at the cost of row filters on every planning collection and the query guard refusing sail-team's queries.
6. **Whether directors see salaries.** Recommended: yes, as Plan Readers do today; their indirect costs include salary shares, and hiding fields brings back the query guard problem. Alternative: hide `annual_salary_cents` and position pay from the Program Director policy, and accept that salary shares in the result lines still show what's being split.
7. **Budget and forecast.** Recommended: the active plan is the board's budget; one draft per year is marked the forecast, and directors edit it all year. Alternatives: separate Program Plans assembled by the committee; or no forecast, with re-freezing.
8. **Which drafts directors can edit.** Recommended: only the forecast, so the committee's what-if drafts stay the committee's. Alternative: any draft that holds their area.
9. **Whether directors can start their own drafts.** Recommended: no; creating plans stays with the committee, as the maintainer said. Alternative: yes, as sandboxes the committee can adopt whole, knowing there's no way to merge one back into the forecast.
10. **Where the planning agent writes for a director.** Recommended: their area of the forecast, replacing [cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149)'s new draft Financial Plan for directors; the committee's agent can still write a new draft. Alternative: always a new draft, which needs the sandboxes in decision 9.
11. **Where real activities come from.** Recommended: the forecast, since it has the director's latest schedule; money tracking still compares with the budget. Alternative: the active plan, as [cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30) decided, which means re-activating to publish a schedule change.
12. **Seasons as a fixed list.** Recommended: make `plan_offerings.season_term` one of winter, spring, summer or fall, matching [cyc-seattle/platform#232](https://github.com/cyc-seattle/platform/pull/232), with none for programs that don't run by season. Alternative: keep free text and filter by dates.
13. **What each lands on.** Recommended: Planning opens a director on their area of the forecast, and the committee on the year's list. Alternative: the same Planning list for both, as today.

## Steps, if approved

1. **platform PR (features):** the Program Director policy's rules in `features/planning.feature` (what a director changes and can't), and the forecast mark, `@pending`.
2. **platform PR:** a spike on the relational permission filter, then the Program Director policy, the forecast mark (one per organization and year), the field locks, and moving bonuses out of Program Plans if decision 3 holds. `docs/access.md` and `docs/planning-schema.md` updated.
3. **[maintainer]:** a Program Directors group with the director in it, their Director assignment on the area, and the finance committee's group on Plan Writer.
4. **sail-team PR:** Overview's budget-against-forecast columns, and the director's landing page with the season filter and locked rules, before editing screens; screenshots in the PR per AGENTS.md.
5. **sail-team PRs:** editing screens for offerings ([cyc-seattle/sail-team#30](https://github.com/cyc-seattle/sail-team/issues/30)) and for rules ([cyc-seattle/sail-team#31](https://github.com/cyc-seattle/sail-team/issues/31)), each showing only what the person's policy lets them change.
