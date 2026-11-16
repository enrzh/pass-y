#!/bin/bash
# usage: ipad_landscape_shots.sh <ipad-udid> <outdir> <tag>
# Companion of PassYUiR6ShotsTests.test_ipadLandscapeHold: waits for its marker files and takes real simulator screenshots.
U=$1; OUT=$2; TAG=$3
mkdir -p "$OUT" /tmp/r6hold
for stage in home list detail; do
  for i in $(seq 1 600); do [ -f /tmp/r6hold/$stage ] && break; sleep 1; done
  sleep 2
  xcrun simctl io "$U" screenshot "$OUT/$TAG-ipad-landscape-$stage.png"
  rm -f /tmp/r6hold/$stage
done
