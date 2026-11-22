# Running the platform's containers off GKE

The maintainer asked, on 2026-11-21, whether GKE is what drives the cloud bill, and whether the containers should run on
a cheaper host, such as a single VM, giving up some availability. Self-hosted open source is preferred. One-time fees
are fine, and monthly fees should be as low as possible. This follows the cost review in
[cyc-seattle/platform#171](https://github.com/cyc-seattle/platform/issues/171) and the AWS comparison in
[2026-11-21-gcp-vs-aws.md](2026-11-21-gcp-vs-aws.md).

Prices are list prices as of 2026-11-21, from Google's price pages and third-party price listings. None is from a quote.
Check Google's calculator, or the host's own page, before buying anything.

## Decided, 2026-11-21

The maintainer's answers to the decisions at the end:

1. **Where:** a Compute Engine VM in this project.
2. **How:** Kubernetes, not Docker Compose.
3. **Postgres** moves onto the VM in step 2, with WAL-G and the new restore drill. This reverses the 2026-11-09 decision
   that Cloud SQL stays.
4. **When:** once the launch work and dev's removal have merged.
5. **Price:** on demand for the first month, then a one-year commitment.
6. **HTTPS:** Traefik and cert-manager, proving domains through Cloud DNS.
7. **OS: Talos**, which runs its own Kubernetes, in place of Debian and k3s. The next section says what that changes.
   Where the analysis below says k3s or Debian, read Talos.
8. **Deploy access:** an IAP tunnel, signing in with `deploy-runner`'s Google ID token.

## Talos in place of k3s: what changes

Talos is an OS that is only Kubernetes: no shell, no SSH, no package manager. It's managed through its own API, with a
machine config that Pulumi writes. It runs upstream Kubernetes, with etcd and the control plane on the one node, which
also runs the apps. The apps' Kubernetes code doesn't change: `WebService`, `Workload` and `ScheduledJob` write the
same objects, and only `src/` and `infra` learn about the new cluster.

| Part                       | With k3s on Debian                                    | With Talos                                                                                                                                                                                                                                                                                                                                                                                         |
| -------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| In code                    | A boot script that installs k3s                       | The `@pulumiverse/talos` provider makes the cluster's keys, writes the machine config, applies it, starts etcd, and reads back the cluster's address. The keys live in `infra`'s state, encrypted by KMS.                                                                                                                                                                                          |
| The VM's image             | Google's Debian image                                 | Talos's GCP image, from Sidero's Image Factory, copied into a Cloud Storage bucket and made a Compute Engine image in `infra`.                                                                                                                                                                                                                                                                     |
| First boot                 | The boot script runs                                  | Talos waits for its config on its API port, unauthenticated, until it gets one. Only IAP can reach that port, and Pulumi applies the config through a tunnel right after the VM starts. The config isn't put in instance metadata, which anyone who can read the project's VMs could read, because it holds the cluster's keys.                                                                    |
| Ingress                    | Traefik ships with k3s                                | Traefik is installed from its Helm chart, with the Gateway API's CRDs. It listens on the node's ports 80 and 443 directly, in a namespace allowed to. No Service of type `LoadBalancer`, and no Google cloud controller, so nothing can create a paid load balancer.                                                                                                                               |
| Network policies           | k3s enforces them                                     | Talos's default network (Flannel) ignores them, so `infra`'s namespace policies would silently do nothing. Cilium replaces it, as Talos documents, and also blocks pods from Google's metadata address.                                                                                                                                                                                            |
| Certificates               | cert-manager, DNS-01 through Cloud DNS                | The same. cert-manager reaches Cloud DNS as its own Workload Identity, with a credential file that trades its Kubernetes token for a Google one.                                                                                                                                                                                                                                                   |
| Disks                      | k3s's local-path storage                              | Talos mounts the data disk as a user volume, and Rancher's local-path provisioner serves volumes from it: Postgres, FreeScout's files. etcd and images stay on the boot disk.                                                                                                                                                                                                                      |
| OS and Kubernetes upgrades | `unattended-upgrades` and `system-upgrade-controller` | The Talos and Kubernetes versions are pinned in `infra`. Renovate opens a PR for each new release. A scheduled workflow applies what's merged, Sundays at 3:00 Pacific: `talosctl upgrade` writes the new OS to the spare slot and reboots, and boots the old one again if the new one fails (2 to 4 minutes down); `talosctl upgrade-k8s` restarts the control plane while the apps keep serving. |
| Deploy access              | IAP to the Kubernetes port                            | The same, plus Talos's API port (50000) for `infra`'s deploys only. Both ports' certificates list `127.0.0.1`, the tunnel's end. The API server trusts Google ID tokens (`--oidc-issuer-url=https://accounts.google.com`, username from `email`), and RBAC names `deploy-runner` and the maintainer. Talos's API takes a client certificate from `infra`'s state.                                  |
| Logs                       | Google's Ops Agent                                    | The Ops Agent can't be installed on Talos. A Fluent Bit DaemonSet sends container logs to Cloud Logging as its own Workload Identity, and Talos sends its own logs to it.                                                                                                                                                                                                                          |
| Pulling images             | Google's image credential plugin                      | A CronJob refreshes an image pull secret every 30 minutes, as an identity that may only read Artifact Registry.                                                                                                                                                                                                                                                                                    |
| Memory for itself          | about 0.7 GB                                          | about 1.5 to 2 GB: etcd, the control plane, and Cilium. That leaves about 1.5 GB spare on 8 GB once Postgres moves in. If deploys run short, the requests come down (nothing bills them now), or the VM becomes a custom E2 with 12 GB, about $11 a month more on the commitment.                                                                                                                  |
| Disk encryption            | Google's                                              | Google's, and Talos encrypts its own partitions with the VM's virtual TPM.                                                                                                                                                                                                                                                                                                                         |
| Rebuilding the VM          | From the boot script, with the data disk kept         | From the daily snapshot of the boot disk, which holds etcd. Or a new cluster, which Pulumi deploys again; the federation provider then reads the new cluster's keys.                                                                                                                                                                                                                               |
| Cost                       |                                                       | The same. Talos is open source, and Sidero's paid Omni service isn't used.                                                                                                                                                                                                                                                                                                                         |

## Recommendation

Move, but after the Dec 23 launch, and in two steps:

1. **Step 1, in January:** one Compute Engine VM in this project (`e2-standard-2`, 2 vCPU and 8 GB) runs k3s, a small
   Kubernetes. Every app moves onto it, one at a time. Cloud SQL, Cloud Storage, Cloud DNS, Secret Manager, the uptime
   checks and the backups project stay. The Gateway's load balancer and Cloud NAT go. Directus keeps its database and
   its address, so its license is as safe as it was in the October move onto GKE.
2. **Step 2, once step 1 has run for a month:** Postgres moves onto the VM too, with continuous backups to Cloud
   Storage, and Cloud SQL goes. This reverses the 2026-11-09 decision that Cloud SQL stays, so it's a decision of its
   own.

That takes the bill from about $98 to $114 a month (GKE, once dev is gone) to about **$49 a month** with a one-year
commitment on the VM, or $67 without one. Step 1 alone gets to about $75.

k3s, not Docker Compose, because the apps keep their Kubernetes code: `WebService`, `Workload` and `ScheduledJob`
stay, sail-team's stack doesn't change, and the syncs stay CronJobs. Compose would rewrite all of it, and would bring
back the root SSH deploys that the October move onto GKE got rid of.

Don't move to Hetzner or another rented server. In the US, Hetzner now costs more than a Google VM with a commitment,
and the cheap hosts that are left trade away live migration, private deploys (IAP), and Workload Identity, and add a
new processor for minors' medical data.

If the maintainer would rather not run a VM at all, staying on GKE is reasonable: about $85 to $90 a month once pods are
right-sized and Autopilot has a commitment. The VM saves about $40 more a month, roughly $500 a year, and costs about
three weeks of work and a monthly few minutes of planned downtime.

## Is GKE the cost driver?

Partly. GKE's cluster fee is $0: Google's free credit covers one Autopilot cluster. What costs money is what comes with
it. Once dev is gone ([cyc-seattle/platform#171](https://github.com/cyc-seattle/platform/issues/171), decision 3):

| What                                                           | $/month               | Because of GKE?                                       |
| -------------------------------------------------------------- | --------------------- | ----------------------------------------------------- |
| Prod pods (billed by what each pod asks for, not what it uses) | 57, or 41 right-sized | Yes. The same pods fit on a $31 to $49 VM.            |
| Gateway load balancer                                          | 18                    | Yes. A VM serves HTTPS itself.                        |
| Cloud NAT and its address                                      | 7                     | Yes. The nodes are private; a VM has its own address. |
| Cloud SQL, prod                                                | 28                    | No. Postgres on the VM removes it (step 2).           |
| Secret Manager, DNS, images, files, keys                       | 4.50                  | No                                                    |
| **Total**                                                      | **98 to 114**         |                                                       |

So about $66 to $82 of it is the cluster's way of running things, and $28 is the managed database.

The pods' real use is far below what they ask for. Authentik's server asks for 500m of CPU and used about 77m in dev.
Autopilot bills the request. A VM bills its size, however full it is, so many small apps pack better on one machine.

## What runs today

Prod, from the stacks:

| App                                                | Asks for (CPU, memory)     | State                                           |
| -------------------------------------------------- | -------------------------- | ----------------------------------------------- |
| Directus                                           | 500m, 768 MiB              | Cloud SQL `directus`; files in Cloud Storage    |
| Authentik server and worker                        | 500m, 1 GiB; 100m, 512 MiB | Cloud SQL `authentik`                           |
| FreeScout                                          | 100m, 512 MiB              | Cloud SQL `inbox`; a 10 GB disk                 |
| Listmonk                                           | 50m, 128 MiB               | Cloud SQL `listmonk`; pictures in Cloud Storage |
| sail-team, 2 copies                                | 50m, 64 MiB each           | none                                            |
| clubspot-sync, gsuite-sync (hourly, a few minutes) | 250m, 512 MiB each         | none                                            |

That's about 1.5 vCPU and 3.6 GB asked for, and much less used. With Postgres (about 1 GB) and k3s itself (about
0.7 GB), it fits in 8 GB with room for a deploy to start each new copy before the old one stops. 4 GB
(`e2-medium`) doesn't fit.

Outside the cluster, and staying wherever the containers go: the website on Firebase Hosting, Cloud DNS, Secret Manager
for the hand-set secrets, the `csc-backups` project, the uptime checks, Workload Identity Federation for Actions, and
Amazon SES.

## The options

### A: a VM in this project, Cloud SQL stays

One `e2-standard-2` in `us-west1`, in the existing VPC, so it reaches Cloud SQL's private address as the pods do now.

| Item                                               | $/month, on demand | 1-year commitment | 3-year commitment |
| -------------------------------------------------- | ------------------ | ----------------- | ----------------- |
| `e2-standard-2` (2 vCPU, 8 GB)                     | 48.92              | 30.82             | 22.01             |
| Boot disk, 20 GB balanced                          | 2.00               | 2.00              | 2.00              |
| Data disk, 30 GB balanced (k3s, FreeScout's files) | 3.00               | 3.00              | 3.00              |
| Daily disk snapshots, 14 kept                      | 1.00               | 1.00              | 1.00              |
| Static address, in use                             | 3.65               | 3.65              | 3.65              |
| Cloud SQL, prod (`db-g1-small`)                    | 28.00              | 28.00             | 28.00             |
| Secret Manager                                     | 1.50               | 1.50              | 1.50              |
| DNS, images, files, backups, keys                  | 3.00               | 3.00              | 3.00              |
| Traffic out, logs, a few VM metrics                | 2.00               | 2.00              | 2.00              |
| **Total**                                          | **about 93**       | **about 75**      | **about 66**      |

A commitment is for an amount of vCPU and memory in the region, not for this VM, and is billed monthly for its term.
It can't be cancelled. A Spot VM is about $24, but Google can stop it at any time with 30 seconds' notice, and may not
start it again for a while. Fine for dev, not for prod.

### B: the same VM, Postgres on it

As A, without Cloud SQL, with a 50 GB data disk and a little more backup storage.

| Item                                              | $/month, on demand | 1-year       | 3-year       |
| ------------------------------------------------- | ------------------ | ------------ | ------------ |
| `e2-standard-2`                                   | 48.92              | 30.82        | 22.01        |
| Boot disk, 20 GB; data disk, 50 GB; snapshots     | 8.00               | 8.00         | 8.00         |
| Static address                                    | 3.65               | 3.65         | 3.65         |
| Continuous database backups in Cloud Storage      | 0.20               | 0.20         | 0.20         |
| Secret Manager, DNS, images, files, backups, keys | 4.50               | 4.50         | 4.50         |
| Traffic out, logs, a few VM metrics               | 2.00               | 2.00         | 2.00         |
| **Total**                                         | **about 67**       | **about 49** | **about 40** |

### C: a rented server, everything on it

The 2026-11-21 AWS research guessed $25 to $50 for a rented server. Hetzner raised prices in April and June 2026, and
its cheap plans are sold only in Europe:

| Host, US region, 4 vCPU and 8 GB    | Server                              | With backups and the GCP parts that stay |
| ----------------------------------- | ----------------------------------- | ---------------------------------------- |
| Hetzner CPX31, Hillsboro or Ashburn | about $73.50                        | about $92                                |
| DigitalOcean Basic, San Francisco   | $48                                 | about $61                                |
| Vultr, Seattle                      | $40 to $48                          | about $50 to $60                         |
| OVHcloud VPS, Hillsboro             | about $7 to $15 (listings disagree) | about $15 to $25                         |
| Hetzner in Germany, for comparison  | about $10 to $15                    | about $15 to $20, 150 ms from Seattle    |

Only OVHcloud is clearly cheaper than option B. What it gives up:

- **No live migration.** Google moves a VM to another machine for maintenance without stopping it. A VPS host reboots
  it, at a time the host picks.
- **No private way in for deploys.** On Google, Actions reaches the VM through IAP, with the deploy's Google identity
  and no open port. Elsewhere it's an open Kubernetes port, a WireGuard key, or Tailscale (a SaaS, free tier).
- **No Workload Identity.** Directus's files and gsuite-sync's Workspace access need a Google identity. Off Google, the
  cluster's own tokens can still be trusted through Workload Identity Federation, but it's more to set up.
- **A new processor for minors' medical data**, with its own terms to read before the move, not after.
- **Support.** OVHcloud's VPS line is cheap because support is thin.

The parts that stay on Google (DNS, Secret Manager, backups, the uptime checks, Firebase) cost about $5 either way.

### D: GKE Standard with one node

Considered, not recommended. A zonal GKE Standard cluster is also covered by the free credit, and one `e2-standard-2`
node costs what the VM does. It keeps Workload Identity, GKE's log format (so the alerts don't change), and Google's
node upgrades. But without a load balancer, the public address has to sit on the node itself, and GKE replaces the node
at every upgrade, about monthly, with a new address. Keeping a fixed address needs `kubeip`, a small third-party
controller. GKE also holds back about 2 GB of the node's 8 GB for itself, which leaves no room for Postgres and a
rolling deploy together.

### Stay on GKE, tightened

Right-size Directus and Authentik's server (#171 kept them at 500m, so Autopilot won't move them), and buy a one-year
commitment on Autopilot's pods, about 20% off. About $85 to $90 a month. Nothing else changes.

## Docker Compose or k3s

The same question in every option, with the same answer.

|                          | Docker Compose                                                                  | k3s                                                                           |
| ------------------------ | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| App code                 | Every stack rewritten, and `@cyc-seattle/platform`'s contract with it           | `WebService`, `Workload`, `ScheduledJob` stay; sail-team's stack is unchanged |
| Deploys from Actions     | SSH as a user who can run Docker, which is root in effect, or a pull agent      | The Kubernetes API through an IAP tunnel, as the deploy's Google identity     |
| Deploys without downtime | Needs an add-on such as `docker-rollout`                                        | Built in: the new copy starts and passes its check before the old one stops   |
| Scheduled syncs          | cron or a scheduler container; no failed-run alerts                             | CronJobs, as now                                                              |
| Secrets                  | An env file on the disk                                                         | Kubernetes Secrets that Pulumi writes, as now, encrypted on disk              |
| Memory for itself        | about 100 MB                                                                    | about 700 MB                                                                  |
| What we've tried         | The substrate VM, until October 2026, which deployed from laptops over root SSH | Integration tests in CI could use the same k3s                                |

Compose is simpler to read on the box, but every advantage is something we already moved away from once. Coolify,
Dokku and Kamal, which add a deploy tool on top, were not looked at closely: each adds a hand-configured layer that the
code doesn't describe.

## HTTPS and the front door

- **Traefik**, which ships with k3s, takes the `HTTPRoute`s that `WebService` already writes. The Gateway's class
  changes from Google's to Traefik's. Google's `HealthCheckPolicy` has no equivalent and isn't needed: Traefik routes
  only to copies that pass their readiness check.
- **cert-manager** gets Let's Encrypt certificates, proving each domain through Cloud DNS (the DNS-01 challenge) with
  its own Google identity. That gets a certificate before a hostname's record moves to the VM, so no address is ever
  served without one, and it covers the wildcards as now.
- **Caddy** was looked at. It's simpler on its own, but it doesn't read `HTTPRoute`s, so routes would move out of the
  apps' stacks into one shared file.
- **Google's load balancer in front of the VM** keeps Google-managed certificates, for the same $18. Not worth it.
- The VM's static address serves HTTPS in and also sends mail out, so the Workspace SMTP relay admits it. Cloud NAT
  goes.
- Only ports 80 and 443 are open. SSH and the Kubernetes API answer only through IAP.

## What downtime looks like

Today, Directus and Authentik's server already run one copy each, and Cloud SQL is in one zone, so the platform is
already not highly available. What changes:

| Event                              | GKE today                                          | VM (A or B)                                                                                              | Rented server (C)                          |
| ---------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| App deploy                         | No downtime: the new copy starts first             | The same                                                                                                 | The same                                   |
| Google's or the host's maintenance | Autopilot moves pods: about a minute, now and then | None: Google live-migrates the VM                                                                        | A reboot when the host says, a few minutes |
| OS security updates                | Google's, invisible                                | A reboot when one needs it, Sundays at 3:00, about 3 minutes                                             | The same                                   |
| k3s upgrade                        | Google's                                           | About a minute per app, in the same window                                                               | The same                                   |
| The machine fails                  | Pods move: a few minutes                           | Google restarts the VM on another machine, disks kept: about 5 minutes                                   | Hours, or a restore from backups           |
| The zone fails                     | Down until Cloud SQL's zone is back                | The same. Or rebuild in another zone from snapshots, about an hour, by hand                              | The same, if the host has another site     |
| Database maintenance               | Cloud SQL's window, a minute or two                | B: Postgres updates in the Sunday window, seconds; a major version every few years, a planned 15 minutes | The same as B                              |

Keeping deploys near zero downtime on one machine needs only what the apps already have: readiness checks, and
memory spare for one extra copy at a time. FreeScout stops before it starts, because of its disk, as it does now.

## Patching and disks

- **OS:** Debian 13 or Ubuntu 24.04, with `unattended-upgrades` installing security updates daily and rebooting in the
  Sunday 3:00 window only when one needs it. Shielded VM, OS Login, no SSH keys.
- **k3s:** pinned in code. Rancher's `system-upgrade-controller` follows k3s's stable channel in the same window, as
  GKE's release channel does now. Or bump the pin in a PR.
- **Disks:** the boot disk holds nothing that matters. A separate data disk holds k3s's state, Postgres (B), and
  FreeScout's files, so the VM can be rebuilt from code and the disk attached again. Daily snapshots, 14 kept. The disk
  grows online when it's near full; an alert at 80% says when.
- **Alerts:** the uptime checks and the backup absence alerts keep working. The failed-Job alerts read GKE's log format,
  so they're rewritten for the VM's logs, which Google's Ops Agent sends to Cloud Logging.

NixOS (a VM whose whole setup is one file, with rollback) or Talos (an OS that is only Kubernetes) would fit "everything
rebuildable from git" even better, but fewer people, and fewer agents, know them. Debian is the boring choice.

## Keeping it in code

Pulumi, as now:

- **`infra`:** the VM, its data disk and snapshot schedule, the static address, the firewall, and a boot script that
  installs a pinned k3s, Traefik and cert-manager. The cluster's outputs in `platform/outputs.json` point at the VM
  instead of GKE. Later, the GKE cluster, the Gateway, its certificates and address, and Cloud NAT are deleted.
- **`bootstrap`** (applied by the maintainer): the VM's own service account, which may only pull images and write logs;
  `deploy-runner`'s right to open an IAP tunnel to the VM; and a Workload Identity Federation provider that trusts the
  k3s cluster's service-account tokens, so Directus and gsuite-sync keep their own Google identities.
- **`src/`:** `WebService` takes the Gateway's class from the outputs and leaves out `HealthCheckPolicy` off GKE.
  `workloadMember` builds the new pool's principal. `appDatabase` creates databases through Postgres itself in step 2,
  since the Cloud SQL Admin API goes with Cloud SQL. A `feat:`, with no change to what the apps write.
- **Pods can't borrow the VM's identity:** a network policy blocks them from Google's metadata address, so only their own
  Workload Identity reaches Google.

## How CI deploys

The workflow logs in to Google as now. It then opens an IAP tunnel to the VM's Kubernetes port, and the Kubernetes
provider signs in with a Google ID token for `deploy-runner`, which k3s trusts. No key is stored anywhere, and no port
is open to the internet. `deploy.yml` adds one step to open the tunnel. Preview, deploy and the integration tests run
as now.

Images: k3s pulls from Artifact Registry with the VM's identity, through Google's image credential plugin.

## Backups and the restore drill

Step 1 changes nothing: Cloud SQL's backups and the twice-daily copies to `csc-backups` go on.

Step 2 replaces what Cloud SQL did:

| What                                   | Today (Cloud SQL)                   | Step 2 (Postgres on the VM)                                                                                                |
| -------------------------------------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Restore to any minute in the last week | Cloud SQL's point-in-time recovery  | WAL-G (open source) streams Postgres's changes to a bucket, with a nightly full backup, 7 days kept                        |
| Twice-daily copies to `csc-backups`    | A Workflow asks Cloud SQL to export | A CronJob runs `pg_dump` and uploads, with the same names, retention and absence alerts. It may only create copies, as now |
| Whole-disk backup                      | none                                | Daily snapshots, 14 days                                                                                                   |
| Restore drill                          | A throwaway Cloud SQL instance      | The copy loads into Postgres on the drill-runner's own machine: no instance, quicker, free                                 |

The quarterly drill adds one check: restore WAL-G's backup to a chosen minute, and check the newest row is from just
before it.

## What staff see

Nothing, after the move. The addresses, sign-in and data are the same. During it:

- Step 1: each app is down for about 5 minutes when it moves, one evening each, announced the day before.
- Step 2: everything is down for about an hour, one evening, while the databases copy.
- After: up to 3 minutes some Sunday nights at 3:00, when an update needs a reboot.

## Directus's license

An activation is bound to the key, the database's `project_id`, and `PUBLIC_URL`
([docs/backend.md](https://cyc-seattle.github.io/platform/backend/)).

- **Step 1** keeps the same database and URL. It's the same move as October's, from the substrate VM onto GKE, and
  spends nothing.
- **Step 2** copies the database with `pg_dump`. `project_id` is a row in `directus_settings`, so it comes along, and
  Directus refreshes its license instead of activating. Two rules keep it that way: Directus never starts on the new
  Postgres before the copy is loaded (an empty database with the key set activates), and the old and new never both
  run. If the refresh fails with `BINDING_MISMATCH` anyway, the stored license has 30 days' grace while we ask.
- **Option C** is the same as step 2, at a new host.

The maintainer approves the start of step 2, per the license rule.

## How to move

### Before

1. The Dec 23 launch is done, and nothing in the launch is being built on the stacks.
2. Dev is gone ([cyc-seattle/platform#171](https://github.com/cyc-seattle/platform/issues/171), decision 3), so only
   prod moves. If dev outlives the launch, it moves later as its own namespace on a Spot VM.

### Step 1: the containers

1. **platform PR**: the `src/` changes above, released as a `feat:`. sail-team bumps it.
2. **platform PR, then the maintainer applies `bootstrap`**: the VM's identity, the IAP grant, and the federation
   provider.
3. **platform PR**: `infra` makes the VM with k3s, Traefik and cert-manager, and issues the certificates. Nothing moves
   yet.
4. **By hand**: the maintainer adds the VM's address to the Workspace SMTP relay (below), and lowers the records' TTL to
   60 seconds a day ahead.
5. **One PR per app**, in this order: sail-team, Listmonk, FreeScout (its 10 GB disk copied across), Authentik, then
   `backend` (Directus and the syncs). Each points the stack at the VM. Pulumi makes the app on the VM, moves its DNS
   record, and deletes it from GKE, in one deploy. To undo one, revert the PR.
6. **platform PR**: delete the GKE cluster, the Gateway, its certificates and address, and Cloud NAT. Each is protected
   now, so the PR lifts that first, and the maintainer approves.
7. **After a month without trouble:** buy the one-year commitment.

### Step 2: the database

1. **platform PR**: Postgres on the VM, WAL-G, the backup CronJob, and the new drill. Run the drill against a test load.
2. **platform PR, applied by the maintainer**: `bootstrap`'s backup Workflow and grants change from Cloud SQL's export
   to the CronJob's.
3. **One evening:** stop every app; copy each database from Cloud SQL with `pg_dump`; load it into the VM's Postgres;
   point the apps at it (one output); start them. Check Directus's license reads `active`.
4. Cloud SQL stays stopped for 2 weeks, costing only its disk, so the copy can be redone. Then one last export to
   `csc-backups`, and the maintainer deletes it.

About two weeks of agent work for step 1 and one for step 2, with the maintainer applying `bootstrap` and approving each
prod change.

## What a person does by hand

- **Workspace SMTP relay:** in the Google Admin console, Apps → Google Workspace → Gmail → Routing → SMTP relay service,
  add the VM's static address to the allowed IP addresses, before Authentik or FreeScout moves. Remove Cloud NAT's
  address after step 1.
- **Apply `bootstrap`** twice, as above.
- **The commitment:** in the Cloud console, Compute Engine → Committed use discounts → Purchase, `us-west1`, general
  purpose E2, 2 vCPU and 8 GB, one year.
- **Approve** each prod deploy, the deletion of the GKE resources, and the start of step 2.

## Risks

- **One machine.** Everything is on one VM. A bad OS update or a full disk takes every app down at once. Mitigated by
  the Sunday window, the disk alert, the snapshots, and a VM that's rebuilt from code.
- **The database is ours to run (step 2).** A backup we haven't restored is a hope. The drill restores both kinds each
  quarter. The architecture doc kept Cloud SQL for exactly this reason; step 2 is a bet that WAL-G, snapshots and the
  drill are enough at this size.
- **Patching is ours.** Automated, but it needs someone to read the alert when an update or a k3s upgrade fails.
- **The pods' identity.** If the metadata block is wrong, every pod gets the VM's identity. The VM's identity can do
  little, and a unit test checks the policy.
- **Timing.** Doing this before Dec 23 would collide with five workers changing the same stacks. It waits.
- **Overlap with other work:** the backups worker ([cyc-seattle/platform#170](https://github.com/cyc-seattle/platform/issues/170))
  owns `backups.ts` and the drill, and the CI-tests worker owns dev's removal. Step 2 changes the first; both should
  land before this starts.

## Decisions

1. **Where the containers run.** Recommended: a Compute Engine VM in this project, running k3s (options A then B).
   Alternatives: stay on GKE, tightened (about $85 to $90, no work beyond right-sizing); GKE Standard with one node
   (option D); a rented server at OVHcloud or another host (option C).
2. **k3s or Docker Compose.** Recommended: k3s, which keeps the apps' Kubernetes code and Actions' keyless deploys.
   Alternative: Docker Compose, with a rewrite of every stack and of `@cyc-seattle/platform`.
3. **Postgres.** Recommended: move it onto the VM in step 2, a month after step 1, with WAL-G and the new drill. This
   reverses the 2026-11-09 decision. Alternative: keep Cloud SQL (option A only), for $28 a month more.
4. **When.** Recommended: start in January, after the launch and after dev is gone. Alternative: start now, alongside
   the launch work.
5. **The VM's size and price.** Recommended: `e2-standard-2` on demand for the first month, then a one-year commitment
   (about $49 a month all-in with step 2). Alternatives: a three-year commitment (about $40); stay on demand (about
   $67); Spot (about $24 for the VM, with random stops).
6. **HTTPS.** Recommended: Traefik, which ships with k3s, with cert-manager proving domains through Cloud DNS.
   Alternatives: Caddy, with routes in one shared file; Google's load balancer in front of the VM, for $18 a month.
7. **OS.** Recommended: Debian 13 with automatic security updates and a Sunday 3:00 reboot window. Alternatives: Ubuntu
   24.04; NixOS; Talos.
8. **Deploy access.** Recommended: an IAP tunnel to the Kubernetes port, signing in with `deploy-runner`'s Google ID
   token. Alternative: the same tunnel with a k3s client certificate kept in Secret Manager.

## Sources

- [Compute Engine pricing](https://cloud.google.com/compute/all-pricing), and per-machine listings for `e2-standard-2`
  at [economize.cloud](https://www.economize.cloud/resources/gcp/pricing/compute-engine/e2-standard-2/) and
  [devzero.io](https://www.devzero.io/instances/gcp/e2-standard-2)
- [Cloud Load Balancing pricing](https://cloud.google.com/load-balancing/pricing),
  [Cloud Storage pricing](https://cloud.google.com/storage/pricing)
- Hetzner's 2026 prices: [devshot.co](https://devshot.co/blog/hetzner-cloud-pricing),
  [bestusavps.com](https://bestusavps.com/reviews/hetzner/), [bitdoze.com](https://www.bitdoze.com/hetzner-cloud-review/)
- Other hosts: [getdeploying.com](https://getdeploying.com/reference/compute-prices),
  [comparevps.com](https://www.comparevps.com/hosting/digitalocean), [vpsbuyer.com](https://vpsbuyer.com/ovhcloud/)
- [cyc-seattle/platform#171](https://github.com/cyc-seattle/platform/issues/171) for today's costs and pod sizes;
  [cyc-seattle/isthmia#172](https://github.com/cyc-seattle/isthmia/issues/172) for the license history;
  [2026-10-14-phase-6-apps-on-gke.md](2026-10-14-phase-6-apps-on-gke.md) for the substrate VM
