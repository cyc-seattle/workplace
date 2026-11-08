#!/usr/bin/env bash
# Prints the resource changes in a run's prod-preview job, so a prod approval is never blind.
# Usage: prod-preview.sh <repo> <run id>     e.g. prod-preview.sh platform 42450695380
# Approve in a separate command after reading this (approve.sh); combining them is a blind apply.
set -euo pipefail
repo=$1 run=$2
job=$(gh run view "$run" -R "cyc-seattle/$repo" --json jobs \
  -q '.jobs[]|select(.name|test("^prod-preview"))|select(.name|test("wait|retry")|not)|.databaseId' | head -1)
gh api --allow-escape-sequences "repos/cyc-seattle/$repo/actions/jobs/$job/logs" 2>&1 |
  sed 's/\x1b\[[0-9;]*m//g; s/^[0-9TZ:.-]* //' |
  grep -E '^ *(~|=|\+|-|\+-|--|\+\+) +[a-zA-Z_-]+:|Resources:|to (update|create|delete|replace|import)|unchanged|^[a-z-]+: changes=' |
  grep -v vitest
