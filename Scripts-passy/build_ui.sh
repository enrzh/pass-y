#!/bin/bash
# usage: build_ui.sh <name>: build-for-testing of the UI test scheme (app + PassYUITests) for any iOS simulator.
source "$(dirname "$0")/env.sh"
cd "$PASSY_REPO"
log="$PASSY_OUT/$1.log"; : > "$log"
passy_run_xcodebuild "$log" build-for-testing -project Bitwarden.xcodeproj -scheme PassYUITests -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$PASSY_DD" -clonedSourcePackagesDirPath "$PASSY_DD/SourcePackages" -disableAutomaticPackageResolution -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO
grep -E '^\*\* (TEST )?BUILD' "$log"
