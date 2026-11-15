# Testing and deploys: safety without the wait

Started 2026-11-14, from a conversation about letting contributors push branches without being able to
merge.

## How it started

The goal was a `contributors` team that can push branches and open PRs but can't merge
([cyc-seattle/platform#270](https://github.com/cyc-seattle/platform/pull/270)). GitHub has no role for
that on any plan: merging is writing to `main`, and Write can write to every branch. Custom
repository roles (Enterprise Cloud, about $21 per user per month at list price) only add permissions
to a base role, so they can't take merging away from Write.

The usual tool is a `main` ruleset with "restrict updates", where only maintainers are allowed past.
Tested on platform:

- With nobody allowed past the rule, a PR couldn't enter the merge queue. That's what we want for
  contributors.
- With `maintainers` allowed past it, the PR still couldn't enter the queue. The queue only checks
  whether a PR meets the rules, not who queued it, and no PR can meet "restrict updates". Community
  reports say the same about required approvals. GitHub's merge queue app can't be added to the
  bypass list, and if it could, anyone with Write could merge by queueing.

So "only maintainers merge" and the merge queue don't work together.

## Why the queue is there

The queue was added so slow integration tests stopped blocking merges (cyc-seattle/platform#80,
cyc-seattle/platform#161). Batches still took 17–23 minutes, and PRs backed up 30–45 minutes behind
them. On 2026-11-14 the integration tests left the queue and moved to a nightly run
(cyc-seattle/platform#268, cyc-seattle/platform#269). Batches have taken 2–6 minutes since. All the
queue does now is deploy to dev before a PR merges.

## What can break, and where to catch it

| Change                            | What goes wrong               | Where to catch it                                             |
| --------------------------------- | ----------------------------- | ------------------------------------------------------------- |
| App and engine logic              | Wrong numbers, broken screens | On the PR: unit tests, and later the planning rules in memory |
| Schema and migrations             | Failed apply, lost data       | On the PR in PGlite, then on dev before prod                  |
| Pulumi infra                      | Broken resources or access    | `pulumi preview`                                              |
| Syncs, sign-in, licensed features | Real systems, timing          | On dev, after each deploy                                     |

A throwaway Directus on each PR would put the integration features back before merge, but
unlicensed Directus caps the number of collections, and the schema is past it.

## The plan

1. **No merge queue.** A PR merges once CI passes. Only maintainers merge, through "restrict updates"
   on every repo, and contributors push branches.
2. **`main` deploys to dev after each merge,** then previews prod and waits for a maintainer's
   approval, as now.
3. **Integration tests run after each dev deploy, and only then.** One run at a time and at most one
   waiting, and a newer waiting run replaces an older one. While a run is going, any number of merges
   collapse into one next run of the newest `main`. A failure is found one or two runs after its merge,
   and the issue lists the PRs merged since the last green run.
4. **Deploys go ahead of a waiting test run,** so prod never waits behind 15 minutes of tests. A test
   run tests whatever is newest when it gets dev.
5. **The nightly run stays** as a backstop that tests both repos together.
6. **Dev takes only `main`.** Today any branch can deploy to dev, so anyone with push could run a
   changed workflow with dev's credentials. Nobody tries a branch on dev before merging anymore.

Later: run the planning features against the planning engine in memory on each PR. `src/planning`
already loads without Pulumi or Directus, and the planning features are the slowest file.

## The cost

A broken deploy can land on `main`. It stops on dev before prod, but it blocks prod until a fix merges
on top of it. A schema change that fails on dev is the expensive case, and PGlite catches most of
those on the PR.
