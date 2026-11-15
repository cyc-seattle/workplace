---
tags: [research, planning, directus]
---

# Planning schema cleanup

Research for [cyc-seattle/platform#276](https://github.com/cyc-seattle/platform/issues/276): a reversible saved
status, short notes, and no leftovers from earlier iterations. Read from `schemas/planning.yaml` and sail-team's
`main` on 2026-11-14, and from prod's database with read-only queries.

## Who reads the schema

- **platform:** the engine (`src/planning/`), the `saved-versions` hook and its triggers
  (`stacks/backend/saved-versions.cjs`), the policies, the default views, the `allocate-plan` skill, the scripts
  `delete-plans` and `move-storage`, and the tests and features.
- **sail-team:** `src/directus/financial-plans.ts` and `src/directus/plan-inputs.ts` read every planning collection,
  and write only `version_sets`. Its mocks still list `plan_resources` and `plan_block_resources`, which platform
  dropped.
- No other app (isthmia, commodore, the website) reads a planning collection.
- Staff open the Data Studio only to break glass.

## The plan model today

Four collections hold what a Financial Plan is and which plans it has:

| Collection            | What it is                                            | Fields                                                                                                                                      |
| --------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `version_sets`        | A Financial Plan                                      | organization, year, name, `message` (its note), status, `effective_from`, parent, `saved_by`, `saved_at`, `platform_version`, `archived_at` |
| `version_set_members` | A junction: which plan copy a Financial Plan holds    | `version_set_id`, `plan_id` (filled in from the copy), `version_id` (unique)                                                                |
| `plans`               | A plan's identity across Financial Plans              | kind, program area, organization, year, name                                                                                                |
| `plan_versions`       | One plan as one Financial Plan holds it ("plan copy") | `plan_id`, `parent_version_id`, status, `message`, `saved_by`, `saved_at`, `platform_version`, `rules`                                      |

Every row collection (`plan_offerings`, `plan_activities`, and 19 more) belongs to a copy through `version_id`.
Results belong to a Financial Plan through `version_set_id`, and to a plan in it through `version_set_member_id`.

In the Data Studio this shows as a Financial Plan's "Plans" through "Financial plans plans", and a separate list of
"plan copies".

### What the data says

On prod:

- Every copy is in exactly one Financial Plan. None is in no Financial Plan, and no plan lacks a copy.
- Each organization, year, kind and program area has one `plans` row. So a plan's identity is its Financial Plan
  plus its kind and area: `plans` adds nothing a copy can't hold itself.
- A member's `plan_id` always matches its copy's.
- No copy has a `message`.
- A copy's status, `saved_by`, `saved_at` and `platform_version` are stamped from its Financial Plan's: never set on
  their own.
- A copy's `parent_version_id` is the copy of the same kind and area in the Financial Plan's parent, so it's derived.
- The trigger already refuses saving a copy on its own, and a member in two Financial Plans.

So the junction, the identity table and the copy's own status fields are leftovers of a design where a plan copy
was versioned on its own ("club plans", before Financial Plans).

## Leftovers

| Item                                                                                                | Evidence                                                                                                                                                                             | Proposal                                       |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| `version_set_members`                                                                               | One copy per member, one Financial Plan per copy                                                                                                                                     | Drop: a plan names its Financial Plan          |
| `plans` (identity)                                                                                  | One per Financial Plan, kind and area                                                                                                                                                | Drop: the copy holds its kind and area         |
| `plan_versions.parent_version_id`                                                                   | Derived from the Financial Plan's parent                                                                                                                                             | Drop                                           |
| `plan_versions.message`                                                                             | Empty on every row                                                                                                                                                                   | Drop                                           |
| `plan_versions.status`, `saved_by`, `saved_at`, `platform_version`                                  | Copies of the Financial Plan's                                                                                                                                                       | Drop                                           |
| `plans.organization_id`, `fiscal_year`, `name`                                                      | The Financial Plan's, and a name derived from kind and area                                                                                                                          | Drop                                           |
| `plan_offerings.fill_rate`                                                                          | Empty on every prod offering; each has `target_enrollment`                                                                                                                           | Drop                                           |
| `plan_salaried_bookings.kind`                                                                       | One choice, `management`                                                                                                                                                             | Drop; the engine's line key stays `management` |
| The hook's copy-time move of a Program Plan's bonuses                                               | No bonus rows on prod                                                                                                                                                                | Drop the code; the trigger still refuses one   |
| The hook's drop of `plans`' old unique indexes                                                      | Gone on every database                                                                                                                                                               | Drop the code                                  |
| `scripts/move-storage`, `scripts/delete-plans` and their tests                                      | One-off moves, done ([cyc-seattle/platform#149](https://github.com/cyc-seattle/platform/issues/149), [cyc-seattle/platform#251](https://github.com/cyc-seattle/platform/issues/251)) | Drop                                           |
| sail-team's `excluded_from_mtdc` fallback, and mocks of `plan_resources` and `plan_block_resources` | Platform renamed and dropped them                                                                                                                                                    | Drop                                           |

Prod's tables and columns match `schemas/planning.yaml`: no stray table or column is left from earlier migrations.

Empty on prod, but live features the engine and sail-team use: `plan_trips`, `plan_bonus_owners`,
`plan_bonus_owner_products`, `plan_closed_dates`, `plan_result_bonuses`, and `plan_capital_items.link`. These stay.

## Notes

Text fields a person writes, with prod's counts:

| Field                                            | Non-empty | Over 280 characters | Longest |
| ------------------------------------------------ | --------- | ------------------- | ------- |
| `version_sets.message` (a Financial Plan's note) | 5         | 3                   | 2,018   |
| `plan_versions.message`                          | 0         | 0                   |         |
| `plan_versions.rules`                            | 18        | 11                  | 1,252   |
| `plan_programs.rules`                            | 91        | 5                   | 451     |
| `plan_offerings.note`                            | 388       | 0                   | 91      |
| `plan_budget_lines.note`                         | 138       | 0                   | 144     |
| `plan_revenue_charges.note`                      | 20        | 0                   | 158     |
| `plan_labor_lines.note`                          | 19        | 0                   | 62      |
| `plan_capital_items.note`                        | 12        | 0                   | 95      |
| `assets.note` (core)                             | 61        | 0                   | 162     |

The engine writes `plan_result_lines.explanation` and `plan_result_warnings.message`; no person does.

Only the three long Financial Plan notes break the 280-character limit. Each is a write-up of how the plan was built
and where it differs from the workbook: a description, not a note. `rules` are the planner's instructions for their
AI, one rule a line, and are long by nature.

## Status

`draft` and `saved`. A Plan Admin saves a Financial Plan; nothing turns it back. sail-team calls saving "Freeze".
The issue makes it reversible, by a Plan Admin, and calls it saved everywhere.

## Decisions

The maintainer's answers on [cyc-seattle/platform#276](https://github.com/cyc-seattle/platform/issues/276), 2026-11-14:

- `version_sets` becomes `financial_plans`, and `plan_versions` becomes `plans`: one plan in one
  Financial Plan, with its own kind and program area. `version_set_members` and the old `plans` go.
  Rows name their plan by `plan_id`, and results their Financial Plan by `financial_plan_id`.
- Deleting a draft Financial Plan deletes its plans, their rows and its results. Copies in no
  Financial Plan (831 on dev, none on prod) are deleted with their rows.
- The status stays one way, and is called frozen everywhere: `draft` or `frozen`, `frozen_by`,
  `frozen_at`, and the hook is `frozen-plans`. "Save sounds like something you do many times."
- No description field. Every `note` holds at most 280 characters, with inline markdown. A long
  Financial Plan note keeps its first line if that fits, and the rest is dropped.
- A plan's and a program's `rules` become `notes`: a list of short notes, stored as a JSON array of
  strings, each one line of at most 280 characters, which the hook's triggers check.
- `plan_offerings.fill_rate`, `plan_salaried_bookings.kind`, and the scripts `move-storage` and
  `delete-plans` go. The engine counts an offering with no target enrollment as none.
- The planning API's types follow the names, so the release is a major one. sail-team moves to it in
  a PR merged right after platform's prod apply, with a few minutes of a broken Planning page between.
