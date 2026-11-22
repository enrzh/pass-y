#!/bin/bash
# Shared paths for the local test runners. Everything lives outside /tmp (it is cleaned from outside). All paths can be
# overridden through the environment. Logs, result bundles and throwaway data go to the scratch directory and are
# deleted after a validated step; one shared DerivedData is used.
export PASSY_SCRATCH="${PASSY_SCRATCH:-$HOME/Library/Caches/passy-vw-scratch}"
export PASSY_CACHE="${PASSY_CACHE:-$PASSY_SCRATCH}"
export PASSY_OUT="${PASSY_OUT:-$PASSY_SCRATCH/out}"                    # logs, result bundles
export PASSY_DD="${PASSY_DD:-$HOME/Library/Caches/passy-vw-dd}"        # DerivedData (shared, with SourcePackages)
export PASSY_REPO="${PASSY_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VW_BIN="${VW_BIN:-/Users/enrico/Documents/GitHub/vaultwarden-build/vaultwarden}"   # Vaultwarden 1.37.5
export PASSY_PHONE="${PASSY_PHONE:-}"      # UDID of the own phone simulator (set by the caller)
export PASSY_IPAD="${PASSY_IPAD:-}"        # UDID of the own iPad simulator
mkdir -p "$PASSY_OUT" "$PASSY_DD"
# Waits until the 1-minute load average is below PASSY_MAX_LOAD; no wait unless PASSY_MAX_LOAD is set.
passy_wait_quiet() { [ -n "${PASSY_MAX_LOAD:-}" ] || return 0; while [ "$(sysctl -n vm.loadavg | awk '{print int($2)}')" -ge "${PASSY_MAX_LOAD}" ]; do sleep 20; done; }
# Ends a hung xcodebuild after the result line appeared in the log: passy_run_xcodebuild <log> <args...>
passy_run_xcodebuild() {
  local log=$1; shift
  xcodebuild "$@" >> "$log" 2>&1 &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    if grep -qE "^\*\* TEST (SUCCEEDED|FAILED)|^\*\* BUILD FAILED" "$log"; then sleep 15; kill $pid 2>/dev/null; sleep 3; kill -9 $pid 2>/dev/null; break; fi
    sleep 10
  done
  echo DONE >> "$log"
}
