#!/bin/bash
# UI chain (generic; round tag in ROUND, default r9), started detached (see start_chain below). PID file: $O/chain.pid, log: $O/chain.log,
# result per step: $O/summary.txt. Never ends foreign processes. Sim: own PassY-${ROUND_UP}b (booted only for the duration of a
# step, shut down afterwards), PassY-2FA for the 2FA step, an own iPad simulator for the iPad steps.
# Gate: 1-minute load < 25 for 3 minutes (sampled every 30 s) before the first step, < 25 before every further step.
export HOME=${HOME:-/Users/enrico}
ROUND="${ROUND:-r9}"; ROUND_UP=$(echo "$ROUND" | tr a-z A-Z)   # (bash 3.2 on macOS: no ${var^^})   # tag for sims, screenshot names and the UiR<N> test class
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"                       # the worktree of the round
S="${PASSY_SCRATCH:-$HOME/Library/Caches/passy-vw-scratch}"; O="$S/out"      # scratch: logs, result bundles, Vaultwarden data
export PASSY_SCRATCH="$S" PASSY_OUT="$O" PASSY_REPO="$R" PASSY_DD="${PASSY_DD:-$HOME/Library/Caches/passy-vw-dd}"
VW_BIN="${VW_BIN:-/Users/enrico/Documents/GitHub/vaultwarden-build/vaultwarden}"; PORT=8089
export VW_PORT=$PORT TEST_RUNNER_PASSY_SERVER="http://localhost:$PORT"
mkdir -p "$O"
SUMMARY=$O/summary.txt; LOG=$O/chain.log
sim_id() { # sim_id <name> <device type> <runtime>: UDID of the own simulator with that name (created when missing)
  local id; id=$(xcrun simctl list devices | grep -F "$1 (" | grep -oE "[0-9A-F-]{36}" | head -1)
  [ -n "$id" ] || id=$(xcrun simctl create "$1" "$2" "$3")
  echo "$id"
}
IOS=com.apple.CoreSimulator.SimRuntime.iOS-27-0
SIM_PHONE=$(sim_id PassY-${ROUND_UP}b com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro $IOS)
SIM_2FA=$(sim_id PassY-$ROUND_UP-2FA com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro $IOS)
echo $$ > $O/chain.pid
log() { echo "$(date '+%F %T') [load $(sysctl -n vm.loadavg | awk '{print $2}')] $*" | tee -a $LOG; }
load1() { sysctl -n vm.loadavg | awk '{print int($2)}'; }
note() { echo "$(date '+%F %T') $*" >> $SUMMARY; log "$*"; }

gate() { # gate <quiet samples needed> <max seconds>
  local need=$1 max=$2 ok=0 waited=0
  while [ $ok -lt $need ]; do
    if [ "$(load1)" -lt 25 ]; then ok=$((ok+1)); else ok=0; fi
    [ $ok -ge $need ] && break
    sleep 30; waited=$((waited+30)); [ $waited -ge $max ] && return 1
  done
  return 0
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

prepare_sim() { # prepare_sim <udid>: boot, verify no foreign app (erase an own sim once), 0 = clean
  local u=$1
  xcrun simctl boot "$u" 2>/dev/null; xcrun simctl bootstatus "$u" -b >/dev/null 2>&1
  local f; f=$(foreign_apps "$u")
  if [ -n "$f" ] && [ "$u" = "$SIM_PHONE" ]; then
    note "foreign apps on own sim: $f -> erase own sim once"
    xcrun simctl shutdown "$u" 2>/dev/null; xcrun simctl erase "$u"; xcrun simctl boot "$u"; xcrun simctl bootstatus "$u" -b >/dev/null 2>&1
    xcrun simctl spawn "$u" defaults write -g AppleKeyboards -array "en_US@sw=QWERTY;hw=Automatic"
    xcrun simctl spawn "$u" defaults write -g AppleLanguages -array en
    xcrun simctl spawn "$u" defaults write -g AppleLocale en_US
    f=$(foreign_apps "$u")
  fi
  [ -z "$f" ] || { note "DISCARD: foreign apps on $u: $f"; return 1; }
  return 0
}

vw_up() {
  curl -s -o /dev/null http://localhost:$PORT/alive && return 0
  DATA_FOLDER=$S/vw-data ROCKET_PORT=$PORT LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000 DOMAIN=http://localhost:$PORT \
    SIGNUPS_ALLOWED=true WEB_VAULT_ENABLED=false EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types \
    nohup "$VW_BIN" >> $O/vaultwarden.log 2>&1 &
  echo $! > $O/vw.pid; sleep 5; curl -s -o /dev/null http://localhost:$PORT/alive
}

# step <name> <fresh 0|1|erase> <udid> <tests...> ; env: STEP_ENV (space separated TEST_RUNNER_* assignments)
step() {
  local name=$1 fresh=$2 u=$3; shift 3
  gate 1 10800 || { note "$name: SKIPPED (load stayed >= 25)"; return; }
  vw_up || { note "$name: SKIPPED (no Vaultwarden)"; return; }
  prepare_sim "$u" || { xcrun simctl shutdown "$u" 2>/dev/null; return; }
  xcrun simctl ui "$u" appearance light 2>/dev/null   # baseline; dark steps force dark through launch arguments
  local attempt result
  for attempt in 1 2; do
    local n=$name; [ $attempt = 2 ] && n=$name-retry
    local un=0; [ "$fresh" != 0 ] && [ $attempt = 1 ] && un=1
    local start_load=$(sysctl -n vm.loadavg | awk '{print $2}')
    ( export PASSY_MAX_LOAD=100000 U=$u PASSY_PHONE=$u; [ "$fresh" = erase ] && export PASSY_ERASE=1
      for kv in $STEP_ENV; do export "TEST_RUNNER_$kv"; done
      "$R/Scripts-passy/run_ui.sh" "$n" $un "$@" ) >> $LOG 2>&1
    local end_load=$(sysctl -n vm.loadavg | awk '{print $2}')
    local failed; failed=$(grep -E "^Test Case .* failed" $O/$n.log | sed -E "s/^Test Case '-\[([^ ]+) ([^]]+)\]'.*/\1\/\2/" | sort -u)
    local passed; passed=$(grep -cE "^Test Case .* passed" $O/$n.log)
    local succeeded; succeeded=$(grep -c '^\*\* TEST SUCCEEDED' $O/$n.log)
    local marker; marker=$(grep -c '^\*\* TEST FAILED' $O/$n.log)
    local crashed; crashed=$(grep -c 'Restarting after unexpected exit' $O/$n.log)
    local failing; failing=$(sed -n '/^Failing tests:/,/^\*\* TEST/p' $O/$n.log | grep '()' | sed -E 's/^[[:space:]]*//; s/\(\)$//; s#\.#/#' | sort -u)
    # a crashed test is only listed under "Failing tests:", not as "Test Case ... failed"
    [ -n "$failing" ] && failed=$(echo "$failed $(for t in $failing; do echo PassYUITests.$t; done)" | tr ' ' '\n' | sort -u)
    local foreign; foreign=$(foreign_apps "$u")
    local min=${STEP_MIN:-1}; [ $attempt = 2 ] && [ -n "$RETRY_N" ] && min=$RETRY_N
    # strict: TEST SUCCEEDED, no failing tests, no TEST FAILED marker, no runner restart, at least the expected tests
    if [ "$succeeded" -ge 1 ] && [ -z "$failed" ] && [ "$marker" = 0 ] && [ "$crashed" = 0 ] && [ "$passed" -ge "$min" ]; then
      note "$n: PASS ($passed of >= $min tests; TEST SUCCEEDED; load start $start_load end $end_load)"; break
    fi
    note "$n: FAIL (passed $passed of >= $min; succeeded-marker $succeeded; failed-marker $marker; runner restarts $crashed; failed: $(echo $failed | tr '\n' ' '); load start $start_load end $end_load; foreign: ${foreign:-none})"
    [ $attempt = 2 ] && break
    # retry once, each failed test alone (or the whole step if no test result exists)
    if [ -n "$failed" ]; then
      set -- $(for t in $failed; do echo "PassYUITests/$t" | sed "s#PassYUITests/PassYUITests\.#PassYUITests/#"; done)
      RETRY_N=$#
    fi
    gate 1 10800 || { note "$name: retry skipped (load)"; break; }
    prepare_sim "$u" || break
  done
  xcrun simctl shutdown "$u" 2>/dev/null
  for x in "$name" "$name-retry"; do   # keep the screenshots of the step (small), then drop the large result bundle
    [ -d "$O/$x.xcresult" ] && "$R/Scripts-passy/export_shots.sh" "$O/$x.xcresult" "$O/shots/$x" >/dev/null 2>&1
  done
  rm -rf "$O/$name".xcresult "$O/$name"-retry.xcresult   # result bundles are large; the logs and the summary stay
}

: > $SUMMARY
note "chain start (pid $$)"
gate 6 43200 || { note "chain: load never below 25 for 3 minutes; aborted"; exit 1; }
vw_up || { note "no Vaultwarden binary/start"; exit 1; }
cd $R
# accounts and data (idempotent markers; the data directory is in the scratch directory and starts empty)
[ -f $O/.seedmain ] || { python3 Scripts-passy/vaultwarden/seed_account.py http://localhost:$PORT >> $LOG 2>&1 && \
  python3 Scripts-passy/vaultwarden/seed_ciphers.py 25 http://localhost:$PORT >> $LOG 2>&1 && touch $O/.seedmain; }
[ -f $O/.seed2fa ] || { PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/seed_account.py http://localhost:$PORT >> $LOG 2>&1; \
  PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/enable_2fa.py http://localhost:$PORT >> $LOG 2>&1 && touch $O/.seed2fa; }

STEP_MIN=1 step diag      0 $SIM_PHONE PassYUITests/PassYUiR8Tests/test00_dumpGroupListTree
STEP_MIN=1 step landing   erase $SIM_PHONE PassYUITests/PassYLandingShotsTests
STEP_MIN=28 step flow      erase $SIM_PHONE PassYUITests/PassYFlowTests
STEP_MIN=15 step rest      1 $SIM_PHONE PassYUITests/PassYImportRegShotsTests/test_exportVault PassYUITests/PassYShotsTests PassYUITests/PassYZAppearanceTests \
  PassYUITests/PassYUiR5ShotsTests/test_newTypeForms PassYUITests/PassYUiR5ShotsTests/test_dynamicTypeForms PassYUITests/PassYUiR5ShotsTests/test_compare \
  PassYUITests/PassYUiR5ShotsTests/test_voiceOverLabels PassYUITests/PassYUiR5ShotsTests/test_addMenuAccessibilityXXXL \
  PassYUITests/PassYUiR6ShotsTests/test_rowChevronContextMenuSwipe PassYUITests/PassYUiR6ShotsTests/test_selectModeDelete PassYUITests/PassYUiR6ShotsTests/test_swipeDelete \
  PassYUITests/PassYUiR7ShotsTests
STEP_MIN=1 step regstart  erase $SIM_PHONE PassYUITests/PassYImportRegShotsTests/test_registrationStart
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=${ROUND}-auth-light"; STEP_MIN=1 step auth-light  erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_authPagesInRunningApp
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-auth-dark";  step auth-dark   1 $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_authPagesInRunningApp
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=${ROUND}-2fa-light"; STEP_MIN=1 step 2fa-light  erase $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-2fa-dark";   step 2fa-dark   1 $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-2fa-dark2";  step 2fa-dark2  1 $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=${ROUND}-dev-light"; STEP_MIN=1 step device-light erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-dev-dark";   step device-dark  erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=${ROUND}-dev-light-b"; STEP_MIN=1 step device-light-b erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-dev-dark-b";   STEP_MIN=1 step device-dark-b  erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV=""
STEP_MIN=7 step ui-r8     erase $SIM_PHONE PassYUITests/PassYUiR8Tests
STEP_ENV="PASSY_SHOT_TAG=${ROUND}"; STEP_MIN=${R9_MIN:-6} step ui-r9     erase $SIM_PHONE PassYUITests/PassYUiR9Tests; STEP_ENV=""
# iPad: own simulator
T=$(xcrun simctl list devicetypes | grep -E "iPad Air 11" | head -1 | grep -oE 'com\.apple[^)]*')
IPAD=$(sim_id PassY-$ROUND_UP-iPad "$T" $IOS)
if [ -n "$IPAD" ]; then
  STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=${ROUND}-ipad-light"; STEP_MIN=2 step ipad-light erase $IPAD PassYUITests/PassYUiR5ShotsTests/test_ipadShell PassYUITests/PassYUiR4ShotsTests/test_ipad
  STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=${ROUND}-ipad-dark";   step ipad-dark  1 $IPAD PassYUITests/PassYUiR5ShotsTests/test_ipadShell PassYUITests/PassYUiR4ShotsTests/test_ipad
  STEP_ENV=""
  xcrun simctl boot $IPAD 2>/dev/null; xcrun simctl bootstatus $IPAD -b >/dev/null 2>&1
  ( U=$IPAD bash $R/Scripts-passy/ipad_landscape_shots.sh $IPAD $O/ipad-landscape $ROUND ) >> $LOG 2>&1 &
  SHOT_PID=$!   # explicit PID: job numbers (%1) are not reliable here (a "kill %1" once ended Vaultwarden)
  STEP_MIN=1 step ipad-landscape 0 $IPAD PassYUITests/PassYUiR6ShotsTests/test_ipadLandscapeHold
  kill "$SHOT_PID" 2>/dev/null; wait "$SHOT_PID" 2>/dev/null
else
  note "ipad steps: SKIPPED (no iPad simulator type found)"
fi
# 2000 item perf: the server may have been restarted: bring it up, seed (verified by the item count through the API), and
# only then run perf. The app needs a fresh login (the first sync with the 2000 items).
vw_up || note "perf: Vaultwarden not reachable before seeding"
if [ ! -f $O/.seed2000 ]; then
  python3 Scripts-passy/vaultwarden/seed_ciphers.py 2000 http://localhost:$PORT >> $LOG 2>&1 && touch $O/.seed2000
fi
COUNT=$(python3 Scripts-passy/vaultwarden/seed_ciphers.py --count http://localhost:$PORT 2>>$LOG | tail -1)
case "$COUNT" in ''|*[!0-9]*) COUNT=0;; esac
if [ "$COUNT" -lt 2000 ]; then
  note "perf: SKIPPED (server has $COUNT items, 2000 needed; .seed2000 removed so the next run seeds again)"; rm -f $O/.seed2000
else
  note "perf: seeding verified ($COUNT items on the server)"
fi
[ "${COUNT:-0}" -ge 2000 ] && STEP_MIN=6 step perf      erase $SIM_PHONE PassYUITests/PassYPerfTests
STEP_MIN=5 step audit     1 $SIM_PHONE PassYUITests/PassYAuditShotsTests
note "chain done"
rm -f $O/chain.pid
