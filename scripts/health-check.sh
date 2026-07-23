#!/bin/bash
# health-check.sh — polls a /health endpoint after deployment. Exits non-zero
# (failing the GitHub Actions step) if the app never becomes healthy, which
# is what triggers the automatic rollback step in the workflow.
#
# Usage: ./health-check.sh <health-url> [max-attempts] [delay-seconds]

set -uo pipefail

URL=$1
MAX_ATTEMPTS=${2:-10}
DELAY=${3:-15}

echo "==> Health-checking $URL (up to $MAX_ATTEMPTS attempts, ${DELAY}s apart)"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" || echo "000")

  if [ "$STATUS" == "200" ]; then
    echo "==> Attempt $attempt/$MAX_ATTEMPTS: healthy (HTTP $STATUS)"
    exit 0
  fi

  echo "==> Attempt $attempt/$MAX_ATTEMPTS: not healthy yet (HTTP $STATUS)"
  sleep "$DELAY"
done

echo "==> Health check FAILED after $MAX_ATTEMPTS attempts. Deployment is unhealthy."
exit 1
