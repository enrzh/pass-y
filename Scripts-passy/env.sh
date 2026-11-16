#!/bin/bash
# Shared paths for the local test runners. Everything lives outside /tmp (it is cleaned from outside).
export PASSY_CACHE="${PASSY_CACHE:-$HOME/Library/Caches/passy-vw}"
export PASSY_OUT="$PASSY_CACHE/out"            # logs, result bundles
export PASSY_DD="$PASSY_CACHE/dd"              # DerivedData
export PASSY_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PASSY_PHONE="${PASSY_PHONE:-3AF691E6-46D6-4436-A0AB-EBDF122F9952}"   # simulator PassY-R3
export PASSY_IPAD="${PASSY_IPAD:-AE56DC90-336B-4DB7-85C7-17EB9F4EB88E}"     # simulator PassY-iPad-R5
mkdir -p "$PASSY_OUT" "$PASSY_DD"
# Waits until the 1-minute load average is below 8 (UI results under load do not count).
passy_wait_quiet() { while [ "$(sysctl -n vm.loadavg | awk '{print int($2)}')" -ge 8 ]; do sleep 20; done; }
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
