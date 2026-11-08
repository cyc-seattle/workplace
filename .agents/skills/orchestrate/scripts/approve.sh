#!/usr/bin/env bash
# Approves a run's waiting prod deployment. Run prod-preview.sh first and read it.
# Usage: approve.sh <repo> <run id> "<what the preview showed>"
set -euo pipefail
repo=$1 run=$2 comment=$3
env=$(gh api "repos/cyc-seattle/$repo/actions/runs/$run/pending_deployments" -q '.[].environment.id')
gh api -X POST "repos/cyc-seattle/$repo/actions/runs/$run/pending_deployments" \
  -F "environment_ids[]=$env" -f state=approved -f comment="Preview read: $comment" -q '.[0].state'
