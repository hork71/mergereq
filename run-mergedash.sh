#!/bin/bash
# Daily GitLab MR sync, run under systemd as the mergedash user.
# Secrets come from mergedash.env (chmod 600, not in git).
set -euo pipefail
cd "$(dirname "$0")"

set -a
source ./mergedash.env
set +a

SINCE=$(date -d "yesterday" +%F)
UNTIL=$(date +%F)

exec python3 mergedash.py \
  --since "$SINCE" --until "$UNTIL" \
  --approvals \
  --token "$GITLAB_TOKEN" \
  --pg-dsn "$PG_DSN" \
  --pg-table gitlab_mergerequests \
  --no-print
