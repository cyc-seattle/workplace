Another contributor's project overlaps with isthmia and runs on Supabase. If the two projects combine, one of them changes backends. This compares Directus and Supabase for that decision, as of October 2026.

## Recommendation

Keep Directus as the CRM's backend, and move the overlapping parts of the Supabase project onto it (path A). The two things that would be hardest to rebuild are the two that Directus gives isthmia today: a back office for non-technical staff (the Data Studio), and the relationship-based permissions behind the roster and the planned guardian portal. Supabase has no staff back office. Its permissions are row-level SQL, so the five Community policies would need a redesign, not a translation. Directus's biggest risk, its license, got smaller in September 2026, when the Open Innovation Grant became perpetual with unlimited seats.

Supabase's advantages are real, and they line up with #185's goals: no license, permission rules that run and get tested in CI, plain SQL migrations, and many more contributors and AI tools that know it. They justify a move if any of these is true:

- Staff don't need the Data Studio, or his project already has a staff UI worth adopting.
- His project is the bigger codebase and depends on Supabase-only features such as Edge Functions, Realtime, or Storage policies.
- Directus changes its terms again, or CYC stops qualifying for the grant.

If isthmia leaves Directus, it should leave before the guardian medical rules (#65) get written as Directus filters, and it should settle the staff UI first. Path C, which keeps Directus only as the staff UI over Supabase's Postgres, is the realistic version of that move.

## What each one is

**Directus** sits on an SQL database you bring. It reads the existing tables, then adds a REST and GraphQL API, auth, a permission engine configured as data, an activity and revision log, Flows, an MCP server, and the Data Studio, an admin app for non-developers. It runs as one container. It is source-available under the MSCL, and since v12 (June 2026) it enforces its own license tiers.

**Supabase** is a Postgres platform. Each project gets its own Postgres plus PostgREST (an API generated from the schema), Auth, Realtime, Storage, Edge Functions, and Studio, a dashboard for developers. Access control is Postgres row-level security (RLS), written in SQL. The hosted cloud is the main product, and self-hosting is a community-supported Docker Compose stack. The code is Apache-2.0, with Auth and PostgREST under MIT.

Both store data in ordinary Postgres tables, so moving data in either direction is a dump and restore. The parts that don't move are the ones around the tables: permissions, auth, the admin UI, and history.

## What isthmia uses Directus for

A move to Supabase has to replace each of these.

1. **The Data Studio.** Staff review `duplicate_person` findings, hand-maintain programs, program roles and assignments, `promoted_fields`, and `classes.program_id`, and read the `sync_tasks` tree (`docs/crm-schema.md`).
2. **Permissions.** There are six roles (`packages/infrastructure/src/infrastructure/directus-roles.ts`) and five Community policies (`packages/infrastructure/src/crm/community-rules.ts`). Some filters chain more than a dozen relations to reach `$CURRENT_USER.email`. Each rule pairs a row filter with a field list, so the same `people` row can come back with a name and school under one policy and an email and phone under another.
3. **Auth.** Authentik is the OIDC provider. New sign-ins register into the Community role, the portal's `fetch` calls use session-cookie mode, and the two sync users have static tokens (`packages/substrate/deploy/docker-compose.yml:52-75`).
4. **The API.** The syncs use `DirectusClient` (`packages/directus/src/client.ts`), and the portal's browser code calls `/items`, `/users/me`, and `/permissions/me` (`packages/portal/src/roster/browser.ts`).
5. **Schema as code.** Four `schema.yaml` files, about 9,600 lines, merge and apply through about 1,400 lines of Pulumi dynamic providers (`packages/infrastructure/src/directus/client.ts` and `resources.ts`).
6. **History.** The CRM's provenance design is `directus_activity` and `directus_revisions` (`docs/crm-schema.md`, "Change tracking and provenance").
7. **MCP.** Directus's MCP server acts as the signed-in user, under that user's policies (#154).

## Differences that matter here

### Staff back office

The Data Studio is built for people who don't write code. It has relational forms, filters, saved layouts, and per-item revision history, and each user's policies limit what it shows.

Supabase Studio is a developer console. Its roles are Owner, Administrator, Developer, and, on Team and Enterprise only, Read-only. A role covers an organization, or on Team and Enterprise a single project, but never a table or a row. Its table and SQL editors run as a privileged database role that bypasses RLS by default. Self-hosted Studio has one project and one shared login (`DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD`). A Supabase back office means building one, buying one (Supamode, Retool, Jet Admin), or running Directus on top.

### Permissions

Directus checks permissions in its API layer. Policies add up, each rule is a filter plus a field list, and filters can use `$CURRENT_USER` and `$NOW` across relations. A client that connects to Postgres directly skips all of it.

Supabase enforces RLS inside Postgres, so every client gets the same rules, direct SQL included. A rule can be any SQL, and pgTAP can test it. RLS works on rows only. Column grants apply per role, not per row, so "email only when opted in" needs the contact fields in their own table with their own policy, or a view or function for each screen. Supabase's secret key bypasses RLS, so a least-privilege sync job needs its own Postgres role and grants.

### Auth

Supabase Auth has accepted custom OIDC providers since early 2026, so Authentik can stay the sign-in. Free projects get 3 custom providers, and Pro has no limit. PKCE is on by default, and ID tokens are checked against the provider's JWKS. Self-hosting needs release 0.8.1 or later, and providers are created through the Auth admin API because self-hosted Studio has no screen for them. An RLS rule can key on `auth.jwt() ->> 'email'`, as the Community rules key on `$CURRENT_USER.email` today.

### Licensing and cost

Directus:

- **License.** The MSCL-1.0 is source-available, and each version becomes GPLv3 four years after release. It is the project's third license: GPLv3 until v10 (April 2023), BSL 1.1 until v12 (June 2026), and MSCL since.
- **Without a key.** The Core tier allows 3 Studio seats, 25 collections, and 5 Flows, with no SSO, and it ignores custom permission rules. The merged schema has 24 collections. On an unlicensed v12.3.1, creating a filtered permission returns a 403 (`docs/manual-setup.md` §6).
- **The Open Innovation Grant.** It is free for organizations with under $5M in revenue and fewer than 50 employees. Donations and grants don't count as revenue, unpaid volunteers don't count as employees, and revenue is measured across a group under common ownership. Since September 2026 the grant is perpetual, with unlimited seats and no feature limits, and Directus can end it only for cause. Telemetry is required. A key has 5 activations, each bound to one `PUBLIC_URL` and database, and a second project needs its own key.
- **Enforcement.** The instance checks its license online at least every 12 hours. When a check fails, it keeps the license, shows admins a lapse date, and drops to Core after that date. SSO then stops for everyone except admins, and the Community rules stop applying. The docs don't say whether a dropped rule denies access or stops filtering, which matters most for the medical data.
- **Paid.** Team costs $499 a month billed annually, or $599 month to month.

Supabase:

- **License.** The platform is Apache-2.0, and Auth and PostgREST are MIT. Self-hosting is free.
- **Free plan.** It has 500 MB, no backups, and a project pauses after a week without activity. It isn't fit for real member data.
- **Pro.** It costs $25 a month per organization, plus compute for each project. A $10 credit covers one Micro instance, and Small costs $15. It includes 8 GB of disk and 7 days of daily backups. Point-in-time recovery costs $100 a month per 7 days kept.
- **Team.** It costs $599 a month and adds the SOC 2 report and a HIPAA add-on. No nonprofit discount is listed.

### Hosting under #185's plan

The #185 plan runs everything on GKE Autopilot, written in Pulumi TypeScript without Helm, and keeps Cloud SQL for its backups and point-in-time recovery.

- **Directus** is one Deployment against Cloud SQL. It fits the plan as written.
- **Self-hosted Supabase** is 11 services in the official compose file: studio, api-gw, auth, rest, realtime, storage, imgproxy, meta, functions, db, and supavisor. Kubernetes support is community-only, through a Helm chart or an early operator, so each service would be a hand-written Deployment. The stack expects Supabase's own Postgres image, which carries a superuser-level admin role and extensions such as pg_net, supabase_vault, pgsodium, and pg_graphql. Cloud SQL offers none of those extensions and no true superuser (`packages/infrastructure/src/infrastructure/directus.ts:105`). Third-party write-ups say a managed Postgres can work only with heavy setup. In practice the CRM database would leave Cloud SQL, and CYC would own its backups. Supabase's self-hosting docs list managed backups, point-in-time recovery, and branching as unavailable.
- **Supabase Cloud** handles backups and upgrades. It also moves the database that holds minors' medical data out of CYC's GCP project to a new processor. Pulumi reaches it only through the bridged Terraform provider, which is a public alpha and covers project settings and branches. Schema and RLS changes go through the Supabase CLI in CI. Authentik, the portal, and the syncs stay on GKE, and Authentik still needs Cloud SQL.

### Schema management

Directus applies snapshot YAML through `/schema/diff` and `/schema/apply`. isthmia needed its own scoping logic for that (#109). An apply still reverts edits made in the Studio (#142), and it drops any extension field the applied snapshot doesn't declare. That last behavior is why every package's schema merges and applies once, and why repos can't own their own schemas yet (#185, "Later").

Supabase uses SQL migrations, or declarative schema files that pg-delta diffs into migrations. The older migra engine misses view owners and grants, comments, roles, and domains. Data changes are never captured, and Supabase says to review every generated migration. One Postgres schema per app would let each app own its own tables. The CLI keeps one migration history per database, though, so several repos sharing one database would still need a convention.

### Testing and dev

Directus permission rules only run on a licensed instance, and each fresh instance spends one of the key's 5 activations (#172). #185 answers that with one licensed dev Directus, which PRs use one at a time.

`supabase start` runs the whole Supabase stack in Docker, locally or in CI, and `supabase test db` runs pgTAP tests. Every PR could test the RLS rules on its own stack, in parallel, without a license. Supabase Cloud also has preview branches, each paying for its own compute.

### History and audit

Directus records every API write with a full snapshot and a delta, for every collection, and the Studio shows the history on each item. Supabase has no built-in row history. The options are supa_audit (Supabase's own extension, lightly used), a trigger-based audit table, or pgaudit for statement logs. Each of them still needs a screen for reading the history.

### API and sync jobs

`DirectusClient` pages at 500 rows and splits writes into chunks of 250 to stay under Directus's body limit. Each chunk commits on its own, so a failed batch can leave earlier chunks written (`packages/directus/src/client.ts:141`). On Supabase, the syncs could use PostgREST through supabase-js with generated types, or connect over SQL and use real transactions. Supabase Queues (pgmq) has visibility timeouts, and `sync_tasks` has no lease: it depends on a job parallelism of 1 (`packages/directus/src/queue.ts:52`).

### Contributors and AI tools

Supabase is the default backend of Lovable Cloud and of Bolt's built-in database, which is probably how his project landed on it. Volunteers and AI agents know it, and its RLS and migrations are plain SQL. Directus has a smaller community and its own concepts, such as snapshots, policies, and filter JSON. #185 counted nine of the last ten CRM PRs touching `packages/infrastructure` too, mostly its Directus files.

The two MCP servers do different jobs. Directus's acts as the signed-in staff member, under that person's policies. Supabase's is a developer tool: it acts with a developer's Supabase account and can run SQL on a project.

## Migration paths

### A: his project moves onto isthmia's Directus

- His tables move into the CRM database and into a package's `schema.yaml`, as their own package if they're a separate domain.
- His frontend's supabase-js calls become Directus REST calls, signed in through Authentik with Directus's session cookie, the way the portal works.
- His RLS policies become Directus policies, which the grant covers. If his app joins isthmia's instance, it shares the key.
- Edge Functions become CronJobs (#185) or Flows, and Storage becomes Directus files on the GCS driver.
- **Cost:** a rewrite of his data layer. Vibe-coded apps tend to call supabase-js from many components, so the cost grows with his app.
- **Risk:** isthmia stays with a vendor that has changed its license twice in three years.

### B: isthmia moves to Supabase

1. Translate about 9,600 lines of `schema.yaml` into SQL migrations, and delete about 1,400 lines of Pulumi Directus providers.
2. Redesign the permissions as RLS, for example by splitting contact fields out of `people`. Write helper functions for the relation chains, and a pgTAP test for each Community rule. This is the medical-data boundary, so it needs the most care.
3. Move auth to Supabase Auth with Authentik as a custom OIDC provider, and give each sync job its own Postgres role.
4. Replace `DirectusClient` and the portal's data layer.
5. Pick a history mechanism, supa_audit or triggers. Decide whether `directus_revisions` survives as an archive table.
6. Pick hosting: Supabase Cloud, or a self-hosted stack off Cloud SQL (see Hosting).
7. Build or buy the staff back office. Nothing in Supabase replaces the Data Studio.

### C: Directus as the staff UI over Supabase's Postgres

Directus documents this setup. Directus connects as a single database user, so RLS doesn't apply to it, and its guide says not to rely on RLS for anything edited in Directus. Staff would use the Data Studio with simple Directus permissions. Families, coaches, guardians, and his app would go through Supabase Auth and RLS, which CI can test. SQL migrations would own the DDL, and Directus would hold only display metadata. The database becomes Supabase's, so C inherits B's hosting choice.

The cost is two auth systems and two permission systems over one database. The grant stays, because staff SSO needs a license. The gain is that the medical-data boundary would live in Postgres, so a lapsed Directus license couldn't open it.

A variant keeps Cloud SQL. PostgREST and RLS run on plain Postgres, and supabase-js's `from()` queries are PostgREST queries, so his data calls would carry over to postgrest-js. His auth calls wouldn't. Nobody has tried this here yet.

## Open questions

For the other contributor:

1. What does his project do, and who signs in to it: staff, coaches, or families?
2. Which Supabase features does it use besides Postgres: Auth providers, RLS, Storage, Edge Functions, Realtime, or Cron?
3. Which Supabase plan is it on, and does it hold real member data? The Free plan has no backups and pauses after a week without activity.
4. Does it hold the same people and registrations that `clubspot-sync` brings in, or different data?

For CYC:

1. How much do staff use the Data Studio, and how many of them need it?
2. When a Directus license lapses, does a dropped filter rule deny access or stop filtering? Ask Directus licensing, and test it on the dev instance once #185 builds it.
3. If the Sailing Center belongs to a larger CYC entity, does the whole group meet the grant's revenue and headcount limits?

## Sources

- [Directus licensing overview](https://directus.com/docs/licensing/overview)
- [Directus v12 breaking changes](https://directus.com/docs/releases/breaking-changes/version-12)
- [Directus pricing](https://directus.com/pricing)
- [Open Innovation Grant FAQ](https://directus.com/oig/faq)
- [Directus: making the OIG perpetual](https://directus.com/resources/making-the-oig-perpetual-and-clearer)
- [Directus: changing our license, one year later](https://directus.com/resources/changing-our-license-one-year-later)
- [Directus community: v12 and the MSCL](https://community.directus.com/t/everything-v12-upgrades-new-features-and-mscl-license/2237)
- [Directus: connect Supabase Postgres to Directus](https://directus.com/docs/guides/integrations/supabase)
- [Supabase pricing](https://supabase.com/pricing)
- [Supabase project pausing](https://supabase.com/docs/guides/platform/free-project-pausing)
- [Supabase self-hosting](https://supabase.com/docs/guides/self-hosting)
- [Supabase self-hosted custom OAuth/OIDC providers](https://supabase.com/docs/guides/self-hosting/self-hosted-custom-oauth-providers)
- [Supabase custom OAuth/OIDC providers](https://supabase.com/docs/guides/auth/custom-oauth-providers)
- [Supabase platform access control](https://supabase.com/docs/guides/platform/access-control)
- [Supabase declarative database schemas](https://supabase.com/docs/guides/local-development/declarative-database-schemas)
- [Supabase Terraform provider](https://supabase.com/docs/guides/deployment/terraform) and [its Pulumi package](https://www.pulumi.com/registry/packages/supabase)
- [Supascale: external Postgres with self-hosted Supabase](https://www.supascale.app/blog/using-external-managed-postgres-with-selfhosted-supabase)
- [supa_audit](https://database.dev/kiwicopple/supa_audit)
- [Lovable Cloud on Supabase](https://supabase.com/blog/lovable-cloud-launch)
- [Cloud SQL for PostgreSQL extensions](https://docs.cloud.google.com/sql/docs/postgres/extensions)
