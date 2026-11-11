#!/bin/sh
#
# Updates the list of third-party software licenses displayed in app settings.

set -euo pipefail

if [ "$CONFIGURATION" = "Debug" ]; then
    # Add the homebrew path for Apple silicon since it's not in Xcode's path.
    if [[ ! "$PATH" =~ "/opt/homebrew/bin" ]]; then
        PATH="/opt/homebrew/bin:$PATH"
    fi

    if command -v license-plist >/dev/null 2>&1; then
        license-plist --config-path .license-plist-pm.yml
    else
        echo "license-plist not installed, skipping acknowledgements update"
    fi
fi
