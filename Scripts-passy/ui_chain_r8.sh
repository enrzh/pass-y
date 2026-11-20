#!/bin/bash
# UI chain for ui-r8, started detached (see start_chain below). PID file: $O/chain.pid, log: $O/chain.log,
# result per step: $O/summary.txt. Never ends foreign processes. Sim: own PassY-R8b (booted only for the duration of a
# step, shut down afterwards), PassY-2FA for the 2FA step, an own iPad simulator for the iPad steps.
# Gate: 1-minute load < 25 for 3 minutes (sampled every 30 s) before the first step, < 25 before every further step.
export HOME=${HOME:-/Users/enrico}
C=$HOME/Library/Caches/passy-vw; O=$C/out-r8; R=$C/wt-r8
SUMMARY=$O/summary.txt; LOG=$O/chain.log
SIM_PHONE=$(cat $O/sim); SIM_2FA=$(xcrun simctl list devices | grep "PassY-R8-2FA" | grep -oE "[0-9A-F-]{36}" | head -1)
[ -n "$SIM_2FA" ] || SIM_2FA=$(xcrun simctl create PassY-R8-2FA com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0)
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
  curl -s -o /dev/null http://localhost:8089/alive && return 0
  DATA_FOLDER=$O/vw-data ROCKET_PORT=8089 LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000 DOMAIN=http://localhost:8089 \
    SIGNUPS_ALLOWED=true WEB_VAULT_ENABLED=false EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types \
    nohup $C/src/target/release/vaultwarden >> $O/vaultwarden.log 2>&1 &
  echo $! > $O/vw.pid; sleep 5; curl -s -o /dev/null http://localhost:8089/alive
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
    ( export PASSY_MAX_LOAD=100000 U=$u; [ "$fresh" = erase ] && export PASSY_ERASE=1
      for kv in $STEP_ENV; do export "TEST_RUNNER_$kv"; done
      "$O/run_ui_r8.sh" "$n" $un "$@" ) >> $LOG 2>&1
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
}

: > $SUMMARY
note "chain start (pid $$)"
gate 6 43200 || { note "chain: load never below 25 for 3 minutes; aborted"; exit 1; }
vw_up || { note "no Vaultwarden binary/start"; exit 1; }
cd $R
# accounts and data (idempotent markers)
[ -f $O/.seed2fa ] || { PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/seed_account.py http://localhost:8089 >> $LOG 2>&1; \
  PASSY_EMAIL=passy-2fa@example.test python3 Scripts-passy/vaultwarden/enable_2fa.py http://localhost:8089 >> $LOG 2>&1 && touch $O/.seed2fa; }

STEP_MIN=1 step diag      0 $SIM_PHONE PassYUITests/PassYUiR8Tests/test00_dumpGroupListTree
STEP_MIN=1 step landing   erase $SIM_PHONE PassYUITests/PassYLandingShotsTests
STEP_MIN=28 step flow      erase $SIM_PHONE PassYUITests/PassYFlowTests
STEP_MIN=15 step rest      1 $SIM_PHONE PassYUITests/PassYImportRegShotsTests/test_exportVault PassYUITests/PassYShotsTests PassYUITests/PassYZAppearanceTests \
  PassYUITests/PassYUiR5ShotsTests/test_newTypeForms PassYUITests/PassYUiR5ShotsTests/test_dynamicTypeForms PassYUITests/PassYUiR5ShotsTests/test_compare \
  PassYUITests/PassYUiR5ShotsTests/test_voiceOverLabels PassYUITests/PassYUiR5ShotsTests/test_addMenuAccessibilityXXXL \
  PassYUITests/PassYUiR6ShotsTests/test_rowChevronContextMenuSwipe PassYUITests/PassYUiR6ShotsTests/test_selectModeDelete PassYUITests/PassYUiR6ShotsTests/test_swipeDelete \
  PassYUITests/PassYUiR7ShotsTests
STEP_MIN=1 step regstart  erase $SIM_PHONE PassYUITests/PassYImportRegShotsTests/test_registrationStart
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=r8-auth-light"; STEP_MIN=1 step auth-light  erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_authPagesInRunningApp
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=r8-auth-dark";  step auth-dark   1 $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_authPagesInRunningApp
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=r8-2fa-light"; STEP_MIN=1 step 2fa-light  erase $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=r8-2fa-dark";   step 2fa-dark   1 $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=r8-2fa-dark2";  step 2fa-dark2  1 $SIM_2FA PassYUITests/PassYUiR6ShotsTests/test_auth2FAScreens
STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=r8-dev-light"; STEP_MIN=1 step device-light erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=r8-dev-dark";   step device-dark  erase $SIM_PHONE PassYUITests/PassYUiR6ShotsTests/test_loginWithDeviceAfterLogout
STEP_ENV=""
STEP_MIN=7 step ui-r8     erase $SIM_PHONE PassYUITests/PassYUiR8Tests
# iPad: own simulator
IPAD=$(xcrun simctl list devices | grep "PassY-R8-iPad" | grep -oE '[0-9A-F-]{36}' | head -1)
if [ -z "$IPAD" ]; then
  T=$(xcrun simctl list devicetypes | grep -E "iPad Air 11" | head -1 | grep -oE 'com\.apple[^)]*')
  IPAD=$(xcrun simctl create PassY-R8-iPad "$T" com.apple.CoreSimulator.SimRuntime.iOS-27-0 2>/dev/null)
fi
if [ -n "$IPAD" ]; then
  STEP_ENV="PASSY_MODE=light PASSY_EXPECT_APPEARANCE=light PASSY_SHOT_TAG=r8-ipad-light"; STEP_MIN=2 step ipad-light erase $IPAD PassYUITests/PassYUiR5ShotsTests/test_ipadShell PassYUITests/PassYUiR4ShotsTests/test_ipad
  STEP_ENV="PASSY_MODE=dark PASSY_EXPECT_APPEARANCE=dark PASSY_SHOT_TAG=r8-ipad-dark";   step ipad-dark  1 $IPAD PassYUITests/PassYUiR5ShotsTests/test_ipadShell PassYUITests/PassYUiR4ShotsTests/test_ipad
  STEP_ENV=""
  xcrun simctl boot $IPAD 2>/dev/null; xcrun simctl bootstatus $IPAD -b >/dev/null 2>&1
  ( U=$IPAD bash $R/Scripts-passy/ipad_landscape_shots.sh $IPAD $O/ipad-landscape r8 ) >> $LOG 2>&1 &
  STEP_MIN=1 step ipad-landscape 0 $IPAD PassYUITests/PassYUiR6ShotsTests/test_ipadLandscapeHold
  kill %1 2>/dev/null
else
  note "ipad steps: SKIPPED (no iPad simulator type found)"
fi
# 2000 item perf
[ -f $O/.seed2000 ] || { python3 Scripts-passy/vaultwarden/seed_ciphers.py 2000 http://localhost:8089 >> $LOG 2>&1 && touch $O/.seed2000; }
STEP_MIN=6 step perf      0 $SIM_PHONE PassYUITests/PassYPerfTests
STEP_MIN=5 step audit     1 $SIM_PHONE PassYUITests/PassYAuditShotsTests
note "chain done"
rm -f $O/chain.pid
