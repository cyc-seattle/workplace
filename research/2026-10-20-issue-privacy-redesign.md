Part of #213. Today's Community rules tie visibility to "teammates in the running camp" (`packages/infrastructure/src/crm/community-rules.ts:16-96`). This issue ties privacy only to whether an adult opted in to share their contact information. Reads go through a backend endpoint, not Directus's item API. It also fixes the domain terms, because the rules and docs use Clubspot's model as ours.

## Context

Line numbers refer to isthmia `main` at ab05b53f, which includes #235.

**The rules today.**

- **Opt-in.** Opt-in is `registrations.share_contact`, answered on each Clubspot registration (`community-rules.ts:86-91`, `docs/crm-schema.md:232`). `people.share_contact` still exists, but nothing writes it.
- **Teammates.** A teammate is someone with a confirmed entry in an active camp's class that maps to one of the viewer's programs (`:56-84`).
- **Parent Coordinators** see every guardian's contact information in their programs (`:107-138`).
- **Coaches** have an unfiltered read on `people`, but no login yet (`src/crm/index.ts:189-195`).

**The leak.** In Directus 12, filters, sorts, and relational joins ignore field permissions. #235 added a query-guard hook that refuses risky query shapes (`src/crm/community-query-guard.js`, `queryGuardConfig` at `community-rules.ts:346`). The guard only runs where Directus is on the cluster. The deepest rule nests 14 relations, and `ME` matches only `people.email`. Matching every email took 7–12 s per request (#182).

**Terms.** The docs flip team and program. #166, the portal, and `docs/crm-schema.md:18-21` call Double-handed Race Team a program and J-Pod a class or "team". In the portal, "team" means class (`packages/portal/src/roster/model.ts:74`). In the rules, it means program.

## 1. Terms

Clubspot is a system we sync from and to. Its model isn't ours. Clubspot's terms appear only at the sync boundary, and in the collections that mirror it.

### Glossary

| Term              | Definition                                                                                                     | CYC example                                                            | Clubspot maps onto it as                                                                                                                                                                    |
| ----------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Program**       | A lasting thing CYC runs for sailors, at one level or for one group. A program is a product of kind `program`. | Guppies, Youth Beginner, Teen Sailing, J-Pod, K-Pod, L-Pod, Opti Green | A **class**, linked by hand through `classes.program_id`. A class is copied with each camp clone, so it's linked again each time.                                                           |
| **Product**       | Anything CYC sells.                                                                                            | Programs, boat charters, storage leases                                | No Clubspot concept                                                                                                                                                                         |
| **Offering**      | A program sold for one dated period. People register for offerings.                                            | Guppies, summer week 3; J-Pod, fall 2026                               | A **class × session**, or a class on its own when its cap is class-wide (`entry_caps` with no session)                                                                                      |
| **Registration**  | One person registered in one offering, with a status (confirmed, waitlisted, cancelled).                       | A child in Guppies week 3                                              | A Clubspot **registration entry** (`registration_entries`). A Clubspot **Registration** is one signup for a whole camp. It is a boundary record that can hold several of our registrations. |
| **Person**        | Anyone CYC knows: a sailor, a guardian, a coach. One row per human.                                            |                                                                        | A Clubspot **participant** resolves to a person. So do its guardians and emergency contacts.                                                                                                |
| **Contact**       | A link from one person to another, with a relationship.                                                        | A guardian, an emergency contact                                       | The guardian and emergency fields on a **participant**                                                                                                                                      |
| **Contact point** | One email address or phone number belonging to a person.                                                       |                                                                        | The email and phone fields on a participant                                                                                                                                                 |
| **Program role**  | A dated assignment of a person to a program in a role.                                                         | Coach of J-Pod; Parent Coordinator of Guppies                          | A Clubspot **event staff** row (a coach on a session) can feed a Coach assignment.                                                                                                          |
| **Cost center**   | What a money line belongs to: an offering, a product, a pool, or the org.                                      | "Summer Camp" is a **pool**                                            | A **camp's** sales account (`clubspot_sales_account`) maps to an account. It is not a cost center.                                                                                          |
| **Pool**          | A cost center that groups products for accounting and spreads shared costs over them.                          | Summer Camp; G&A                                                       | No Clubspot concept                                                                                                                                                                         |

**Boundary-only terms.** These stay in the Clubspot-domain collections and the sync code:

- **Camp.** A registration container in Clubspot, copied each season. "Summer Camp" is a camp that sells many programs' weekly offerings. It decides how people sign up, not what CYC runs.
- **Session.** A dated slot within a camp, such as Week 3. Together with a class, it makes an offering.
- **Class.** A track within a camp. It maps to a program.
- **Registration (Clubspot).** One signup to a camp.
- **Participant.** The form's record of a sailor, with their guardians, emergency contacts, and medical answers.

**Terms we don't define for now:**

- **Team.** Punted. Nothing in the schema or the rules uses it. The `doublehanded@` parent Google Group stays a Workspace structure.
- **Season.** No concept. Offerings have dates.
- **Enrollment.** Not used. Our word is registration.

### Schema changes

The prefix, `offerings`, and `registrations` ship in #213's Phase 1 (step 6). This issue ships the opt-in and the Coach role.

- **Prefix the Clubspot mirrors.** Directus has one namespace: every collection is a table in one Postgres schema, and folders only group them in the Data Studio. So the Clubspot-domain collections become `clubspot_camps`, `clubspot_sessions`, `clubspot_classes`, `clubspot_session_classes`, `clubspot_entry_caps`, `clubspot_registrations`, `clubspot_registration_entries`, `clubspot_registration_billing`, `clubspot_participants`, `clubspot_custom_field_definitions`, `clubspot_custom_field_responses`, `clubspot_event_staff` and `clubspot_promoted_fields`.
  - Directus can't rename a collection, so this is create, re-sync, and drop. clubspot-sync rebuilds the new collections from the API.
  - Only two fields are set by hand, and they're copied across by Clubspot id: `classes.program_id` and `participants.person_id`.
  - Relations from `people` and `contact_points` move to the new collections. Then the old collections go.
- **New `offerings`** (canonical). Fields: `program_id`, `starts_on`, `ends_on`, `capacity`. clubspot-sync writes one for each mapped class × session. A class with no program makes no offering, and raises today's `class_without_program` finding.
  - This replaces the planning schema's `offering_external_refs`. A planned offering (`plan_offerings.key`) links to an actual offering, and an actual offering links to its Clubspot class and session.
- **New `registrations`** (canonical). Fields: `person_id`, `offering_id`, `status`. clubspot-sync writes these from Clubspot registration entries.
- **`people.share_contact` comes back** as the opt-in (§2). `clubspot_registrations.share_contact` stays as Clubspot's raw answer.
- **No `teams` or `seasons` collections.** `plan_offerings.season_term` is dropped; offerings have dates.
- **Coach becomes a program role.** It joins Parent Coordinator in `program_roles`, so coaches are assigned to programs. Clubspot event staff can propose the assignments.

### Docs and plans that need changes

| Where                                                                          | Change                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/crm-schema.md:14-23`                                                     | Drop "Terminology matches Clubspot". Use the glossary, and say Clubspot's terms are boundary terms. Fix the program example: Double-handed Race Team isn't a program. J-Pod is.                                                                                                                                                                                      |
| `docs/crm-schema.md:47-48, 240-243`                                            | Coaches are program roles, not session staff                                                                                                                                                                                                                                                                                                                         |
| `docs/crm-schema.md:52-53`                                                     | The revenue-account audit is about a camp's sales account against its programs' accounts, so call it a sync check, not a finance unit                                                                                                                                                                                                                                |
| `docs/crm-schema.md:216-243`                                                   | Rewrite the privacy section to §2                                                                                                                                                                                                                                                                                                                                    |
| `docs/planning-schema.md:9-23`                                                 | Fix the Program and Offering examples: J-Pod, not J-Pod Race Team; and "a program sold for one dated period", not a Clubspot unit. Add Summer Camp as a pool example. Remove "no single program hierarchy" phrasing about teams. Drop `season_term` (`:166`) and `offering_external_refs` (`:79-85`). Rename the activity kind `camp_week` to `week` (`:210, :240`). |
| `docs/architecture.md:25, 92, 197`                                             | "Event" becomes offering or activity. gsuite-sync syncs program groups only.                                                                                                                                                                                                                                                                                         |
| `docs/google-groups-nesting.md:7-15, 48-49`                                    | J-Pod is a program. Its group nests under a parent group (today `doublehanded@`), not a "program group" over "class groups".                                                                                                                                                                                                                                         |
| `packages/crm/schema.yaml:192` and `packages/clubspot/schema.yaml:20, 155-157` | Collection notes use the glossary. Classes map to programs, and camps are registration containers.                                                                                                                                                                                                                                                                   |
| `packages/infrastructure/src/crm/community-rules.ts`                           | Replaced by §2. `ACTIVE_CAMP`, `TEAM_ENTRY` and `TEAMMATE` go.                                                                                                                                                                                                                                                                                                       |
| `packages/portal/src/roster/*` and their tests                                 | "Team" means class today. The roster groups by program, and the class filter becomes a program filter. Fixtures stop calling camps sessions.                                                                                                                                                                                                                         |
| `features/community-rules.feature`                                             | Rewritten for the new model. Its first line already says the model is being redesigned.                                                                                                                                                                                                                                                                              |
| #166                                                                           | Comment on the inversion: J-Pod is a program. Note that the privacy decisions moved to the new issue.                                                                                                                                                                                                                                                                |
| #213                                                                           | Offerings, registrations, and the Clubspot prefix join Phase 1 and Phase 4. No season wording. Settle Decision 7's "what is a program".                                                                                                                                                                                                                              |
| `AGENTS.md:113`                                                                | Already right ("Parent Coordinator of J-Pod")                                                                                                                                                                                                                                                                                                                        |

## 2. Privacy

Privacy depends on one thing: whether an adult opted in to share their contact information. Programs and dates decide who counts as a current family, and whose names appear. Hiding ended programs, grouping rosters, and filtering are front-end features, not rules. Once contact information is shared, hiding it later protects nothing.

### The rules

**Current family.** A signed-in user's email matches a person who is current, or who is a guardian of a minor who is current. Current means having a registration whose offering hasn't ended, or ended less than 12 months ago. Anyone else who signs in sees nothing.

What a current family sees:

| What                    | Who it covers                                                                                                                                                                                             |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Names**               | People with a current registration in a program where the family also has one. A roster lists them all, opted in or not.                                                                                  |
| **Contact information** | Adults who opted in (`people.share_contact`), visible to every current family. That's their email and phone, plus which children they're a guardian of. A minor's own contact information is never shown. |
| **Their own family**    | Their own and their minors' registrations, and their own opt-in, which they can change                                                                                                                    |

Families never see medical information.

**Role rules.** These are separate from opt-in. They cover people with a current registration in a program the viewer is assigned to:

| Role                   | Sees                                                                      |
| ---------------------- | ------------------------------------------------------------------------- |
| **Parent Coordinator** | Names, all guardian and adult contact information, and emergency contacts |
| **Coach**              | The same, plus medical profiles                                           |
| **Staff**              | Everything                                                                |

**Opt-in.** Opt-in is per person, for adults only.

- `people.share_contact` takes the latest answer, whether it came from a Clubspot registration or a portal edit. This uses the existing "latest edit wins" rule for synced fields (`docs/crm-schema.md:95-109`).
- clubspot-sync writes it from the newest registration's answer, through the `promoted_fields` row that now targets `share_contact` on registrations.
- It replaces per-registration consent (`community-rules.ts:86-91`, `docs/crm-schema.md:232`). It also drops the rule that one registration's opt-in shares every guardian.

### Why the rules don't run as Directus permissions

In Directus 12, filters, sorts, and relational joins ignore field permissions (`docs/crm-schema.md`, #235). #235 closed the known probes with a query-guard hook, but the guard is a list of allowed query shapes. It has to keep up with every new readable relation.

The new model makes this worse if it runs as permissions. Names come from a program relation, and contact information from opt-in. That is two rules with different field sets on related collections, which is exactly the shape the leak exploits.

So Community users get no item permissions at all. Families, coaches, and Parent Coordinators read through a Directus **endpoint extension** in platform's backend:

- **Endpoints.** It exposes fixed endpoints, such as `/community/roster` and `/community/me`.
- **Auth.** It authenticates with the caller's Directus session.
- **Identity.** It resolves the caller to person ids once, matching every contact-point email. That settles #182 without a 14-level `ME` join.
- **Reads.** It runs fixed queries with its own access, applies the rules above in code, and returns only the fields each rule allows.
- **Writes.** The one write is the caller's own `share_contact`.
- **Guard.** No query is user-supplied, so there's nothing to filter, sort, or join on. The query guard and the deep Community rules can go.

This moves the decisions out of Directus rules, but they stay in the backend, not in the portal or the front end. #166's "the portal makes no data-access decisions" still holds. The endpoint's features replace `features/community-rules.feature`.

**#213's front end.** The redesign changes nothing for the staff screens. Staff read everything, so they keep calling Directus as themselves. Community-facing pages in the Next.js app call the endpoint as the user. A Next.js server with its own token wouldn't help: while the browser holds a Directus session that can read items, it can skip the Next.js server and query Directus directly. The fix has to be in the backend.

## Steps

Each step is one PR or one maintainer action. These steps run in isthmia. When #213 Phase 1 moves the backend, the endpoint, its features, and the schema move to platform with it.

- [ ] 1. **isthmia PR**: the glossary in `docs/crm-schema.md`, `docs/planning-schema.md`, `docs/architecture.md`, `docs/google-groups-nesting.md`, and the `schema.yaml` notes, per the table above. Docs only.
- [ ] 2. **[maintainer]** Comment on #166: J-Pod is a program, and its privacy decisions moved here.
- [ ] 3. **isthmia PR (features)**: the rules above as features against the endpoint, replacing `features/community-rules.feature`.
- [ ] 4. **isthmia PR**: per-person opt-in. clubspot-sync writes `people.share_contact` from the newest registration's answer, with latest edit winning. Coach joins `program_roles`.
- [ ] 5. **isthmia PR**: the community endpoint extension (roster and me), with its own reads, mounted like the query guard.
- [ ] 6. **isthmia PR**: the portal roster calls the endpoint. It groups and filters by program, and hides ended offerings itself.
- [ ] 7. **isthmia PR**: remove the Community item permissions, `community-rules.ts`, and the query guard. Close #175 and #182.
- [ ] 8. Update `AGENTS.md` and `docs/crm-schema.md` to match what shipped. Close this issue.

## Alternatives

- **Keep the rules as Directus permissions, and widen the guard.** Names and contact information would come from different rules on related collections, which is the shape the leak exploits. The guard would grow with every relation.
- **A Next.js server with a service token.** The browser still holds a Directus session that can read items, so it could skip the server.
- **A SQL view per audience.** It still exposes a filterable collection, and Directus can't write through a view.

## Decisions

The maintainer settled these on 2026-10-20:

1. **Clubspot's model isn't ours.** Its terms stay at the boundary.
2. **Programs** are what a Clubspot class maps to: Guppies, Youth Beginner, J-Pod. An **offering** is one program for one dated period, which is a class × session in Clubspot.
3. **"Summer Camp"** is a Clubspot camp, which shapes how people register. For accounting, it's a pool.
4. **Team is punted.** It isn't defined for now.
5. **No season concept.**
6. **Registration** is our word for a person in an offering. Clubspot's mirrors take a `clubspot_` prefix.
7. **Opt-in is per person**, for adults only, and the latest answer wins.
8. **Opted-in contact information** is visible to every current family.
9. **Names** are visible to current families in the same program, whether or not those people opted in.
10. **A current family** has a registration whose offering ended less than 12 months ago, or hasn't ended.
11. **A minor's own contact information** is never shown. Guardian links are shown.
12. **Parent Coordinators** also see emergency contacts. **Coaches** also see medical profiles. Both are role rules for their assigned programs.

**Still open:**

- whether Coach assignments come from Clubspot event staff automatically, or by hand
- whether a coach's medical access covers past registrations within the 12 months, or only offerings that are running
- whether names include guardians who didn't opt in, as "parent of" a sailor (today the answer is no)
