# Rules for every worker (read first)

The coordinator copies this file to `.plans/_common.md` and every brief starts with "Read `.plans/_common.md` first and follow it."

## Working with the coordinator

- The coordinator is another Claude session, talking to you over Orca. Ask before you code: send a question with a recommendation. Never put open questions in a PR or issue.
- Everything you need from the coordinator goes through `orca orchestration send` (type `question`): a decision, "please open this PR", "please push this". Text you only print in your own terminal never reaches it, and you will sit stalled.
- Send a `status` when something changes, a `question` when you need a decision, and `worker_done` when your PRs are green and handed over. No heartbeats, and don't poll for a reply in a loop.
- The coordinator merges PRs and approves prod deploys; you don't. Once it has queued your PR, send `worker_done`. It watches the queue and will bring you back if the run fails.
- If your permissions refuse a push, `gh pr create`, `gh issue create` or a push to the `screenshots` branch, don't work around it: send the branch, title and body file path (under `/home/ungood/workplaces/cyc/.plans/`), and the coordinator does it.

## Writing

- Plain words a sailing-center staffer would say. No AI slop.
- Link issues and PRs as `[owner/repo#N](https://github.com/owner/repo/issues/N)` (or `/pull/N`), never a bare `#N`.
- Never use "club" for the organization in general: CYC is a club, CSC is a sailing center. Name the one you mean.
- Say "household", not "family", for the people who register together.
- Conventional-commit PR titles. Read each repo's `AGENTS.md` before working in it.

## Privacy and safety

- Every repo, PR and issue is public. No real names, emails, phone numbers or money figures. Use made-up data. Private material stays in `/home/ungood/workplaces/cyc/.plans/`.
- Never print secret values. No `pulumi stack export` or state dumps to the terminal: write them to a file under `.plans/backups/` and `jq` out what you need (URNs, types), never `.outputs` or `random:*` ids. Don't read secrets out of Secret Manager.
- Prod Pulumi state is read-only for you. Dev state only after a backup. Never `pulumi destroy` a shared stack.
- Never drop, recreate or rename the Directus database, or change its `PUBLIC_URL` (the license allows 5 activations).

## Branches, CI and dev

- platform, sail-team and isthmia use batched merge queues. A PR push runs only CI. The dev deploy and integration tests run in the queue, one batch at a time, on the one shared dev. Never force-push: merge `origin/main` into your branch.
- A queued PR's branch can't be pushed. If you need to change it, ask the coordinator to take it out of the queue first.
- To try a branch on dev early: `gh workflow run pull-request.yml -R cyc-seattle/<repo> --ref <branch>`, only when no other dev run is going for that repo (`gh run list -R cyc-seattle/<repo> -L 5`), and say so in a status.
- Before pushing a fix for a failing queue run, reproduce it locally against dev, so each attempt doesn't cost a queue run. `kubectl` works under the workplace's mise env: `cd /home/ungood/workplaces/cyc && mise exec -- kubectl -n dev logs deploy/directus --tail 200` (read only).
- Don't delete other workers' dev data.

## UI changes

- Review every UI change at a laptop size (1440 × 900) and a phone size (390 × 844).
- Screenshots go in the PR description, never only in `.plans/`: before and after, both sizes, made-up data. Push them to the repo's never-merged `screenshots` branch under `pr-<number>/` and embed them by commit-SHA raw URL, as the repo's `AGENTS.md` says.
