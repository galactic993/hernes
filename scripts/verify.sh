#!/usr/bin/env bash
#
# verify.sh — thin wrapper so CI / agents can call verification by path.
# Prefer `make verify`; this exists for environments without make.
#
set -euo pipefail
exec make verify
