# AGENTS.md

This directory is a [place](https://github.com/ungood/place) workplace: the cyc-seattle repos checked out side by side. `place.toml` lists them. Each is an independent git repo with its own `AGENTS.md`; read that before working in it.

- This repo tracks only the workplace's own files. `.gitignore` ignores every checkout.
- `.github/` is a checkout of cyc-seattle/.github, not this repo's workflows, so this repo has no CI. Run `mise run ci` before opening a PR.
- Work that spans repos is planned on an issue in the repo that owns the outcome, usually cyc-seattle/isthmia#185 or its phase issues. Each repo gets its own PR.
- `mise run sync` never switches branches, so a checkout may be on a feature branch. Check `place status -s` before assuming a repo is on `main`.
- Repo settings, including this repo's, are code in platform's `bootstrap` stack (`stacks/bootstrap/github.ts`).
