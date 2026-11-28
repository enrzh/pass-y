#!/bin/bash
# usage: U=<simulator udid> appstore_shots.sh <iphone69|ipad13>
# App Store screenshots of one own simulator (booted; iPhone 17/18 Pro Max or iPad Pro 13-inch; it is rebooted) in en-US and de-DE into
# AppStore/screenshots/<locale>/<device>/. Needs build_ui.sh (this PASSY_DD), the throwaway Vaultwarden
# (vaultwarden/run_local.sh) with seed_account.py and seed_demo.py for the same PASSY_EMAIL, and VW_PORT.
# PASSY_LANGS="de:de-DE" repeats single languages on the signed-in app; PASSY_MAX_LOAD=40 waits for a quiet host.
source "$(dirname "$0")/env.sh"
device=$1; : "${U:?set U to the simulator udid}" "${device:?iphone69 or ipad13}"
export TEST_RUNNER_PASSY_EMAIL="${PASSY_EMAIL:-alex.miller@example.com}"
prepare() { # prepare <language> <locale>: system language (iPad status bar date), full-screen apps, reboot, status bar
  xcrun simctl spawn "$U" defaults write -g AppleLanguages -array "$1"
  xcrun simctl spawn "$U" defaults write -g AppleLocale "$2"
  # iPadOS "Full Screen Apps": no window resize handle and no app name next to the date (ignored on the iPhone).
  xcrun simctl spawn "$U" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO
  xcrun simctl spawn "$U" defaults write com.apple.springboard SBChamoisWindowingEnabled -bool NO
  xcrun simctl shutdown "$U"; xcrun simctl boot "$U"; xcrun simctl bootstatus "$U" -b >/dev/null
  xcrun simctl ui "$U" appearance light
  xcrun simctl status_bar "$U" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
}

run() { # run <name> <fresh 0|1> <test>
  "$PASSY_REPO/Scripts-passy/run_ui.sh" "appstore-$device-$1" "$2" "PassYUITests/ShotsAppStoreTests/$3"
  grep -qE '^\*\* TEST (EXECUTE )?SUCCEEDED' "$PASSY_OUT/appstore-$device-$1.log" || { echo "FAIL: $PASSY_OUT/appstore-$device-$1.log"; exit 1; }
}

prepare en en_US
[ -n "${PASSY_LANGS:-}" ] || run signin 1 test_signIn
for pair in ${PASSY_LANGS:-en:en-US de:de-DE}; do
  lang=${pair%:*}; locale=${pair#*:}
  [ "$lang" = en ] || prepare "$lang" "${locale/-/_}"
  TEST_RUNNER_PASSY_LANG=$lang run "$lang" 0 test_storeScreens
  raw="$PASSY_OUT/appstore/$device-$lang-$(date +%s)"
  "$PASSY_REPO/Scripts-passy/export_shots.sh" "$PASSY_OUT/appstore-$device-$lang.xcresult" "$raw"
  dest="$PASSY_REPO/AppStore/screenshots/$locale/$device"; mkdir -p "$dest"
  for f in "$raw"/appstore-"$lang"-0*.png; do
    python3 "$PASSY_REPO/Scripts-passy/flatten_png.py" "$f" "$dest/$(basename "$f" | sed "s/^appstore-$lang-//")"
  done
done
prepare en en_US
