#!/bin/bash
# usage: [U=<udid>] run_ui.sh <name> <fresh 0|1> [test ...]   e.g. run_ui.sh one 0 PassYUITests/SearchTests
# Ad-hoc run of single UI tests with the build of the last build_ui.sh/ui_chain.sh (test-without-building). Needs the
# throwaway Vaultwarden (vaultwarden/run_local.sh) with seed_account.py / seed_ciphers.py 25 (/ enable_2fa.py).
# fresh=1: uninstall the app, reset the keychain and remove its app group containers first (see passy_fresh_app).
source "$(dirname "$0")/env.sh"
cd "$PASSY_REPO"
U=${U:-$PASSY_PHONE}
n=$1; fresh=$2; shift 2; args=(); for t in "$@"; do args+=(-only-testing:"$t"); done
[ -n "$(passy_xctestrun)" ] || { echo "no xctestrun in $PASSY_DD: run build_ui.sh first"; exit 1; }
passy_wait_quiet
export TEST_RUNNER_PASSY_SERVER="${TEST_RUNNER_PASSY_SERVER:-http://localhost:$VW_PORT}"
log="$PASSY_OUT/$n.log"; echo "start load $(sysctl -n vm.loadavg)" > "$log"
[ "$fresh" = 1 ] && passy_fresh_app "$U"
rm -rf "$PASSY_OUT/$n.xcresult"
passy_run_xcodebuild "$log" test-without-building -xctestrun "$(passy_xctestrun)" -destination "id=$U" -parallel-testing-enabled NO \
  "${args[@]}" -resultBundlePath "$PASSY_OUT/$n.xcresult"
