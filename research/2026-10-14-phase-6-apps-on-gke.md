Part of #185. isthmia's apps (Authentik, Directus and the CRM, the portal, and the two syncs) move off the substrate VM onto the GKE cluster from #215. Dev first, then prod, one project at a time. The VM retires at the end.

## Context

Line numbers refer to isthmia `main` at 0ef6d24e and platform `main` at 3014525f.

**What runs on the VM.** One compose project, `packages/substrate/deploy/docker-compose.yml`, on a COS VM (`src/infrastructure/compute.ts:33`):

| Service                                | Image                                                                                | Notes                                                                                                                                            |
| -------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `caddy`                                | the `substrate` image: Caddy plus the built portal (`packages/substrate/Dockerfile`) | TLS by ACME. Serves the portal behind `forward_auth` to Authentik's embedded outpost, and proxies `login.` and `directus.` (`deploy/Caddyfile`)  |
| `directus`                             | `directus/directus:12.3.1`                                                           | No volumes: uploads are already ephemeral. OIDC to Authentik. Licensed when `directus-license-key` is set                                        |
| `authentik-server`, `authentik-worker` | `ghcr.io/goauthentik/server:2026.8.3`                                                | No Redis. Email templates bind-mounted read-only from git. Connection caps keep both apps under `db-g1-small`'s ~50 connections (compose :86-88) |

- **Secrets** reach containers through `apply.sh`, which reads 11 Secret Manager secrets into an env file at boot (`substrate-bootstrap-script.ts:45-78`). Pulumi generates seven of them with `randomSecret` (`secret.ts:67-82`), plus the two sync tokens. Five are set by hand: `directus-license-key`, `google-oauth-client-id` and `-secret`, `clubspot-username` and `-password` (`docs/manual-setup.md:48-64`).
- **Mail.** Authentik sends through the Workspace SMTP relay, `smtp-relay.gmail.com:587`, which admits the VM by its static IP (`docs/manual-setup.md:164-168`). There is no SMTP password.
- **Databases.** `infrastructure` creates the `directus` and `authentik` users through the Cloud SQL Admin API (`database.ts:14-24`). It creates their databases with the `postgresql` provider, over an IAP tunnel through the VM (`scripts/pulumi-tunnel`, `scripts/db-tunnel`).
- **The syncs** are Cloud Run jobs with Cloud Scheduler triggers, hourly (`clubspot-sync-job.ts`, `gsuite-sync-job.ts`). They reach Directus at its public URL. gsuite-sync runs as `gsuite-sync@`, which holds Groups Administrator in Workspace.
- **DNS.** `cycsail.team`, `login.cycsail.team`, and `directus.cycsail.team` are A records to the VM, owned by `infrastructure` (`portal.ts:16`, `authentik.ts:75`, `directus.ts:123`).
- **Projects.** `infrastructure` owns the VM, the databases, users, and secrets, the Directus roles and users (`directus-roles.ts`), the jobs, and the DNS records. `authentik` and `crm` reach their apps over the public URLs and read `infrastructure` through StackReferences.
- **Deploys** run from laptops. `substrate-apply` needs IAP SSH as root, which #215 kept away from `deploy-runner`.

**What platform gives an app today** (`@cyc-seattle/platform`, unpublished):

- `getPlatformOutputs()` reads `platform/outputs.json`: project, region, cluster, namespace, Gateway, domain, the Cloud SQL connection name, and the registry. It has no Cloud SQL host.
- `WebService` creates a Deployment, a ServiceAccount, a ClusterIP Service named after the component, an HTTPRoute, and a HealthCheckPolicy. It always creates a public route. It has no command, volumes, limits, or second port, and it runs read-only as non-root.
- Nothing for CronJobs, internal-only services, databases, or secrets. No release workflow.
- Only the `dev` namespace exists. Its quota is 2 CPU and 6 GiB, and its LimitRange defaults each container's limit to 250m and 512Mi, below what Authentik needs. Its NetworkPolicy admits only the same namespace and the load balancer's health checks.
- `deploy-dev` has no Secret Manager or Cloud SQL access. Cloud SQL is private-IP only, so runners can't reach Postgres.

**The fakes** (#210) aren't published as images. clubspot-sdk's fake is Parse Server on Postgres with a seed, port 1337. Its master key and app ID are public test values. gsuite-sdk's fake holds state in memory, ignores auth, and starts empty. isthmia still pins both SDKs at `^0.1.0`. `gsuite-sync` passes no `rootUrl` (`packages/gsuite-sync/src/main.ts:69-70`).

**Directus license (#172).** One Open Innovation Grant key, 5 activations, some already spent. An activation binds to an instance: its database and `PUBLIC_URL`. Prod keeps its activation if Directus keeps its database and URL. Dev needs an activation that survives redeploys.

## Approach

### 1. Projects in isthmia

Every project has a `dev` and a `prod` stack, under `packages/infrastructure/src/`. Each owns its workloads, its database, its secrets, and its hostname:

| Project         | Holds                                                                                                                   | Dev only                                         |
| --------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `authentik`     | Authentik server and worker, its database and secrets, today's flows, sources, and applications, the `login.` redirects | Mailpit                                          |
| `crm`           | Directus, its database and secrets, its roles and users (from `infrastructure`), the schema and rules                   |                                                  |
| `portal`        | The portal image: Caddy and the static site, with `forward_auth` to `authentik-server` in the same namespace            |                                                  |
| `clubspot-sync` | Its image and CronJob                                                                                                   | The Clubspot fake, and its database on `cyc-dev` |
| `gsuite-sync`   | Its image and CronJob, with Workload Identity to `gsuite-sync@` in prod                                                 | The Workspace fake                               |

`scripts/each-stack` (as in platform) applies them in that order. `crm` reads `authentik` for the OIDC client secret. The syncs read `crm` for their Directus tokens. Each read is a StackReference in the same environment's bucket.

`infrastructure` shrinks as prod moves and is deleted with the VM. Directus's Authentik application stays in `authentik` for now.

### 2. What `@cyc-seattle/platform` adds

- **`Workload`**: the Deployment, ServiceAccount, and Service that `WebService` builds on, without a route, for internal services such as Authentik's worker, Mailpit, and the fakes. Both components gain `command` and `args`, `emptyDir` and ConfigMap mounts, extra ports, and limits equal to requests.
- **`ScheduledJob`**: a CronJob with the same secure defaults, `concurrencyPolicy: Forbid`, Spot in dev, and a `member` for grants.
- **Outputs**: `sqlHost`, the instance's private IP, and `gatewayAddress`, for prod DNS records.
- **Releases.** The maintainer publishes `0.1.0` by hand. `release.yml` then releases each merge to `main`, as in the other libraries.

### 3. Secrets

Pods read Kubernetes Secrets that Pulumi writes. They never call Secret Manager, so a pod needs no IAM for its secrets, and the workloads stay portable.

- **Generated values** (keys, database passwords, tokens) are `random` resources in the owning project's state, encrypted by that environment's KMS key, and written straight to a Kubernetes Secret. Prod moves today's values into the new projects with `pulumi state move`, so nothing rotates.
- **Values set by hand** stay in Secret Manager. The deploy identity reads them at deploy time. Dev's live under a `dev-` prefix, and `bootstrap` grants `deploy-dev` access to those secrets only. Dev needs only `dev-directus-license-key`: the fakes take the place of Clubspot and Workspace, and Google sign-in can wait for a dev OAuth client.
- **The `dev-` prefix** applies only to project-wide names: Secret Manager secret IDs. Everything else in dev lives in the `dev` namespace or on `cyc-dev`.

### 4. Databases without a tunnel

Pulumi creates databases and users through the Cloud SQL Admin API (`gcp.sql.Database`, `gcp.sql.User`), never over a Postgres connection. Directus and Authentik create their own tables at start. Prod's two `postgresql.Database` resources are removed from state and imported as `gcp.sql.Database`, which changes nothing in Postgres.

- `bootstrap` grants `deploy-dev` `roles/cloudsql.admin` with an IAM condition on the `cyc-dev` instance.
- Pods reach Cloud SQL's private IP directly. The VPC peering already routes the pod ranges.
- `mise run db-shell` replaces `db-tunnel`: a throwaway `postgres:16` pod in the namespace, running `psql`.

### 5. Ingress and DNS

- **Dev** hostnames are `dev.cycsail.team` (the portal), `login.dev.cycsail.team`, and `directus.dev.cycsail.team`, under dev's wildcard listener and DNS. The roster's `directus.${location.hostname}` keeps working.
- **Prod.** `cluster` adds the `prod` namespace, labeled like `dev`, with its quota and policies. It also adds HTTPS listeners for `cycsail.team` and `*.cycsail.team`, and a DNS-authorized certificate for both. The certificate is issued before any record moves.
- Prod's A records move from the VM's address to `gatewayAddress`, one hostname per cutover. Each project then owns its own record.
- Caddy's `login.` redirects become an HTTPRoute in `authentik`, with `RequestRedirect` filters for `/` and `/if/user/`.
- The VM's Caddy strips `X-Authentik-*` headers that a client sends. The portal's Caddy keeps doing that.

### 6. Mail

- **Dev**: Authentik sends to Mailpit (`mailpit:1025`). An egress NetworkPolicy in `dev` blocks ports 25, 465, and 587 to anything outside the cluster, so dev can't send real mail.
- **Prod**: Cloud NAT gets a static address, and the Workspace relay admits it (Decision 1).

### 7. Images

- Each project builds its own image with `docker-build`, tagged with the commit SHA. Only the dev deploy builds and pushes. Prod resolves the same tag to a digest, so prod runs what dev ran. A prod deploy of a commit that dev never built fails with that message.
- Authentik, Directus, and Mailpit run upstream images, pinned by tag for Renovate.
- clubspot-sdk and gsuite-sdk publish their fakes to GHCR (`ghcr.io/cyc-seattle/clubspot-fake`, `ghcr.io/cyc-seattle/workspace-fake`) as public images, on each release. Pulling a public GHCR image needs no token.

### 8. Deploying from Actions

- isthmia's `pull-request.yml` gets the `dev` job now: a PR deploys its branch to dev and runs `mise run integration`.
- The `prod-preview` and `prod` jobs come when the VM is gone. Until then, `infrastructure`'s IAP apply keeps prod deploys on laptops.
- `mise.toml` keeps `GOOGLE_APPLICATION_CREDENTIALS` when Actions sets it, as platform's does.

### 9. Tests and the reset workflow

Gherkin features in `features/`, steps in `test/features/`, run by `mise run integration` against dev:

- **clubspot-sync**: #185's scenario. Seed the fake, run the CronJob as a Job, and check the CRM.
- **gsuite-sync**: a program role becomes a group membership in the Workspace fake.
- **Community rules** (#172, #175): the 743-line `packages/infrastructure/integration/community-rules.test.ts` moves onto dev's licensed Directus and becomes Gherkin. #175 adds the depth and filter-probing assertions.
- **Sign-in** (#173): Playwright journeys through `playwright-bdd` for today's flows: the emailed code, read from Mailpit, and the portal gate. #173's redesign stays its own work.

Tests reach the fakes and Mailpit through the Kubernetes API's service proxy, as `deploy-dev`, so none is exposed on the Gateway. The `dev` NetworkPolicy must admit that path; Step 2 checks it.

The reset workflow (`reset-dev.yml`, by hand) runs `mise run reset` as `deploy-dev`:

1. Empty the CRM collections.
2. Reseed the fakes.
3. Run both syncs.

It keeps the database, so Directus keeps its activation. `.github`'s `deploy.yml` accepts `task: reset` in v2.2.0, because the WIF condition admits only that workflow.

### 10. Job-failure alerts (#205)

- `cluster` adds a log-based alert on any Job in `prod` that fails (`BackoffLimitExceeded`, `DeadlineExceeded`).
- It also adds an absence alert on each CronJob's successful completions over 3 hours. The CronJob dead-man covers a job that never starts.
- Alerts go to an email notification channel, set in stack config. platform owns the alerts because they cover every app.

### 11. Moving prod

Prod moves one project at a time, and the VM serves the rest until the last one moves.

1. **State moves**, in one sitting: each project's prod resources move from `infrastructure` into `authentik`, `crm`, `clubspot-sync`, and `gsuite-sync`. These are the generated secrets, the users, the databases (re-imported per §4), the Directus roles and users, and the DNS records. Every preview must show no changes before anything else moves.
2. **`crm`**: Directus starts in `prod` against the same database and `PUBLIC_URL`, so it keeps its activation. `directus.` moves to the Gateway. The VM's Directus stops.
3. **The syncs**: the CronJobs start in `prod` and reach Directus inside the cluster. The Cloud Run jobs and schedulers are deleted.
4. **`authentik` and `portal` together**, because the portal's `forward_auth` needs Authentik in the same namespace. Mail moves per Decision 1. `login.` and the apex move.
5. **Retire the VM**: delete `infrastructure`, `packages/substrate`, the IAP and SSH tasks (`ssh`, `logs` become `kubectl`), `substrate-runner` and its grants in `bootstrap`, and the VM's firewall rules and address. #107 and #117 close as moot. isthmia gets its `prod-preview` and `prod` jobs, and #118 closes.

### 12. Cost

Monthly, `us-west1`, Autopilot list prices. Rough requests: Authentik server 500m/1 GiB, worker 250m/768 MiB, Directus 250m/768 MiB, portal 50m/128 MiB.

| Item                                          | About  |
| --------------------------------------------- | ------ |
| Prod pods, regular                            | $40–45 |
| Dev pods, on Spot, with Mailpit and the fakes | $15–20 |
| A static Cloud NAT address                    | $3     |
| The VM, its address, and its disk, retired    | −$30   |

With platform's $30–40 from #215, the total is about $75–100 a month, within #185's $70–115.

**Try in dev before prod moves:**

- Authentik's and Directus's real requests against Autopilot's minimums
- `db-f1-micro`'s ~25 connections with Authentik, Directus, and Parse together; bump dev's tier if they don't fit
- Directus's 12-hour license check on a Spot pod that restarts
- Spot evictions mid-sync

## Alternatives

- **Secret Manager's CSI add-on, or External Secrets.** Each pod then needs Workload Identity to its secrets, and the add-on ties the workloads to Google. The values would also still have to come from somewhere for dev.
- **Keep Secret Manager as the source of generated values.** `deploy-dev` would need to create secrets, and IAM conditions on secret creation by name are fragile.
- **The Cloud SQL Auth Proxy from the runner.** The instance has no public IP, and a public IP would widen its exposure for the one job the Admin API already does.
- **A self-hosted runner in the VPC.** Something else to patch and secure.
- **Authentik's own outpost per app in place of the portal's Caddy.** It moves forward-auth into Kubernetes, but the portal is static files that still need a server. Caddy already does both.
- **The GKE Gateway's own authorization (IAP or service extensions).** It ties the portal's sign-in to Google, and IAP can't use Authentik.
- **Expose the fakes and Mailpit on the Gateway with tokens.** That adds public surface. The Clubspot fake's master key is public.
- **Fakes in an in-cluster Postgres.** The dev instance already backs up and restores, and one more database there is free.
- **Each project in its own package now.** The Pulumi code is CommonJS (#127) and shares `src/directus/`. Splitting waits for the schema change in #185's "Later".

## Steps

Each step is one PR or one maintainer action. **[maintainer]** marks what only the maintainer can do: an npm first publish, a manual Workspace step, or `pulumi state move`.

- [ ] 1. **[maintainer]** Publish `@cyc-seattle/platform` 0.1.0 by hand and add its trusted publisher (deferred from #215). **platform PR**: `release.yml`.
- [ ] 2. **platform PR**: `Workload`, `ScheduledJob`, and the `WebService` options; `sqlHost` and `gatewayAddress` in the outputs; the `prod` namespace, listeners, and certificate; the dev egress policy and the API-proxy path; the static NAT address; the job alerts (#205). In `bootstrap`: `deploy-dev`'s grants on `cyc-dev` and `dev-*` secrets, and Workload Identity for `gsuite-sync` in `prod`. Apply `bootstrap`; Actions applies the rest.
- [ ] 3. **clubspot-sdk and gsuite-sdk PRs**: publish the fakes' images to GHCR on release. The Clubspot fake gets an HTTP readiness path that waits for its seed.
- [ ] 4. **.github PR**: `deploy.yml` accepts `task: reset`. Release `v2.2.0`.
- [ ] 5. Copy the grant key into `dev-directus-license-key` (Decision 3).
- [ ] 6. **isthmia PR**: the five projects' `dev` stacks, the `each-stack` script, `db-shell`, the SDK bumps and `gsuite-sync`'s `rootUrl`, and the caller workflow's `dev` job. Deploy dev and check the "try in dev" list.
- [ ] 7. **isthmia PR**: the integration features (#172, #175, #173's current journeys) and the reset workflow.
- [ ] 8. **isthmia PR, then [maintainer]**: the prod state moves from `infrastructure` into the four projects (§11.1). Every prod preview shows no changes.
- [ ] 9. **isthmia PR**: move `crm` to `prod`.
- [ ] 10. **isthmia PR**: move the syncs to `prod`, and delete the Cloud Run jobs.
- [ ] 11. **isthmia PR, and [maintainer]** for the Workspace relay: move `authentik` and `portal` to `prod`.
- [ ] 12. **isthmia PR and platform PR**: retire the VM. Add isthmia's `prod-preview` and `prod` jobs (#118).
- [ ] 13. Update `AGENTS.md`, the READMEs, and `docs/architecture.md` in both repos. Record where this phase changed #185. Delete this draft.

## Decisions

The maintainer settled these when the plan was posted:

1. **Prod mail.** `cloud` reserves a static address for Cloud NAT (about $3 a month). The Workspace relay admits it alongside the VM's address until the VM goes. Dev's egress policy keeps dev off the relay.
2. **Prod pods run on regular capacity**, not Spot. Dev stays on Spot.
3. **Dev's Directus license** is the grant key. Dev spends one of its activations, and keeps its database so it never spends another. #172 still asks Directus about the spent activations.
