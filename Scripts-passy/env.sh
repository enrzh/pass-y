#!/bin/bash
# Shared paths for the local test runners. Everything lives outside /tmp (it is cleaned from outside). All paths can be
# overridden through the environment; parallel runs MUST give each run its own PASSY_SCRATCH, PASSY_DD, VW_PORT and
# PASSY_SIM_PREFIX (the runners never touch another run's directories, simulators or processes).
export PASSY_SCRATCH="${PASSY_SCRATCH:-$HOME/Library/Caches/passy-ui-scratch}"
export PASSY_CACHE="${PASSY_CACHE:-$PASSY_SCRATCH}"
export PASSY_OUT="${PASSY_OUT:-$PASSY_SCRATCH/out}"                    # logs, result bundles, exported screenshots
export PASSY_DD="${PASSY_DD:-$HOME/Library/Caches/passy-ui-dd}"        # DerivedData (with SourcePackages)
export PASSY_REPO="${PASSY_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export VW_BIN="${VW_BIN:-/Users/enrico/Documents/GitHub/vaultwarden-build/vaultwarden}"   # Vaultwarden 1.37.5
export VW_PORT="${VW_PORT:-8089}"
export PASSY_SIM_PREFIX="${PASSY_SIM_PREFIX:-PassY-UI}"                 # own simulators: <prefix>-Phone, <prefix>-iPad
export PASSY_PHONE="${PASSY_PHONE:-}"      # UDID of the own phone simulator (set by the caller or the chain)
export PASSY_IPAD="${PASSY_IPAD:-}"        # UDID of the own iPad simulator
export PASSY_BUNDLE_ID=de.aiity.passy
mkdir -p "$PASSY_OUT" "$PASSY_DD"

# Waits until the 1-minute load average is below PASSY_MAX_LOAD; no wait unless PASSY_MAX_LOAD is set.
passy_wait_quiet() { [ -n "${PASSY_MAX_LOAD:-}" ] || return 0; while [ "$(sysctl -n vm.loadavg | awk '{print int($2)}')" -ge "${PASSY_MAX_LOAD}" ]; do sleep 20; done; }

# Waits (PID based, at most PASSY_FOREIGN_WAIT seconds, default 2700 = 45 min) until no foreign xcodebuild runs. The
# runners start their own xcodebuild only after this returns and wait for it, so every running xcodebuild is foreign.
# Prints the waited seconds (0 = none was running).
passy_wait_no_foreign_xcodebuild() {
  local max=${PASSY_FOREIGN_WAIT:-2700} waited=0
  while pgrep -x xcodebuild >/dev/null 2>&1; do
    [ $waited -ge "$max" ] && { echo "$waited (still running: $(pgrep -x xcodebuild | tr '\n' ' '); going anyway)"; return 0; }
    sleep 20; waited=$((waited + 20))
  done
  echo $waited
}

# The xctestrun file of the last build-for-testing of the PassYUITests scheme in PASSY_DD.
passy_xctestrun() { ls -t "$PASSY_DD"/Build/Products/PassYUITests_*.xctestrun 2>/dev/null | head -1; }

# Runs xcodebuild with the given arguments, appends to <log>, ends it by its own PID once the result line is in the log
# (xcodebuild sometimes hangs after the result). passy_run_xcodebuild <log> <args...>
passy_run_xcodebuild() {
  local log=$1; shift
  xcodebuild "$@" >> "$log" 2>&1 &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    if grep -qE "^\*\* TEST (SUCCEEDED|FAILED|EXECUTE SUCCEEDED|EXECUTE FAILED)|^\*\* (TEST )?BUILD (SUCCEEDED|FAILED)" "$log"; then
      sleep 15; kill $pid 2>/dev/null; sleep 3; kill -9 $pid 2>/dev/null; break
    fi
    sleep 10
  done
  wait $pid 2>/dev/null
  echo DONE >> "$log"
}

# A truly fresh app on simulator <udid>: uninstall, reset the keychain and remove the app group containers (they survive
# an uninstall on the simulator, and a leftover account made the app start on the unlock screen). No erase, no reboot.
passy_fresh_app() {
  local u=$1 dev="$HOME/Library/Developer/CoreSimulator/Devices/$1/data/Containers/Shared/AppGroup" groups g
  groups=$(xcrun simctl get_app_container "$u" "$PASSY_BUNDLE_ID" groups 2>/dev/null | awk '{print $2}')
  xcrun simctl terminate "$u" "$PASSY_BUNDLE_ID" >/dev/null 2>&1
  xcrun simctl uninstall "$u" "$PASSY_BUNDLE_ID" >/dev/null 2>&1
  xcrun simctl keychain "$u" reset >/dev/null 2>&1
  for g in $groups; do
    case "$g" in "$dev"/*) rm -rf "$g" 2>/dev/null || mv "$g" "$HOME/.Trash/passy-appgroup-$(date +%s)-$RANDOM" ;; esac
  done
}

# One-time keyboard and language setup of an own simulator (needs a reboot to take effect; the chain does that).
passy_sim_defaults() {
  local u=$1
  xcrun simctl spawn "$u" defaults write -g AppleKeyboards -array "en_US@sw=QWERTY;hw=Automatic"
  xcrun simctl spawn "$u" defaults write -g AppleLanguages -array en
  xcrun simctl spawn "$u" defaults write -g AppleLocale en_US
  # No autocorrection, prediction bar, smart punctuation or first-use "slide to type" intro: they can replace or swallow
  # synthesized keystrokes.
  xcrun simctl spawn "$u" defaults write com.apple.Preferences KeyboardAutocorrection -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences KeyboardPrediction -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences KeyboardShowPredictionBar -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences SmartQuotesEnabled -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences SmartDashesEnabled -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences KeyboardAutocapitalization -bool NO
  xcrun simctl spawn "$u" defaults write com.apple.Preferences DidShowContinuousPathIntroduction -bool YES
  xcrun simctl spawn "$u" defaults write com.apple.Preferences DidShowGestureKeyboardIntroduction -bool YES
}
