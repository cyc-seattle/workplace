# workplace

The [place](https://github.com/ungood/place) workplace for cyc-seattle: the repos to check out side by side, and shared config for work that spans them.

## Setup

Install [mise](https://mise.jdx.dev), then:

```sh
git clone git@github.com:cyc-seattle/workplace.git cyc
cd cyc
mise trust && mise run install
mise run sync
gcloud auth login
mise run kube
mise run doctor
```

`mise run sync` clones every repo in `place.toml` and fast-forwards the ones that are clean and on their default branch. It never switches branches or touches uncommitted work.

Each repo keeps its own history, CI, and releases. A change inside a repo never needs a commit here.

## The environment

The workplace's `mise.toml` applies to every checkout, since mise reads the config of each parent directory. It provides:

- `gcloud` with `gke-gcloud-auth-plugin`, and `kubectl`. `mise run install` adds the plugin to mise's gcloud.
- `timeout`, which macOS lacks, from `coreutils` through `bin/timeout`.
- gcloud's `isthmia` configuration, so one `gcloud auth login` serves every checkout. A checkout's own `mise.toml` can override it.
- `KUBECONFIG`, pointed at `.kube/config` in the workplace. It's git-ignored and holds only CYC's cluster, which `mise run kube` writes. No command under the workplace sees your default kubeconfig, or reaches another cluster.

`mise run doctor` checks the gcloud login, each checkout's ADC, that `kubectl` reaches CYC's cluster, and that no checkout has a `packages/*` directory holding only ignored files. It changes nothing, and names the fix for each failure.

## Adding a repo

Run `place add <url>`, which clones it and adds it to `place.toml`, then add its path to `.gitignore`. `mise run check` runs `place doctor`, which fails if a checkout isn't ignored.
