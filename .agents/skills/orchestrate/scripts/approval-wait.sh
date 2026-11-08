#!/usr/bin/env bash
# Exits, printing them, as soon as any run in platform, isthmia or sail-team waits for a prod approval.
for i in $(seq 1 240); do
  out=""
  for r in platform isthmia sail-team; do
    for id in $(gh api "repos/cyc-seattle/$r/actions/runs?status=waiting" -q '.workflow_runs[].id' 2>/dev/null); do
      out+="$r $id $(gh run view $id -R cyc-seattle/$r --json displayTitle -q .displayTitle)"$'\n'
    done
  done
  if [ -n "$out" ]; then printf '%s' "$out"; exit 0; fi
  sleep 30
done
echo "none waiting"
