# AGENTS.md

Follow `cyc:conventions` (the rules shared by every cyc-seattle repo).

This directory is a [place](https://github.com/ungood/place) workplace: the cyc-seattle repos checked out side by side. `place.toml` lists them. Each is an independent git repo with its own `AGENTS.md`; read that before working in it.

- This repo tracks only the workplace's own files. `.gitignore` ignores every checkout.
- `.github/` is a checkout of cyc-seattle/.github, not this repo's workflows, so this repo has no CI. Run `mise run ci` before opening a PR.
- Work that spans repos is planned on an issue in the repo that owns the outcome. Each repo gets its own PR.
- An issue lives in the repo whose code it changes. One with no home repo goes in this repo. Priority is the P0–P3 labels; there's no GitHub Project (cyc-seattle/.github#33).
- `mise run sync` never switches branches, so a checkout may be on a feature branch. Check `place status -s` before assuming a repo is on `main`.
- Run `mise run doctor` before work that needs gcloud or the cluster. It names the fix for each failure; a login fix needs the maintainer.
- Application Default Credentials are one login for the whole workplace, in `.gcloud/` (`mise run auth-adc`, from the workplace or any checkout). Each checkout that sets `GOOGLE_APPLICATION_CREDENTIALS` in its `mise.toml` gets its `.gcloud/application_default_credentials.json` linked to it, so Orca worktrees outside the workplace share it too.
- `KUBECONFIG` is the workplace's `.kube/config`, which holds only CYC's cluster. Run commands under the workplace's mise env, so `kubectl` never sees the machine's default kubeconfig. Never change the machine's current context.
- The workplace's own tools (`gcloud`, `coreutils`, `jq`, `prettier`) are unpinned on purpose, and there's no `mise.lock`. A lock pointed at files `.gitignore` drops, so fresh checkouts failed to install. Each checkout pins its own tools.
- `timeout` is on the workplace's PATH, through `bin/timeout`. Use it on anything that might hang.
- `.mcp.json` connects Claude Code to prod Directus's MCP server as `cycsail-team-directus`. Run `/mcp` and sign in with your own Directus login. The agent gets only your access.
- Repo settings, including this repo's, are code in platform's `bootstrap` stack (`stacks/bootstrap/github.ts`).

## Plans, research, and docs

- **`.plans/`** is git-ignored scratch space for coordinating work: briefs for agents, handoffs, and backups. Nothing in it is kept.
- **`research/`** holds what comes out of planning conversations: research, comparisons, and draft plans. Name each file `YYYY-MM-DD-<slug>.md`, for the day the work started. Commit them, and leave them as they were once their work is done.
- **`ROADMAP.md`** maps every feature issue across the repos, by area. When you open, close, or reprioritize a feature issue, update its line there.
- **A plan goes into an issue** in the repo that owns the outcome. Once posted, the issue is the source of truth, and the research file isn't updated to match it.
- **Living documentation** lives in each repo's `docs/` folder, beside its README and `AGENTS.md`. When work lands, move the facts that last into `docs/`. Docs and code cite issues, never research files.
- **This repo is public.** Research holds no secrets, personal details, or private figures.
