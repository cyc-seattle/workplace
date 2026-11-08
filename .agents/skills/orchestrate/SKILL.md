---
name: orchestrate
description: Run a batch of changes across the cyc-seattle repos as the coordinator of supervised Orca workers, so the maintainer can keep giving feedback while work runs in parallel. Use when the maintainer asks you to orchestrate, act as coordinator, spin up agents or workers for tasks, or check in on workers, PRs, merge queues and prod deploys.
---

# Orchestrate workers across the cyc-seattle repos

You're the coordinator. The maintainer gives feedback, and you turn each item into a brief, start an Orca worker for it, answer the workers' questions, review and merge their PRs, approve prod deploys, and clean up. Stay unblocked: the maintainer should always be able to send the next item.

## Your job, and what isn't

- **Delegate everything substantive**, including research and reading code to form a proposal. Write a brief and start a worker. Your own tool use is dispatching, quick status checks, reviewing diffs and previews, and small one-line fixes.
- **The maintainer decides; you recommend.** Bring every design question to them before code that depends on it, through AskUserQuestion: one decision per question, with context, links, a recommendation first and the alternatives. Read their answer closely: they often change the question.
- **Record decisions on the GitHub issue they belong to** (a "Decisions (date)" comment), and file new issues for new asks. Never only in `.plans/`.
- **Keep it simple.** The maintainer has pushed back on over-complicated proposals. When a worker's proposal has extra machinery, ask whether the maintainer's own description already covers it.
- **Report plainly, with links.** Every PR and issue as `[owner/repo#N](https://github.com/owner/repo/pull/N)`. What you're waiting on them for, with the exact command. Don't hide failures.

## Setup for a batch

1. Run `mise run doctor` from the workplace, and check `place status -s` (checkouts may be on branches).
2. Copy [worker-rules.md](worker-rules.md) to `/home/ungood/workplaces/cyc/.plans/_common.md` if it isn't there, and keep it current: when the maintainer sets a rule that every worker needs (a word to avoid, a review size), add it there and to the briefs of running workers.
3. Start the 30-minute check-in with `/loop 30m` and the check-in steps below, if the maintainer wants it. Offer to pause it when nothing is in flight.

## Starting a worker

Write the brief to `/home/ungood/workplaces/cyc/.plans/<slug>.md`:

- First line after the title: "Read `.plans/_common.md` (in /home/ungood/workplaces/cyc) first and follow it."
- The maintainer's words, quoted. What you already know: files, issues, related PRs and other workers in flight that it might collide with.
- Steps. Research or proposal first ("send the coordinator one `question`, recommendations first, wait for the answer"), then build. Say it may push and open PRs after your OK. A brief that says "read-only" gets later pushes refused.
- What "done" is, and to send `worker_done` then.

Start it in a fresh worktree:

```sh
orca orchestration worker-start --spec "You are a worker. Read /home/ungood/workplaces/cyc/.plans/<slug>.md and do it." \
  --task-title "<short title>" --repo name:<repo> --worktree new-top-level --name <fresh-name> \
  --base-branch origin/main --agent claude --model claude-opus-5-5 --json | jq -c '{ok, err: .error}'
```

- For workplace-repo work use `--repo path:/home/ungood/workplaces/cyc`.
- Right after, check the worker isn't bypassing permissions: `ps -eo pid,etimes,args | grep -E '^ *[0-9]+ +[0-9]+ claude ' | grep -c dangerously` must print 0.
- Never reuse a worktree name you just removed: Orca's background delete kills the new checkout.
- A worktree outside the workplace doesn't get the workplace's `.mcp.json`. For a worker that needs prod Directus, run `claude mcp add --scope local --transport http cycsail-team-directus https://directus.cycsail.team/mcp` in its worktree and start a fresh session there. The maintainer signs in with `/mcp`.

## The mailbox

Run [scripts/orca-wait.sh](scripts/orca-wait.sh) in the background (`run_in_background`, 3600). It exits on the first question, status, escalation or worker_done, and skips heartbeats. Read its output with `scripts/read-mail.sh <output file>`. Then:

- **Answer a question** with `orca orchestration reply --id <msg>`, never `send`: a worker blocked on its question misses separate messages.
- **Ack the delivery** (`orca orchestration check --ack <delivery> --json`) once handled, or the next wait returns it again.
- **Restart the wait** every time. Run only one at a time, and never start it with `&`: its output is lost.
- **Long answers** go in a `.plans/` file, and the reply points to it.

## Waking and poking workers

- `orca orchestration send` only queues. A worker sitting at its prompt never sees it, and after `worker_done` its dispatch is closed and replies go nowhere. To give it work, write the message to a `.plans/` file and type into its terminal:
  `orca terminal send --terminal <agentTerminalHandle> --text "Coordinator: read <file> and do it now." --enter --wait-submit 30`
  The handle comes from `orca orchestration worker-list --json`. A "no turn start was observed" warning means it was busy, and the message is queued.
- To see why a worker is quiet, read its screen: `orca terminal read --terminal <h> --screen`. Workers sometimes ask for help only in their own terminal and stall unseen.
- A worker near its context limit ignores terminal messages. Start a fresh one in the same worktree (`--worktree name:<name>`), with a handoff notes file in the brief.
- Two messages sent close together arrive in order. If you correct yourself, the worker may act on the first one before reading the second.

## Doing what workers can't

The auto-mode classifier often refuses workers' `git push`, `gh pr create`, `gh issue create` and pushes to `screenshots`. When a worker sends a branch and body file, do it:

- Push from its worktree, then `gh pr create -R cyc-seattle/<repo> --head <branch> --base main --title "<title>" --body-file <file>`. Check that the body file is the right one: workers overwrite each other's `.plans/` files.
- Fill in any `<PR>` placeholders afterwards with `gh pr edit --body-file`.
- Screenshots: add a temporary worktree of `origin/screenshots`, copy the images to `pr-<n>/`, commit, `git push origin HEAD:screenshots`, and embed `https://raw.githubusercontent.com/cyc-seattle/<repo>/<sha>/pr-<n>/<file>`. Then remove the worktree.

You can't close PRs or cancel other workloads' runs either. Give the maintainer the exact `! gh ...` command.

## Reviewing and merging

- **Read the diff** before merging (`gh pr diff`). Look for "club" or "family" wording, real data, and anything that breaks the brief.
- **You merge** any PR once CI is green and you've read the diff. The maintainer reviews features PRs that define new requirements, and UI they asked to see. When unsure, ask.
- **Merge queues** (platform, sail-team, isthmia):
  - Wait for checks first (`gh pr checks N -R repo --watch`), then queue with plain `gh pr merge N -R repo`, with no `--squash`, `--delete-branch` or `--auto`.
  - On a PR whose checks are still pending, that command does nothing, silently. Confirm it's in the queue:
    `gh api graphql -f query='{repository(owner:"cyc-seattle",name:"<repo>"){mergeQueue{entries(first:10){nodes{state position pullRequest{number}}}}}}'`
  - Repos without a queue (`.github`): `gh pr merge N -R repo --squash --delete-branch`.
- **Batching.** The queues batch: HEADGREEN, up to 100, no wait. A PR queued alone starts at once. PRs queued while it runs form the next batch, and only the newest one's run deploys and tests. Older runs in the batch "step aside" and wait, then merge with it. If the newest fails and leaves, the older ones deploy on their own once.
- **Ejected PRs.** When a PR leaves the queue, find out why:
  `gh api graphql -f query='{repository(owner:"cyc-seattle",name:"<repo>"){pullRequest(number:N){timelineItems(last:3,itemTypes:[REMOVED_FROM_MERGE_QUEUE_EVENT]){nodes{... on RemovedFromMergeQueueEvent{reason createdAt}}}}}}'`
  Then read the failing run with `gh run view <id> -R cyc-seattle/<repo> --log-failed`, strip the color codes, and grep for errors.
- **A queued branch can't be pushed.** Dequeue it first (the `dequeuePullRequest` GraphQL mutation with the PR's node id), push, wait for CI, then re-queue.
- **Stacked PRs.** Never `--delete-branch` a PR another PR is based on. After a squash merge, the next PR conflicts: have its author merge `origin/main` (never force-push), then merge it.
- **Two fixes, each failing on what the other fixes:** combine them into one PR.

## Shared dev

Every repo deploys to one dev cluster.

- **Order matters.** A PR's queue run deploys that PR's code to dev. A schema change on dev breaks the other repos' journeys until their matching PR lands. Sequence it: land what needs today's dev first, then the schema change, then its consumers.
- **A migration that fails half-way leaves dev half-migrated.** Every other queue run then fails on it. Fixing the PR comes first.
- **Hung runs.** A run that shows "in progress" far longer than usual holds the dev slot. Check its current step through the jobs API. Cancel it if it's yours, or ask the maintainer.

## Prod deploys

The maintainer has given standing permission to approve prod deploys after reading the preview.

1. Run [scripts/approval-wait.sh](scripts/approval-wait.sh) in the background. It exits when any repo's run waits for approval.
2. Read the preview: `scripts/prod-preview.sh <repo> <run>`. Check every create, delete and replace against what the merged PRs should change. A rebuilt app image or sync image is normal.
3. Approve in a **separate** command: `scripts/approve.sh <repo> <run> "<what it showed>"`. Combining read and approve is a blind apply, and the classifier blocks it.
4. Watch it finish (`gh run watch <run> -R ... --exit-status`), then verify with your own checks: curl the pages, OIDC discovery, a Directus read through the MCP, `kubectl`. Don't ask the maintainer to test what you can check.

Other rules:
- **Two halves of one change** (a platform schema and the sail-team pages that read it): get both merged, then approve platform first and the other right after, so prod is broken for minutes, not hours.
- **Bootstrap (repo settings):** pull `main` in the platform checkout, run `mise run preview-bootstrap`, read it, then `mise run deploy-bootstrap -- --yes` in a separate command. Settings changes don't restart queue entries that are already waiting: re-queue them.

## Cleaning up

Once a worker's PR is merged (or pushed and only awaiting review), check its worktree is clean and nothing is unpushed, then `orca worktree rm --worktree name:<name>` (or `git -C <repo> worktree remove <path>` for worktrees Orca didn't make) and delete the local branch. Worktrees are 300–600 MB each. The maintainer sees leftovers as "discovered worktrees" in Orca.

## Check-in (every 30 minutes)

1. Run `scripts/status.sh`. It lists live workers with the tail of each screen, open PRs, merge queues, and unfinished runs.
2. Read any queued messages (`orca orchestration check --types "worker_done,escalation,question,status" --json`) and answer them.
3. **Workers:** clean up the done ones. Poke the stalled ones: read their screen, write the message to `.plans/`, type it in.
4. **PRs:** queue the green ones, find out why any were ejected, and read and approve waiting prod deploys.
5. **Anything slow:** hung runs, a PR stuck behind the dev slot, an unqueued green PR. Fix it or report it.
6. Report in a few lines: what moved, what's waiting on the maintainer (with commands), and what's next.

## Safety

- **Secrets:** never print secret values. Pulumi state goes to files, never to the terminal. If a worker leaks one, tell the maintainer, let them decide on rotating it, and delete that worker's transcript (`~/.claude/projects/-home-ungood-orca-workspaces-...`) once its worktree is removed.
- **Prod Pulumi state is read-only for workers.** Dev state only after a backup.
- **Independent review before prod:** for a risky prod change (migrations, auth), have a fresh agent review it against prod data (read only). Then check the queue's real dev deploy too: the review can't catch clashes between deploy steps.
