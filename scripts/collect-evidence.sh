#!/usr/bin/env bash
#
# collect-evidence.sh — run verification and append machine results to evidence.md.
# Captures the raw command output so the evidence is auditable, not just claimed.
#
# Usage: make evidence FEATURE=001-first-feature
#
set -euo pipefail

FEATURE="${FEATURE:?FEATURE is required}"
EVIDENCE="specs/$FEATURE/evidence.md"

test -f "$EVIDENCE" || { echo "missing $EVIDENCE"; exit 2; }

echo "==> Collecting verification evidence for $FEATURE"

{
  echo ""
  echo "## Verification run"
  echo ""
  echo '```text'
} >> "$EVIDENCE"

# Run verify and tee output into evidence. Do not abort the script on failure;
# a failing run is itself evidence.
if make verify >> "$EVIDENCE" 2>&1; then
  RESULT="PASS"
else
  RESULT="FAIL"
fi

{
  echo '```'
  echo ""
  echo "Result: **$RESULT**"
} >> "$EVIDENCE"

echo "==> Verification result: $RESULT (appended to $EVIDENCE)"
[ "$RESULT" = "PASS" ]
