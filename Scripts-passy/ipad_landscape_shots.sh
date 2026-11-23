#!/bin/bash
# usage: ipad_landscape_shots.sh <ipad-udid> <outdir> <tag> <hold-dir>
# Companion of ShotsIPadLandscapeTests.test_landscapeHold: waits for its marker files in <hold-dir> (the test gets the
# same directory as TEST_RUNNER_PASSY_HOLD_DIR) and takes real simulator screenshots of the rotated screen.
U=$1; OUT=$2; TAG=$3; HOLD=$4
mkdir -p "$OUT" "$HOLD"
for stage in home list detail; do
  for i in $(seq 1 600); do [ -f "$HOLD/$stage" ] && break; sleep 1; done
  [ -f "$HOLD/$stage" ] || { echo "landscape: no marker for $stage"; continue; }
  sleep 2
  xcrun simctl io "$U" screenshot "$OUT/$TAG-ipad-landscape-$stage.png"
  rm -f "$HOLD/$stage"
done
