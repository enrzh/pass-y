#!/bin/bash
# UI test chain by tier. usage (start detached, e.g. `nohup ... &`):
#   TIER=core|full|shots [PASSY_SCRATCH=... PASSY_DD=... VW_PORT=... PASSY_SIM_PREFIX=...] Scripts-passy/ui_chain.sh
#
# Tiers (see Docs/Testing.md, "Pass-Y UI tests"):
#   core   PassYUITests/Core: critical paths, ONE simulator boot, ONE install, ONE xcodebuild run, one Vaultwarden,
#          the app is launched and logged in once and stays running between tests. Gating, no retry.
#   full   core + PassYUITests/Full (phone) + Full/iPad (own iPad simulator) + Full/Perf (2000 item account). Gating.
#   shots  PassYUITests/Shots: screenshot export only (into $O/shots/<step>), never gating.
#
# Strict PASS per step (unchanged): `** TEST SUCCEEDED **` (`** TEST EXECUTE SUCCEEDED **` for test-without-building),
# no "Test Case ... failed", no "Failing tests:" entry, no TEST FAILED marker, no runner restart, and at least the
# expected number of passed tests (counted from the sources of the step's classes). A retry only with PASSY_RETRIES=1;
# a step that is green only after a retry is FLAKY and the tier is then not PASS.
# Before every test run the chain waits (PID based, max 45 min) until no foreign xcodebuild runs. It never ends a
# foreign process: only PIDs it started itself (xcodebuild, Vaultwarden, the screenshot driver).
# Files: $O/chain.pid, $O/chain.log, $O/summary.txt (one line per step), $O/<step>.log.
export HOME=${HOME:-/Users/enrico}
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
TIER="${TIER:-core}"
R="$PASSY_REPO"; S="$PASSY_SCRATCH"; O="$PASSY_OUT"; PORT="$VW_PORT"
export TEST_RUNNER_PASSY_SERVER="http://localhost:$PORT"
# DEBUG animation tracker install point of the app: early|late|off. Chain runs default to off (UIKit unswizzled, so a
# validation measures the real app); late|early on request (see PassYAnimationTracker.mode).
PASSY_TRACKER=${PASSY_TRACKER:-off}
export TEST_RUNNER_PASSY_TRACKER="$PASSY_TRACKER"
SUMMARY=$O/summary.txt; LOG=$O/chain.log
RETRIES=${PASSY_RETRIES:-0}
IOS=${PASSY_IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}

log() { echo "$(date '+%F %T') [load $(sysctl -n vm.loadavg | awk '{print $2}')] $*" | tee -a "$LOG"; }
note() { echo "$(date '+%F %T') $*" >> "$SUMMARY"; log "$*"; }

sim_id() { # sim_id <name> <device type>: UDID of the own simulator with that name (created when missing)
  local id; id=$(xcrun simctl list devices | grep -F "$1 (" | grep -oE "[0-9A-F-]{36}" | head -1)
  [ -n "$id" ] || id=$(xcrun simctl create "$1" "$2" "$IOS")
  echo "$id"
}

foreign_apps() { # prints user apps on simulator $1 that are not ours
  xcrun simctl listapps "$1" 2>/dev/null | plutil -convert json -o - - 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for bid,a in d.items():
    if a.get("ApplicationType")=="User" and not (bid.startswith("de.aiity.passy") or "PassYUITests" in bid):
        print(bid)'
}

boot() { # boot <udid>: boots the own simulator; the first time also applies the keyboard/language defaults (one reboot)
  local u=$1
  xcrun simctl boot "$u" 2>/dev/null; xcrun simctl bootstatus "$u" -b >/dev/null 2>&1
  if [ ! -f "$O/.prepared-$u" ]; then
    passy_sim_defaults "$u"
    xcrun simctl shutdown "$u"; xcrun simctl boot "$u"; xcrun simctl bootstatus "$u" -b >/dev/null 2>&1
    touch "$O/.prepared-$u"; note "sim $u: keyboard/language defaults applied (one-time reboot)"
  fi
  xcrun simctl ui "$u" appearance light 2>/dev/null   # baseline; dark tests force dark through a launch argument
  local f; f=$(foreign_apps "$u")
  [ -z "$f" ] || { note "DISCARD: foreign apps on $u: $f"; return 1; }
}

VW_PID=""
vw_up() {
  curl -s -o /dev/null "http://localhost:$PORT/alive" && return 0
  mkdir -p "$S/vw-data"
  DATA_FOLDER=$S/vw-data ROCKET_PORT=$PORT LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000 DOMAIN=http://localhost:$PORT \
    SIGNUPS_ALLOWED=true WEB_VAULT_ENABLED=false EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types \
    nohup "$VW_BIN" >> "$O/vaultwarden.log" 2>&1 &
  VW_PID=$!; echo $VW_PID > "$O/vw.pid"
  for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:$PORT/alive" && return 0; sleep 1; done
  return 1
}

seed() { # idempotent (markers; the data directory is in the scratch directory)
  local url=http://localhost:$PORT
  cd "$R"
  [ -f "$O/.seedmain" ] || { python3 Scripts-passy/vaultwarden/seed_account.py $url >> "$LOG" 2>&1 && \
    python3 Scripts-passy/vaultwarden/seed_ciphers.py 25 $url >> "$LOG" 2>&1 && touch "$O/.seedmain"; }
  if [ "$TIER" != core ]; then
    [ -f "$O/.seed2fa" ] || { PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/seed_account.py $url >> "$LOG" 2>&1; \
      PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/enable_2fa.py $url >> "$LOG" 2>&1 && touch "$O/.seed2fa"; }
  fi
  if [ "$TIER" = full ]; then   # the perf tests use their own account: the 2000 items never slow down the other tests
    [ -f "$O/.seedperf" ] || { PASSY_EMAIL=passy-perf@example.test python3 Scripts-passy/vaultwarden/seed_account.py $url >> "$LOG" 2>&1 && \
      PASSY_EMAIL=passy-perf@example.test python3 Scripts-passy/vaultwarden/seed_ciphers.py 2000 $url >> "$LOG" 2>&1 && touch "$O/.seedperf"; }
  fi
}

classes_in() { # classes_in <dir...>: test classes (file names) directly in the given PassYUITests sub-directories
  local d; for d in "$@"; do ls "$R/PassYUITests/$d"/*.swift 2>/dev/null; done | xargs -n1 basename | sed 's/\.swift$//' | sort
}
expected_tests() { # expected_tests <class...>: number of test methods in the sources of the classes
  local c n=0 f
  for c in "$@"; do f=$(find "$R/PassYUITests" -name "$c.swift" | head -1); n=$((n + $(grep -cE '^    func test' "$f"))); done
  echo $n
}

build() {
  local log=$O/build.log; : > "$log"
  local t0=$(date +%s)
  cd "$R"
  passy_run_xcodebuild "$log" build-for-testing -project Bitwarden.xcodeproj -scheme PassYUITests \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$PASSY_DD" -clonedSourcePackagesDirPath "$PASSY_DD/SourcePackages" \
    -disableAutomaticPackageResolution -skipPackagePluginValidation -skipMacroValidation \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO
  if grep -qE '^\*\* TEST BUILD SUCCEEDED' "$log" && [ -n "$(passy_xctestrun)" ]; then
    note "build: PASS ($(( $(date +%s) - t0 )) s)"; return 0
  fi
  note "build: FAIL (see $log)"; return 1
}

# step <name> <fresh 0|1> <udid> <gating 0|1> <class...>; env STEP_ENV: space separated KEY=VALUE for the test runner
STEP_RESULT=""
step() {
  local name=$1 fresh=$2 u=$3 gating=$4; shift 4
  # PASSY_ONLY_STEP=<name>: run only that step of the tier (seeding stays the tier's); the others are skipped.
  if [ -n "${PASSY_ONLY_STEP:-}" ] && [ "$PASSY_ONLY_STEP" != "$name" ]; then STEP_RESULT=INFO-SKIPPED; note "$name: skipped (PASSY_ONLY_STEP=$PASSY_ONLY_STEP)"; return; fi
  [ -n "${PASSY_STEP_CLASSES:-}" ] && set -- $PASSY_STEP_CLASSES   # override (positive controls, single classes)
  local classes=("$@") tests=() c
  for c in "${classes[@]}"; do tests+=(-only-testing:"PassYUITests/$c"); done
  local min; min=$(expected_tests "${classes[@]}")
  vw_up || { note "$name: FAIL (no Vaultwarden)"; STEP_RESULT=FAIL; return; }
  boot "$u" || { STEP_RESULT=FAIL; return; }
  local attempt n=$name
  for attempt in $(seq 0 "$RETRIES"); do
    [ "$attempt" -gt 0 ] && n=$name-retry$attempt
    local waited; waited=$(passy_wait_no_foreign_xcodebuild)
    [ "$waited" != 0 ] && note "$n: waited ${waited}s for foreign xcodebuild"
    WAIT_TOTAL=$((WAIT_TOTAL + ${waited%% *}))
    [ "$fresh" = 1 ] && passy_fresh_app "$u"
    local log=$O/$n.log; echo "start load $(sysctl -n vm.loadavg)" > "$log"
    rm -rf "$O/$n.xcresult"
    local start_load end_load t0 t1; start_load=$(sysctl -n vm.loadavg | awk '{print $2}'); t0=$(date +%s)
    # Stall watcher: the tests only request a dump for a stalled typeText. Any idle wait can stall (taps too), so fire
    # the dump while the log sits on "Wait for ... to idle" for 20 s (again every 30 s while it stays there), and after
    # every "not received" line. Each fire is logged ($O/<step>.watcher.log: time, log line, reason); the first 6 fires
    # also take a host `sample` of the app process ($O/<step>.sample-<k>.txt), which works even if the app's main
    # thread is blocked.
    ( seen=0; lastfire=0; k=0; wlog=$O/$n.watcher.log; : > "$wlog"
      while sleep 5; do
        c=$(grep -c 'App animations complete notification not received' "$log" 2>/dev/null); c=${c:-0}
        m=$(stat -f %m "$log" 2>/dev/null); now=$(date +%s)
        why=""
        [ "$c" -gt "$seen" ] && { seen=$c; why="not-received #$c"; }
        if [ -z "$why" ] && [ -n "$m" ] && [ $((now - m)) -ge 20 ] && [ $((now - lastfire)) -ge 30 ] \
           && tail -n 3 "$log" | grep -q 'Wait for .* to idle'; then
          why="idle wait quiet $((now - m)) s"
        fi
        [ -n "$why" ] || continue
        lastfire=$now
        xcrun simctl spawn "$u" notifyutil -p de.aiity.passy.dumpAnimations >/dev/null 2>&1
        pid=$(pgrep -f "Devices/$u/data/Containers/Bundle/Application/.*/Bitwarden.app/Bitwarden" | head -1)
        echo "$(date '+%F %T') line $(wc -l < "$log" | tr -d ' ') pid ${pid:--} load $(sysctl -n vm.loadavg | awk '{print $2}'): $why; last: $(tail -n 1 "$log" | cut -c1-120)" >> "$wlog"
        if [ -n "$pid" ] && [ $k -lt 6 ]; then k=$((k + 1)); sample "$pid" 2 -file "$O/$n.sample-$k.txt" >/dev/null 2>&1 & fi
      done ) &
    local watcher=$!
    ( export TEST_RUNNER_PASSY_SERVER TEST_RUNNER_PASSY_HOLD_DIR="$O/hold"
      for kv in $STEP_ENV; do export "TEST_RUNNER_$kv"; done
      cd "$R"
      passy_run_xcodebuild "$log" test-without-building -xctestrun "$(passy_xctestrun)" -destination "id=$u" \
        -parallel-testing-enabled NO -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance 900 \
        -maximum-test-execution-time-allowance 1800 "${tests[@]}" -resultBundlePath "$O/$n.xcresult" )
    t1=$(date +%s); end_load=$(sysctl -n vm.loadavg | awk '{print $2}')
    kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
    # DEBUG animation dumps (PassYAnimationDump, requested by the tests on an idle stall): copy them out before the
    # next fresh install deletes the app container.
    local box; box=$(xcrun simctl get_app_container "$u" "$PASSY_BUNDLE_ID" data 2>/dev/null)
    [ -n "$box" ] && [ -s "$box/tmp/passy-animations.txt" ] && cp "$box/tmp/passy-animations.txt" "$O/$n.animations.txt" \
      && log "$n: animation dumps in $O/$n.animations.txt ($(grep -c '^=== ' "$O/$n.animations.txt") dumps)"
    local failed passed succeeded marker crashed failing retypes alerts
    failed=$(grep -E "^Test Case .* failed" "$log" | sed -E "s/^Test Case '-\[([^ ]+) ([^]]+)\]'.*/\1\/\2/" | sort -u)
    passed=$(grep -cE "^Test Case .* passed" "$log")
    succeeded=$(grep -cE '^\*\* TEST (EXECUTE )?SUCCEEDED' "$log")
    marker=$(grep -cE '^\*\* TEST (EXECUTE )?FAILED' "$log")
    crashed=$(grep -c 'Restarting after unexpected exit' "$log")
    failing=$(sed -n '/^Failing tests:/,/^\*\* TEST/p' "$log" | grep '()' | sed -E 's/^[[:space:]]*//; s/\(\)$//; s#\.#/#' | sort -u)
    [ -n "$failing" ] && failed=$(echo "$failed $(for t in $failing; do echo "PassYUITests.$t"; done)" | tr ' ' '\n' | grep . | sort -u)
    retypes=$(grep -c 'PASSY-RETYPE [0-9]' "$log"); alerts=$(grep -c 'LOGIN-ALERT ' "$log"); launches=$(grep -c 'PASSY-LAUNCH [0-9]' "$log")
    # Zero-hits rule: any XCUITest idle stall fails the step (it means the app did not become idle within 60 s).
    local hits; hits=$(grep -c 'App animations complete notification not received' "$log")
    local info="$passed of >= $min tests; $((t1 - t0)) s; app launches $launches; retypes $retypes; login alerts $alerts; idle-stall hits $hits; load start $start_load end $end_load"
    if [ "$succeeded" -ge 1 ] && [ -z "$failed" ] && [ "$marker" = 0 ] && [ "$crashed" = 0 ] && [ "$hits" = 0 ] && [ "$passed" -ge "$min" ]; then
      if [ "$attempt" = 0 ]; then STEP_RESULT=PASS; else STEP_RESULT=FLAKY; fi
      note "$n: $STEP_RESULT ($info; TEST SUCCEEDED)"; break
    fi
    STEP_RESULT=FAIL
    note "$n: FAIL ($info; succeeded-marker $succeeded; failed-marker $marker; runner restarts $crashed; failed: $(echo $failed | tr '\n' ' '); foreign: $(foreign_apps "$u" | tr '\n' ' '))"
    grep -E "error: -\[|XCTAssert|Failed to|PASSY-RETYPE|LOGIN-ALERT" "$log" | head -20 >> "$LOG"
    # a retry repeats only the failed tests (or the whole step if no test result exists)
    if [ -n "$failed" ]; then
      tests=(); for t in $failed; do tests+=(-only-testing:"$(echo "PassYUITests/$t" | sed 's#PassYUITests/PassYUITests\.#PassYUITests/#')"); done
      min=${#tests[@]}
    fi
  done
  [ "$gating" = 1 ] || STEP_RESULT="INFO-$STEP_RESULT"
  for x in "$O/$name".xcresult "$O/$name"-retry*.xcresult; do   # keep the screenshots (small), drop the bundles (large)
    [ -d "$x" ] && "$R/Scripts-passy/export_shots.sh" "$x" "$O/shots/$(basename "$x" .xcresult)" >/dev/null 2>&1
    rm -rf "$x"
  done
}

TIER_OK=1; WAIT_TOTAL=0
gate() { case "$STEP_RESULT" in PASS|INFO-*) ;; *) TIER_OK=0 ;; esac; }

mkdir -p "$O" "$O/hold"
echo $$ > "$O/chain.pid"
: > "$SUMMARY"
T0=$(date +%s)
note "chain start TIER=$TIER tracker $PASSY_TRACKER (pid $$, port $PORT, scratch $S, dd $PASSY_DD, retries $RETRIES)"
PHONE=${PASSY_PHONE:-$(sim_id "$PASSY_SIM_PREFIX-Phone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro)}
IPAD=${PASSY_IPAD:-$(sim_id "$PASSY_SIM_PREFIX-iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4)}
note "simulators: phone $PHONE, iPad $IPAD"
if [ "${PASSY_SKIP_BUILD:-0}" = 1 ] && [ -n "$(passy_xctestrun)" ]; then note "build: skipped (PASSY_SKIP_BUILD=1, $(basename "$(passy_xctestrun)"))"
else build || { note "TIER $TIER: FAIL (build)"; rm -f "$O/chain.pid"; exit 1; }; fi
vw_up || { note "TIER $TIER: FAIL (no Vaultwarden binary/start)"; rm -f "$O/chain.pid"; exit 1; }
seed
T1=$(date +%s)

case "$TIER" in
  core)
    step core 1 "$PHONE" 1 $(classes_in Core); gate ;;
  full)
    step core 1 "$PHONE" 1 $(classes_in Core); gate
    step full-phone 1 "$PHONE" 1 $(classes_in Full); gate
    xcrun simctl shutdown "$PHONE" 2>/dev/null
    step full-ipad 1 "$IPAD" 1 $(classes_in Full/iPad); gate
    xcrun simctl shutdown "$IPAD" 2>/dev/null
    COUNT=$(PASSY_EMAIL=passy-perf@example.test python3 "$R/Scripts-passy/vaultwarden/seed_ciphers.py" --count "http://localhost:$PORT" 2>>"$LOG" | tail -1)
    case "$COUNT" in ''|*[!0-9]*) COUNT=0;; esac
    if [ "$COUNT" -ge 2000 ]; then
      note "perf: seeding verified ($COUNT Perf items on the perf account)"
      STEP_ENV="PASSY_EMAIL=passy-perf@example.test" step full-perf 1 "$PHONE" 1 $(classes_in Full/Perf); gate
    else
      note "full-perf: FAIL (perf account has $COUNT items, 2000 needed; .seedperf removed)"; rm -f "$O/.seedperf"; TIER_OK=0
    fi ;;
  shots)
    step shots-onboarding 1 "$PHONE" 0 ShotsOnboardingTests; gate
    step shots-main 1 "$PHONE" 0 $(classes_in Shots | grep -v '^ShotsOnboardingTests$'); gate
    xcrun simctl shutdown "$PHONE" 2>/dev/null
    rm -f "$O/hold"/*
    boot "$IPAD" && {
      ( bash "$R/Scripts-passy/ipad_landscape_shots.sh" "$IPAD" "$O/shots/ipad-landscape" "${PASSY_SHOT_TAG:-passy}" "$O/hold" ) >> "$LOG" 2>&1 &
      SHOT_PID=$!   # explicit PID: job numbers (%1) are not reliable here (a "kill %1" once ended Vaultwarden)
      step shots-ipad 1 "$IPAD" 0 $(classes_in Shots/iPad); gate
      kill "$SHOT_PID" 2>/dev/null; wait "$SHOT_PID" 2>/dev/null; } ;;
  *) note "unknown TIER=$TIER (core|full|shots)"; TIER_OK=0 ;;
esac

xcrun simctl shutdown "$PHONE" 2>/dev/null; xcrun simctl shutdown "$IPAD" 2>/dev/null
[ -n "$VW_PID" ] && { kill "$VW_PID" 2>/dev/null; wait "$VW_PID" 2>/dev/null; }   # only the Vaultwarden this chain started
T2=$(date +%s)
if [ $TIER_OK = 1 ]; then V=PASS; else V=FAIL; fi
note "TIER $TIER: $V (wall $((T2 - T0)) s: build+seed $((T1 - T0)) s, waiting for foreign xcodebuild $WAIT_TOTAL s, own work without that wait $((T2 - T0 - WAIT_TOTAL)) s)"
rm -f "$O/chain.pid"
