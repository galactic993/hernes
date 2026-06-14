#!/usr/bin/env bash
#
# run-loop.sh — implement the next task, verify, and repair up to MAX_ATTEMPTS.
# The minimal MVP of the automated development loop:
#   AI implements 1 task -> tests fail -> AI repairs (<=3) -> writes evidence.
#
# Usage:
#   make loop FEATURE=001-first-feature
#   FEATURE=001-first-feature scripts/run-loop.sh
#
set -euo pipefail

FEATURE="${FEATURE:?FEATURE is required (e.g. make loop FEATURE=001-first-feature)}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
# Swap this for your agent CLI, e.g. AGENT_CMD="claude -p"
AGENT_CMD="${AGENT_CMD:-codex exec}"

echo "==> Running development loop for $FEATURE (max repair attempts: $MAX_ATTEMPTS)"

# 1. Required artifacts must exist before any implementation.
test -f "specs/$FEATURE/spec.md"        || { echo "missing specs/$FEATURE/spec.md"; exit 2; }
test -f "specs/$FEATURE/acceptance.md"  || { echo "missing specs/$FEATURE/acceptance.md"; exit 2; }
test -f "specs/$FEATURE/tasks.md"       || { echo "missing specs/$FEATURE/tasks.md"; exit 2; }

# 2. Implement the next unchecked task.
$AGENT_CMD "
Use the implementation-loop skill.
Work on the next unchecked task in specs/$FEATURE/tasks.md.
Follow AGENTS.md strictly.
"

# 3. Verify. On success, record evidence and exit.
if make verify; then
  $AGENT_CMD "
  Update specs/$FEATURE/evidence.md.
  Mark the completed task in specs/$FEATURE/tasks.md.
  Summarize what passed.
  "
  echo "==> PASS on first attempt."
  exit 0
fi

# 4. Repair loop.
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "==> Repair attempt $i / $MAX_ATTEMPTS"

  $AGENT_CMD "
  Use the validation-repair-loop skill.
  Repair the current failure for specs/$FEATURE.
  Attempt number: $i.
  Follow AGENTS.md strictly.
  "

  if make verify; then
    $AGENT_CMD "
    Update specs/$FEATURE/evidence.md and specs/$FEATURE/loop-log.md.
    Mark the task complete if acceptance criteria are satisfied.
    "
    echo "==> PASS after repair attempt $i."
    exit 0
  fi
done

# 5. Out of attempts: write a human handoff.
$AGENT_CMD "
Create a human handoff report in specs/$FEATURE/evidence.md.
Include remaining failures, suspected causes, and recommended next step.
"
echo "==> FAILED after $MAX_ATTEMPTS attempts. Human handoff written to specs/$FEATURE/evidence.md"
exit 1
