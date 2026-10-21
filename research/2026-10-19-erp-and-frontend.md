Follows #185, which ends when Phase 6 (#231) has isthmia's apps on the cluster. This plan starts from that state. It replaces the earlier plan to port project-two as it stood. The planning schema in `docs/planning-schema.md` gets built in Directus, and staff get a Next.js front end under the portal, so they stop working in the Data Studio. Before either lands, Directus and the whole schema move from isthmia to platform, and platform publishes an SDK that apps build on.

## Context

Line numbers refer to isthmia `phase-6-dev-stacks` at 7102e824 (#232) and platform `main` at d2745b7f. Lines marked `main` refer to isthmia `main` at f97c4679.

**The schema today.** Four packages declare 24 collections, plus 5 folders:

| Package                                            | Collections                                                                                                                 |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `crm` (`packages/crm/schema.yaml`)                 | `people`, `contacts`, `contact_points`, `medical_profiles`, `programs`, `program_roles`, `program_role_assignments`         |
| `clubspot` (`packages/clubspot/schema.yaml`)       | 13: camps, sessions, classes, entry caps, registrations, billing, custom fields, participants, event staff, promoted fields |
| `directus` (`packages/directus/schema.yaml`)       | `sync_tasks`, `sync_runs`, `audit_findings`                                                                                 |
| `gsuite-sync` (`packages/gsuite-sync/schema.yaml`) | `google_groups`                                                                                                             |

- **One apply.** The `crm` project finds every `schema.yaml` on disk and merges them (`packages/infrastructure/src/crm/index.ts:55`). `mergeSchemas` throws if two packages declare the same field. `applySchema` leaves undeclared collections alone, but drops a removed field and its data (`packages/directus/src/client.ts:539-547`).
- **Cross-package fields.** Some packages add fields to collections they don't own: gsuite-sync adds `programs.google_group_id`, and directus adds `people.directus_user_id`. That's why #185's "Schema ownership" says an app can't leave isthmia until the apply changes.

**Who writes what.**

- clubspot-sync writes the Clubspot collections and the people it matches (`src/crm/index.ts:235-311`).
- gsuite-sync writes only `google_groups`, its tasks, and its findings (`:360-368`).
- Staff edit `programs`, `program_roles`, `program_role_assignments`, `promoted_fields`, `classes.program_id`, and `participants.person_id` by hand in the Data Studio (`docs/crm-schema.md:45-53`).
- `programs.revenue_account` is a free-text string (`packages/crm/schema.yaml:2180`). gsuite-sync's `mismatched_revenue_account` audit reads it (`packages/gsuite-sync/src/audit.ts:254`).

**The planning schema.** `docs/planning-schema.md` designs 37 collections, and no `schema.yaml` declares them yet (`:7`):

| Group           | Collections                                                                                                                  |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Core catalog    | `products`, `accounts`, `qualifications`, `qualification_covers`, `boat_classes`, `resource_kinds`, `offering_external_refs` |
| Versioning      | `plans`, `plan_versions`, `version_sets`, `version_set_members`, `plan_activations`                                          |
| Product plan    | 9 `plan_*` collections, from offerings to budget lines                                                                       |
| Operations plan | 13 `plan_*` collections, from assumptions to bonus owners                                                                    |
| Results         | `plan_results`, `plan_metrics`, `actuals`                                                                                    |

The doc doesn't say:

- how `products` relates to `programs`
- who owns `core`
- how saved versions stay immutable
- where the engine runs
- how actuals arrive

Together with today's 24, that makes 61 collections.

**Roles.**

- Staff get full CRUD on everything outside Clubspot, with Data Studio access (`src/crm/index.ts:157-187`, `src/directus/roles.ts:39-44`). Every new collection would give Staff full CRUD automatically, including wages and saved versions.
- Coach, Guardian, and Community are API-only or read-only (`src/crm/index.ts:189-228`, `community-rules.ts`).
- The two syncs are machine users with static tokens (`roles.ts:131-174`).

**Data Studio use.** There are no Data Studio presets, flows, dashboards, or extensions in code. Staff resolve audit findings, link participants, and keep the program catalog by hand (`docs/crm-schema.md:118-140`). #170 and #123 ask for purpose-built screens instead.

**The portal.** `packages/portal` is a static link page for `cycsail.team`, rendered as a Caddy template.

- **Auth.** Caddy runs `forward_auth` to Authentik and copies three `X-Authentik-*` headers (`packages/portal/Caddyfile:36-38`). Staff sections gate on the Authentik `staff` group (`src/authentik/naming.ts:6`).
- **Roster.** The roster (#166) is the only dynamic part. It calls Directus from the browser with Directus's session cookie, as the signed-in user.
- **Directus settings.** Directus runs SSO in session mode. Its CORS and redirect allow-list name only the portal origin (`src/crm/workloads.ts:36-41`).
- **Architecture.** `docs/architecture.md:155-159` already names "thin clients calling Directus's API as the signed-in user" as the pattern for portals.

**Hosting.**

- **`WebService`.** It gives a Deployment, a Service, and a public `HTTPRoute` (`platform/src/web-service.ts`). It runs read-only, non-root, with requests equal to limits. It provides no auth, secrets, or DNS; apps bring their own.
- **Dev quota.** The `dev` namespace has 4 CPU and 10Gi for every project (`platform/stacks/cluster/dev.ts:14`).
- **Deploys.** isthmia deploys every PR to dev through `.github`'s `deploy.yml`.
- **Gherkin.** Features run on `@amiceli/vitest-cucumber` (#185 §5). `playwright-bdd` is planned for sign-in journeys (#173) but isn't installed anywhere.

**project-two.** It's a staff-only Next.js 16 app on the App Router, running on Supabase. It uses Tailwind v4 and shadcn's base-nova style on Base UI, and deploys to AWS with SST. This issue's earlier version described it in full.

- **Data access.** Server components call server-only fetch modules, and about 150 route handlers do reads and writes with a service-role client. Authorization is all in app code.
- **Business logic.** Aggregations live in pure modules with Vitest tests.
- **Tests.** It has no form library, no DOM or end-to-end tests, and no Gherkin.
- **Cost engine.** Its program and cost engine (season P&L, G&A, profit share) covers the same ground as the planning schema. The planning schema is its redesign.

## Approach

### 1. platform becomes the backend

Directus, every `schema.yaml`, the schema-apply code, and the roles and policies move to platform. Authentik stays in isthmia. This replaces #185's "Later" item, a per-repo schema apply.

- **Schema ownership.** One repo applies the whole schema, which ends #185's ownership problem. A domain's `schema.yaml` still has an owner, but owners are directories in platform, not repos. The "serialized schema changes" rule moves with it.
- **Stack.** A new platform stack (call it `backend`) runs Directus as a `WebService` per environment. It applies the schema and declares roles, policies, and machine users. The database and `PUBLIC_URL` stay the same.
- **Dependency direction.** Today isthmia's `authentik` project generates Directus's OIDC secret, and the `crm` project reads it (`src/authentik/index.ts:351`). After the move, platform generates the client ID and secret and exports them. isthmia's `authentik` project registers the application with those values, so isthmia still depends on platform and never the reverse.
- **The SDK.** platform publishes `@cyc-seattle/sdk` (name open) as ESM. It holds:
  - types generated from the merged schema
  - a client factory over `@directus/sdk`, for service tokens and for user sessions
  - sign-in helpers
  - It replaces `@cyc-seattle/crm`'s hand-written row types and isthmia's `DirectusClient` over time, and settles #127.
- **Apps.** Every app, the syncs included, becomes a client of the SDK. Later each app gets its own repo, and one shared UI component library serves them all. For now they stay in isthmia.
- **Prototypes.** Someone building a prototype adds their origin to Directus's redirect and CORS allow-lists, and signs in as themselves. Their permissions are their Directus policies.

### 2. Subtypes: a subtype table with a unique foreign key

Use this pattern for every base type and subtype, starting with products and programs:

- **Base table.** It holds the shared fields and a `kind` discriminator, for example `products(id, name, kind, revenue_account_id)`.
- **Subtype table.** Each subtype that has fields of its own gets a table with its own `id`, plus `product_id`: an M2O to the base that is required, unique, and cascades on delete. `programs` keeps its id and gains `product_id`.
- **Directus.** It sees an M2O on the subtype and a one-row O2M alias on the base, so deep reads work both ways (`products?fields=*,programs.*`).
- **Nested writes.** Apps create the base and subtype in one nested request.
- **Kinds without fields.** A kind with no fields of its own (charters, storage leases) gets no table until it needs one.
- **Kind check.** A check in the schema tests, or an audit finding, catches a subtype row whose base has the wrong `kind`. Directus validation can't compare across tables.

The other patterns don't fit as well:

- **Shared primary key** (`programs.id` = `products.id`). This is clean in Postgres. But Directus doesn't model a primary key that is also a foreign key, and it would change the id of every existing program.
- **One wide table.** Kinds diverge, so most columns would be empty for most rows. Per-kind permissions would need row filters instead of per-collection grants.
- **Directus M2A.** It joins through collection-name strings, so there is no foreign-key integrity.

Existing references to `programs` keep working: `classes.program_id`, `program_role_assignments`, and `google_group_id`. Fields that belong on the product, such as `name` and `revenue_account`, move to `products` with copy-then-drop steps. The apply drops a removed field's data.

### 3. Terms and collections

Clubspot is a system we sync with, and its terms stay at the sync boundary. The full glossary, with the Clubspot mapping, is on the privacy issue. In short:

| Term             | Meaning                                                     | Clubspot                                |
| ---------------- | ----------------------------------------------------------- | --------------------------------------- |
| **Program**      | A product of kind `program`: Guppies, Youth Beginner, J-Pod | A class, mapped by `program_id`         |
| **Offering**     | One program for one dated period: Guppies week 3            | A class × session                       |
| **Registration** | One person in one offering                                  | A registration entry                    |
| **Pool**         | A cost center grouping products. "Summer Camp" is one.      | A camp is only a registration container |

Team and season aren't defined for now.

Directus has one namespace: folders only group collections in the Data Studio. So the Clubspot mirrors take a `clubspot_` prefix, which frees `registrations` for our own. clubspot-sync writes canonical `offerings` and `registrations` from mapped classes and sessions. These replace the planning schema's `offering_external_refs`: a planned offering links to an actual offering instead.

The schema in platform is split into domains:

| Domain     | Collections                                                                                                           |
| ---------- | --------------------------------------------------------------------------------------------------------------------- |
| `crm`      | today's 7, plus `offerings` and `registrations`. Adds `programs.product_id`, and `people.share_contact` as the opt-in |
| `clubspot` | today's 13, renamed `clubspot_*`                                                                                      |
| `sync`     | today's 3                                                                                                             |
| `gsuite`   | `google_groups`                                                                                                       |
| `core`     | `products`, `accounts`, `qualifications`, `qualification_covers`, `boat_classes`, `resource_kinds`                    |
| `planning` | versioning, product plan, operations plan                                                                             |
| `finance`  | `plan_results`, `plan_metrics`, `actuals`                                                                             |

`docs/planning-schema.md` moves to platform with the schema, and its rule (diagrams change with the design) moves too.

### 4. Permissions

- **`Catalog editor`.** Staff get CRUD on `core`. Nothing there is sensitive.
- **`Planner`.** CRUD on `planning`, but only on drafts. Update and delete filter on the version's `status = draft`, and saved versions are read-only. Activating a version or freezing a baseline is a separate permission.
- **`Finance`.** Reads staff levels, salaried positions, bonus owners, and results. Without it, wages and bonus rates are hidden.
- **Machine users.** The engine and the actuals sync each get a machine user that writes only its own collections.
- **Staff.** The blanket rule stops covering new domains. Staff lose Data Studio access once the front end covers their work. Directus becomes the backend only, and the maintainer keeps the Data Studio as the admin tool.

### 5. The front end

- **Location.** A Next.js app at `packages/web` (name open) in isthmia, served under the portal at `cycsail.team/<path>` (path open). Caddy stays the front door at first. It routes the path to the Next.js service behind the same `forward_auth`, and the link page stays as it is. Later the Next.js app absorbs the link page and the roster, and Caddy goes.
- **Auth.** The app calls Directus as the signed-in user, never with a service token.
  - Directus sets its session cookie on the parent domain with `SESSION_COOKIE_DOMAIN`: `cycsail.team` in prod and `dev.cycsail.team` in dev. Dev and prod use different `SESSION_COOKIE_NAME`s, because prod's cookie also reaches dev hosts.
  - The Next.js server forwards that cookie to Directus through the SDK, and middleware refreshes it.
  - Sign-in redirects to `directus.<domain>/auth/login/authentik`. Authentik's session makes that silent after the portal's forward-auth.
  - Directus policies decide everything, so the app carries no security logic, as #166 and `architecture.md` want.
  - Community-facing pages (families, coaches, Parent Coordinators) call the backend's community endpoint as the user, not Directus's item API. The privacy issue explains why.
- **Data layer.** Server components read through the SDK. Writes are server actions, not route handlers, so the app gets Next.js's origin check and doesn't need project-two's CSRF guard. Validation uses zod schemas generated with the SDK types. Business logic and aggregations stay in pure modules with Vitest tests, as in project-two.
- **UI library.** `packages/ui` holds Tailwind v4, shadcn base-nova on Base UI, lucide, and sonner. It also takes project-two's generic pieces, copied and adapted: page header, back link, summary tiles, table row actions, confirm and content dialogs, sticky notice, info popover, toast wrapper, and the unsaved-changes hook. Its domain components serve as patterns to rebuild, not code to lift: the activity calendar, the season calendar, the attendance roster, and the CRUD manager tables. `packages/ui` moves to its own repo when a second app needs it.
- **Left behind.** These don't fit and stay in project-two:
  - the Supabase client
  - SST deploy
  - the CSV upload wizard
  - PII hashing
  - the 1,000–3,900-line client components
- **Hosting.**
  - The app builds with `output: "standalone"` into a non-root image, with an emptyDir for `.next/cache`.
  - It deploys as a `WebService` in a new isthmia project, `packages/infrastructure/src/web`, which goes after `portal` in `each-stack`.
  - Requests are about 250m CPU and 512Mi. The dev quota may need raising.
- **Tooling.** The app's `tsconfig` overrides `@cyc-seattle/ts-config` with `jsx` and `moduleResolution: bundler`, and adds `eslint-config-next` and browser globals. Once that settles, a ts-config PR adds a `./next` preset for later app repos. The Dockerfile manifest check covers the new packages.

### 6. Tests

- Each phase starts with its features PR, in line with #185's features-first rule.
- **Schema and permissions.** These features run on `vitest-cucumber` against dev Directus with throwaway users, in platform. For example: "a Planner can't edit a saved version" and "Staff can't read wages".
- **Front-end journeys.** These run on `playwright-bdd` against the dev deploy, in isthmia. They extend #173's baseline.
- **Schema work** runs against dev's Directus through the PR deploy. `directus-local` moves to platform with the schema.

### 7. Data migration

Nothing is bulk-copied from project-two. Its settings worth keeping, such as cost catalogs, boats, and staff levels, are re-entered through the new screens.

In the CRM, a one-off backfill runs as an isthmia script with a dry run, in dev and then prod:

1. Create a `products` row of kind `program` for each `programs` row, and set `programs.product_id`.
2. Create `accounts` from the distinct `programs.revenue_account` and `camps.clubspot_sales_account` values, then set `products.revenue_account_id`.
3. Switch gsuite-sync's audit to the account relation. Then drop `programs.revenue_account`.
4. clubspot-sync fills `offerings` and `registrations` from mapped classes and sessions. In Phase 4, planned offerings link to them.

## Alternatives

- **Planning data in an app-owned Postgres database.** This would avoid the 61-collection schema and Directus's lack of transactions across requests. It was rejected: the maintainer wants one backend, with Directus policies as the only gate.
- **Keep the schema in isthmia, and change the apply so each repo applies its own** (#185 "Later"). That's more apply code to keep correct for a split nobody needs once platform owns the schema.
- **Front end in its own repo now.** It would need published types, StackReferences into isthmia, and its own deploy wiring before the SDK exists. It moves out later.
- **Service token with authorization in the app** (project-two's model). Every edit becomes one machine user. That loses per-user audit, and a privileged token sits in a web server.
- **Directus content versioning for plan versions.** It versions one item at a time. A plan version is a whole tree of rows pinned in version sets.
- **A Next.js app replacing the portal on day one.** That ports the link page and roster before any staff screen ships. Caddy routing one path to Next.js gets there in smaller steps.

## Steps

Each step is one PR or one maintainer action. **[maintainer]** marks what only the maintainer can do. A **features** step is reviewed before the code that turns it green.

**Phase 0, Agreement.**

- [ ] 1. **[maintainer]** Close or retitle the issues listed below.

**Phase 1, The backend moves to platform.** Ships: dev and prod Directus deployed from platform with the same database and URL, SDK 0.1 on npm, and canonical offerings and registrations. Starts when #231 is done, so prod is already on the cluster.

- [ ] 2. **platform PR (features)**: today's role boundaries as features, such as "Coach reads rosters" and "Community sees only its own minors". These are #231 step 7's features, moved. The Community rules are being redesigned, so their features move with the privacy issue, not here.
- [ ] 3. **platform PR**: the `schema/` domains, with today's four `schema.yaml` files moved as they are. Also `mergeSchemas`, `applySchema`, verification and its tests, and the `planning-schema.md` rule.
- [ ] 4. **platform PR**: the `backend` stack in dev. It holds Directus, the schema apply, roles, policies, machine users, and the generated OIDC client, exported for Authentik. The sync tokens go to Kubernetes Secrets in the namespace.
- [ ] 5. **isthmia PR**: `authentik` registers Directus's application from platform's outputs. The syncs and the portal read Directus from platform. The `crm` project leaves dev. Delete the moved `schema.yaml` files and the apply code.
- [ ] 6. **platform PR, then isthmia PR**: the `clubspot_` prefix, and canonical `offerings` and `registrations`. clubspot-sync re-syncs into the new collections, copies `program_id` and `person_id` across by Clubspot id, and fills offerings and registrations. Drop the old collections.
- [ ] 7. **[maintainer]** Prod: deploy `backend` to `prod` on the existing database and `PUBLIC_URL`, and remove isthmia's `crm` from prod.
- [ ] 8. **platform PR**: publish the SDK, with generated types, the client factory, and sign-in helpers. **[maintainer]** first npm publish and trusted publisher.
- [ ] 9. **isthmia PR**: the syncs use the SDK's types. Retire `@cyc-seattle/crm`'s row types.

**Phase 2, Core catalog.** Ships: products, accounts, and the other catalog collections in Directus, with programs as a subtype of product.

- [ ] 10. **platform PR (features)**: catalog permissions. Catalog editors write, and Coach and Community see nothing.
- [ ] 11. **platform PR**: the `core` domain, `programs.product_id`, the subtype kind check, and the `Catalog editor` policy for Staff. Document the subtype pattern in platform's `AGENTS.md`, and update the diagrams.
- [ ] 12. **isthmia PR, then [maintainer]**: the backfill script. Run it in dev, then prod.
- [ ] 13. **isthmia PR**: gsuite-sync's revenue-account audit reads `products.revenue_account_id`. **platform PR**: drop `programs.revenue_account`.

**Phase 3, Front end and catalog screens.** Ships: staff edit the catalog at `cycsail.team/<path>` instead of the Data Studio.

- [ ] 14. **isthmia PR (features)**: sign-in, and catalog CRUD journeys on `playwright-bdd`.
- [ ] 15. **platform PR**: Directus's `SESSION_COOKIE_DOMAIN`, per-environment `SESSION_COOKIE_NAME`, and the app's origin in the redirect and CORS allow-lists. Raise the dev quota if needed.
- [ ] 16. **isthmia PR**: `packages/ui`, with the stack and generic components adapted from project-two, plus their tests.
- [ ] 17. **isthmia PR**: the Next.js app shell (session forwarding, refresh, sign-in redirect, and the standalone image) and its `web` project. The portal's Caddy routes the path to it. Deploy it to dev.
- [ ] 18. **isthmia PR**: catalog screens for products (with the program subtype), accounts (the parent and contra tree), qualifications and covers, boat classes, and resource kinds.
- [ ] 19. **[maintainer]** Deploy to prod. Tell staff the catalog has moved.

**Phase 4, Versioning and one product plan.** Ships: a planner builds a program's offerings and schedule in a draft, saves it, and maps it to Clubspot.

- [ ] 20. **platform PR (features)**: drafts are editable and saved versions aren't. Only the right permission activates a version.
- [ ] 21. **platform PR**: the versioning and product-plan collections, with `plan_offerings` linked to actual `offerings`, and the `Planner` policy. Save-as-version copies a version's tree in one transaction (Decision needed: a Directus endpoint extension in platform, or the engine).
- [ ] 22. **isthmia PR**: the schedule engine. A pure module turns schedule rules and trips into activities, with tests.
- [ ] 23. **isthmia PR**: plan list, version history, offering editor, and the calendar.
- [ ] 24. **isthmia PR**: the mapping screens: Clubspot classes to programs (today's hand-set `program_id`), and planned offerings to actual offerings. Raise an `unplanned_offering` finding for an actual offering with no planned one.

**Phase 5, Operations plan and results.** Ships: the P&L and metrics for the active version set, with scenarios and baselines.

- [ ] 25. **platform PR (features), then platform PR**: the operations-plan collections, `plan_results`, `plan_metrics`, the `Finance` policy, and the engine's machine user.
- [ ] 26. **isthmia PR**: the engine. It covers costing, pools, formulas, and bonus owners, and writes results for baselines.
- [ ] 27. **isthmia PR**: operations-plan screens, results, scenarios, and baselines.

**Phase 6, Actuals and variance.** Ships: plan against actuals by cost center and month.

- [ ] 28. **isthmia PR**: an actuals job from Clubspot billing. QuickBooks waits on a decision about its source (clubspot-sdk#11 covers Clubspot accounting only).
- [ ] 29. **isthmia PR**: variance screens.

**Phase 7, Off the Data Studio.** Ships: staff no longer need the Data Studio.

- [ ] 30. **isthmia PRs**: audit-finding review (#170), session capacity (#123), and participant linking.
- [ ] 31. **platform PR**: Staff lose `appAccess`.
- [ ] 32. Update `AGENTS.md`, the READMEs, and `docs/architecture.md` in platform and isthmia. Delete this draft.

project-two's other features get their own issues: insights, the marketing worklists, schedules, inventory, attendance, and leads.

## Decisions

The maintainer settled these while the plan was drafted:

1. **project-two's code** may be copied into cyc-seattle's public repos and relicensed under their license, with no attribution.
2. **First users** are staff and program planners. Coaches and guardians come later.
3. **Directus stays as the backend only.** The front end sits over its API. Staff leave the Data Studio. Replacing Directus later stays possible.
4. **The first slice** is the core catalog, with catalog CRUD as the first screens.
5. **One plan.** The ERP work and the project-two port share this issue.
6. **All planning data lives in Directus**, all 37 collections.
7. **Programs are a kind of product**, and both collections stay. The subtype pattern in Approach §2 is the default for every base type and subtype.
8. **The front end calls Directus as the signed-in user.**
9. **platform becomes the backend.** It owns Directus, the schema, the roles, and a published SDK for apps and prototypes. Authentik stays in isthmia. Each app becomes its own repo later, sharing one UI component library.
10. **The backend moves before the front end.** The front end lives in isthmia for now.
11. **The front end is served under the portal**, at `cycsail.team/<path>`.
12. **Terms.** Programs are what Clubspot classes map to, such as Guppies and J-Pod. An offering is a program for one dated period. A registration is a person in an offering. Summer Camp is a pool. Team and season aren't defined for now.
13. **The Clubspot mirrors take a `clubspot_` prefix.** Directus has one namespace.
14. **Community privacy** is redesigned around opt-in on its own issue, and reads go through a backend endpoint.

**Still open:**

- the app's package name, URL path, and the SDK's package name
- where save-as-version and the engine run: a Directus extension in platform, or a module in isthmia
- the formula language for `formula`, `expression`, and `hours_formula`, and how it's evaluated safely
- where families and households live, since `docs/crm-schema.md:15` rules them out
- the QuickBooks source for actuals
- whether Directus's MCP OAuth server should also sign in prototype apps

## Issues

**Closed or changed by this plan:**

| Issue                 | Change                                                                                                                                  |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| #185                  | Follows on. Its "Later" item (a per-repo schema apply) is replaced by moving the schema to platform. Phase 7 (onboarding) is unaffected |
| #231                  | Depends: Phase 1 starts when #231 is done. Its step 7 features move to platform in Phase 1                                              |
| #166                  | Changed: J-Pod is a program, not a "team" class. Its privacy decisions move to the new privacy issue                                    |
| #182                  | Closed by the privacy issue: the community endpoint resolves a caller's emails once                                                     |
| #175                  | Superseded by the privacy issue: Community users get no item permissions to probe                                                       |
| #127                  | Closed by the SDK (step 8)                                                                                                              |
| #142                  | Changed: once staff leave the Data Studio, there are fewer edits to pull back. Keep it for the maintainer's admin edits                 |
| #170                  | Closed by step 30                                                                                                                       |
| #123                  | Closed by step 30, which is a front-end screen, not a Directus panel                                                                    |
| #98                   | Changed: role-filtered links come free when Next.js absorbs the link page                                                               |
| #177                  | Moot once the link page moves to Next.js                                                                                                |
| #69                   | Close as superseded                                                                                                                     |
| #164, #165, #156, #74 | Changed: the new policies (Catalog editor, Planner, Finance) join this access model. #74 moves to platform with the roles               |
| #126                  | Depends: the planning schema adds many relations, so fix verification before Phase 4                                                    |
| #168                  | Depends: new policies get renamed while settling                                                                                        |
| #181                  | Coordinate: it changes `people` while the schema moves                                                                                  |

**New issues to open:**

- Redesign the Community privacy model around opt-in. It carries the glossary, the privacy rules, and the community endpoint.

- Phase issues for Phases 1 to 7, each with its steps.
- Pick the formula language and its evaluator.
- Port project-two's insights and marketing worklists.
- Port schedules and the organizer-site scrapers.
- Port inventory: boats, charters, damage, and storage racks.
- Port per-plan attendance.
- Decide where families and households live.
- A QuickBooks source for actuals.
- Extract `packages/ui` and the app into their own repos, once the SDK is stable.
- A ts-config `./next` preset.
