#!/bin/bash
# usage: [U=<udid>] run_ui.sh <name> <uninstall 0|1> [test ...]   e.g. run_ui.sh flow 1 PassYUITests/PassYFlowTests
# Needs the throwaway Vaultwarden (run_local.sh) with seed_account.py / seed_ciphers.py 25 / enable_2fa.py.
source "$(dirname "$0")/env.sh"
cd "$PASSY_REPO"
U=${U:-$PASSY_PHONE}
n=$1; un=$2; shift 2; args=(); for t in "$@"; do args+=(-only-testing:"$t"); done
passy_wait_quiet
export TEST_RUNNER_PASSY_SERVER="${TEST_RUNNER_PASSY_SERVER:-http://localhost:${VW_PORT:-8088}}"
log="$PASSY_OUT/$n.log"; echo "start load $(sysctl -n vm.loadavg)" > "$log"
if [ "$un" = 1 ] && [ "${PASSY_ERASE:-0}" = 1 ]; then
  # Truly fresh: the app state survives uninstall + keychain reset ("Log in" is then not found), so erase the simulator and
  # restore the English QWERTY keyboard settings the tests need. Use only with a dedicated test simulator.
  xcrun simctl shutdown "$U" 2>/dev/null; xcrun simctl erase "$U"; xcrun simctl boot "$U"; sleep 5
  xcrun simctl spawn "$U" defaults write -g AppleKeyboards -array "en_US@sw=QWERTY;hw=Automatic"
  xcrun simctl spawn "$U" defaults write -g AppleLanguages -array en
  xcrun simctl spawn "$U" defaults write -g AppleLocale en_US
  xcrun simctl shutdown "$U"
elif [ "$un" = 1 ]; then
  xcrun simctl uninstall "$U" de.aiity.passy
  # The keychain survives an uninstall: a leftover account makes the app start on another screen (login/unlock) than
  # the fresh-install tests expect ("Log in" not found). Reset it for a truly fresh install.
  xcrun simctl keychain "$U" reset
fi
rm -rf "$PASSY_OUT/$n.xcresult"
passy_run_xcodebuild "$log" test -project Bitwarden.xcodeproj -scheme PassYUITests -destination "id=$U" \
  -derivedDataPath "$PASSY_DD" -clonedSourcePackagesDirPath "$PASSY_DD/SourcePackages" -skipPackagePluginValidation -skipMacroValidation "${args[@]}" \
  -resultBundlePath "$PASSY_OUT/$n.xcresult" CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO
