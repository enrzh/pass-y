#!/bin/bash
# usage: run_plan.sh <name> <testplan> [only-testing ...]   e.g. run_plan.sh unit Bitwarden-Unit
source "$(dirname "$0")/env.sh"
cd "$PASSY_REPO"
n=$1; plan=$2; shift 2; args=(); for t in "$@"; do args+=(-only-testing:"$t"); done
passy_wait_quiet
log="$PASSY_OUT/$n.log"; echo "start load $(sysctl -n vm.loadavg)" > "$log"
rm -rf "$PASSY_OUT/$n.xcresult"
passy_run_xcodebuild "$log" test -project Bitwarden.xcodeproj -scheme Bitwarden -testPlan "$plan" \
  -destination "id=$PASSY_PHONE" -derivedDataPath "$PASSY_DD" -skipPackagePluginValidation -skipMacroValidation \
  "${args[@]}" -resultBundlePath "$PASSY_OUT/$n.xcresult" CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO
