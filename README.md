# workplace

The [place](https://github.com/ungood/place) workplace for cyc-seattle: the repos to check out side by side, and shared config for work that spans them.

## Setup

Install [mise](https://mise.jdx.dev), then:

```sh
git clone git@github.com:cyc-seattle/workplace.git cyc
cd cyc
mise trust && mise install
mise run sync
```

`mise run sync` clones every repo in `place.toml` and fast-forwards the ones that are clean and on their default branch. It never switches branches or touches uncommitted work.

Each repo keeps its own history, CI, and releases. A change inside a repo never needs a commit here.

## Adding a repo

Run `place add <url>`, which clones it and adds it to `place.toml`, then add its path to `.gitignore`. `mise run check` runs `place doctor`, which fails if a checkout isn't ignored.
