#!/bin/bash
# usage: build_ui.sh <name> [scheme]: build-for-testing of the UI test scheme (compile check + app for the simulator).
source "$(dirname "$0")/env.sh"
cd "$PASSY_REPO"
n=$1; scheme=${2:-PassYUITests}
log="$PASSY_OUT/$n.log"; : > "$log"
xcodebuild build-for-testing -project Bitwarden.xcodeproj -scheme "$scheme" -destination "id=$PASSY_PHONE" \
  -derivedDataPath "$PASSY_DD" -clonedSourcePackagesDirPath "$PASSY_DD/SourcePackages" -disableAutomaticPackageResolution -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO >> "$log" 2>&1
echo "EXIT $?" >> "$log"
