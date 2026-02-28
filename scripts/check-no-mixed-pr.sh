#!/usr/bin/env bash
set -euo pipefail

# Validates that a git diff does not contain changes to both infra/ and lambda/.
# Usage: ./scripts/check-no-mixed-pr.sh [BASE_REF]
# BASE_REF defaults to main.

BASE_REF="${1:-main}"

INFRA_CHANGES=$(git diff --name-only "origin/$BASE_REF"...HEAD -- infra/ | wc -l | tr -d ' ')
LAMBDA_CHANGES=$(git diff --name-only "origin/$BASE_REF"...HEAD -- lambda/ | wc -l | tr -d ' ')

if [ "$INFRA_CHANGES" -gt 0 ] && [ "$LAMBDA_CHANGES" -gt 0 ]; then
  echo "ERROR: This branch contains changes to both infra/ and lambda/."
  echo "  infra/ files changed:  $INFRA_CHANGES"
  echo "  lambda/ files changed: $LAMBDA_CHANGES"
  echo "Please split into separate PRs."
  exit 1
fi

echo "OK: no mixed changes detected."
