# Phase 6 shared contract (isthmia#231)

Workers in platform, clubspot-sdk, gsuite-sdk, .github, and isthmia code against this at the same
time. **Extend it; never rename or change a name here.** If something here is wrong or can't work,
stop and report it to the orchestrator instead of diverging.

## `@cyc-seattle/platform` (platform repo, `src/`, CommonJS)

Released by semantic-release from platform's `main`. 0.1.0 is the hand-published baseline (today's
`src/`). This phase's platform PR is a `feat:`, so it releases **0.2.0**. isthmia depends on
`^0.2.0`.

### `Workload(name, args, opts?)`

A Deployment, a ServiceAccount, and a ClusterIP Service, all with `metadata.name: name` in
`platform.namespace`, label `app.kubernetes.io/name: name`. No route. Args:

```ts
platform: pulumi.Input<PlatformOutputs>;
provider: k8s.Provider;
image: pulumi.Input<string>;
command?: string[];
args?: string[];
ports?: { name: string; port: number }[];          // the Service exposes each at the same port number; omitted = no Service
requests: { cpu: string; memory: string };         // limits are set equal to requests
env?: pulumi.Input<k8s.types.input.core.v1.EnvVar>[];
envFrom?: pulumi.Input<k8s.types.input.core.v1.EnvFromSource>[];
volumes?: {
  name: string;
  mountPath: string;
  emptyDir?: { sizeLimit?: string };
  configMap?: pulumi.Input<string>;               // a ConfigMap's name
  secret?: pulumi.Input<string>;                  // a Secret's name
  subPath?: string;
  readOnly?: boolean;
}[];
readinessProbe?: k8s.types.input.core.v1.Probe;   // any handler
livenessProbe?: k8s.types.input.core.v1.Probe;
startupProbe?: k8s.types.input.core.v1.Probe;
runAsUser?: number;                                // also sets runAsGroup, as today
replicas?: number;                                 // default 1
serviceAccountAnnotations?: Record<string, string>; // e.g. iam.gke.io/gcp-service-account
```

Exposes `member` (the Workload Identity principal of its ServiceAccount), `serviceAccountName`, and
`host` (`name`, which resolves inside the namespace).

### `WebService(name, args, opts?)`

`Workload`'s args plus `hostname` and `port` (the `http` port, which the Service exposes as port 80,
as today). `readinessProbe` stays required and must be `httpGet`. Existing callers (`smoke`) keep
working unchanged. Also exposes `url`.

### `ScheduledJob(name, args, opts?)`

A CronJob named `name`, with a ServiceAccount named `name`. Args: `platform`, `provider`, `image`,
`schedule` (cron), `timeZone?` (default `America/Los_Angeles`), `command?`, `args?`, `env?`,
`envFrom?`, `requests`, `volumes?`, `runAsUser?`, `activeDeadlineSeconds?` (default 3600),
`backoffLimit?` (default 0), `serviceAccountAnnotations?`. `concurrencyPolicy: Forbid`. Exposes
`member` and `serviceAccountName`.

### All three

Spot in the `dev` namespace only. `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:
false`, capabilities drop ALL, `RuntimeDefault` seccomp, no service account token automount.

### `PlatformOutputs`

Gains two required fields; everything else is unchanged (`sqlConnectionName` is
`project:region:instance`):

- `sqlHost`: the environment's Cloud SQL private IP
- `gatewayAddress`: the shared Gateway's IPv4 address

## Environments

| Stack  | Namespace | Domain             | State bucket                    | Deploy identity |
| ------ | --------- | ------------------ | ------------------------------- | --------------- |
| `dev`  | `dev`     | `dev.cycsail.team` | `cyc-admin-scripts-pulumi-dev`  | `deploy-dev`    |
| `prod` | `prod`    | `cycsail.team`     | `cyc-admin-scripts-pulumi-prod` | `deploy-runner` |

`getPlatformOutputs()` picks by stack name. Prod listeners: `cycsail.team` and `*.cycsail.team`. Dev
listeners: unchanged. The cluster stack writes no prod DNS records; apps own theirs and point them at
`gatewayAddress`.

## Grants isthmia relies on (platform `bootstrap`)

- **Dev databases come from platform, not from isthmia's dev stacks.** Cloud SQL ignores IAM conditions on user and database calls, so `deploy-dev` holds no Cloud SQL role.
  - platform's `cloud` stack, applied as `deploy-runner` behind the prod gate, creates a database and a user, both named `<name>`, on `cyc-dev` for each entry in config `cloud:devDatabases`: `authentik`, `directus`, and `clubspot_fake`.
  - It writes each user's password to Secret Manager `dev-db-<name>-password`.
  - isthmia's dev stacks read that secret with `gcp.secretmanager.getSecretVersionAccess`, and connect to `sqlHost` as user `<name>` to database `<name>`.
  - isthmia's prod stacks keep creating their own databases and users: `deploy-runner` holds an unconditional `cloudsql.admin`.
- `deploy-dev`: `roles/secretmanager.secretAccessor`, conditioned on secret IDs that start with `dev-`.
- The KSA `gsuite-sync` in namespace `prod` may impersonate the GSA `gsuite-sync@`
  (`roles/iam.workloadIdentityUser`).
- The `dev` namespace denies egress to TCP 25, 465, and 587 outside the cluster.
- The Kubernetes API's service proxy (`/api/v1/namespaces/dev/services/<svc>:<port>/proxy/`) reaches
  `dev` Services, as `deploy-dev`.

## Fake images (public on GHCR)

The tag is the library's npm release version, without `v`, plus `latest`.

- **`ghcr.io/cyc-seattle/clubspot-fake:<version>`**:
  - Parse Server on port 1337, mounted at `/parse`. Env `PARSE_SERVER_DATABASE_URI` (required).
  - `GET /ready` on 1337 returns 200 only after the seed has finished.
  - Runs as non-root with a read-only root filesystem, given an `emptyDir` at `/tmp`.
  - Seed: admin `dockmaster@example.test` / `fake-password`, club `seedClub01`, app ID `myclubspot2017`, master key `fake-master-key-for-tests-only`.
- **`ghcr.io/cyc-seattle/workspace-fake:<version>`**:
  - Port 8080 (env `PORT`). `NEW_GROUP_DELAY_MS` is 0 in dev.
  - `GET /healthz` returns 200.
  - Runs as non-root with a read-only root filesystem.

## `cyc-seattle/.github` v2.2.0

- **`deploy.yml`**: `task` also accepts `reset`, which runs `mise run reset`.
- **`release.yml`**: optional inputs `image` (for example `ghcr.io/cyc-seattle/clubspot-fake`),
  `image-context` (default `.`), and `image-file` (default `Dockerfile`).
  - When the run released a new version, it builds `linux/amd64` and pushes `<image>:<version>` and
    `<image>:latest`.
  - The caller grants `packages: write`.

## isthmia names (dev and prod)

**Pulumi projects** live under `packages/infrastructure/src/`: `authentik`, `crm`, `portal`, `clubspot-sync`, and
`gsuite-sync`. `scripts/each-stack` applies them in that order.

**Workloads:**

| Name               | Kind               | Ports                |
| ------------------ | ------------------ | -------------------- |
| `authentik-server` | WebService         | 9000                 |
| `authentik-worker` | Workload           | none                 |
| `directus`         | WebService         | 8055                 |
| `portal`           | WebService         | 8080                 |
| `mailpit`          | Workload, dev only | SMTP 1025, HTTP 8025 |
| `clubspot-fake`    | Workload, dev only | 1337                 |
| `workspace-fake`   | Workload, dev only | 8080                 |
| `clubspot-sync`    | ScheduledJob       |                      |
| `gsuite-sync`      | ScheduledJob       |                      |

**Hostnames:** `<domain>` (portal), `login.<domain>` (Authentik), `directus.<domain>` (Directus).

**StackReference outputs** (same environment):

- `authentik` exports `directusOidcClientSecret` (secret).
- `crm` exports `clubspotSyncToken` and `gsuiteSyncToken` (secrets).

**Gating:** each project creates its cluster workloads only when its stack config has
`<project>:onCluster: true`. `Pulumi.dev.yaml` sets it now. A prod stack sets it in that project's
prod-move step. Dev-only workloads (Mailpit, the fakes) are gated on the stack being `dev`.

**Secrets:**

- Generated values are `random` resources in the owning project, written to Kubernetes Secrets.
- Hand-set values stay in Secret Manager and are read at deploy time. Dev's have the `dev-` prefix:
  `dev-directus-license-key`.

**Images** are tagged with the commit SHA. Only the dev deploy builds and pushes them.
