# Pass-Y

Pass-Y is an open-source iOS password manager for **self-hosted [Vaultwarden](https://github.com/dani-garcia/vaultwarden)** servers.
It is a fork of the [Bitwarden iOS client](https://github.com/bitwarden/ios) (GPLv3) with a different focus:

- **Server first**: you enter your own server URL; there is no Bitwarden cloud preset (US/EU/Gov are removed).
- **No telemetry**: Firebase/Crashlytics and all other crash or analytics reporting are removed. Errors are only written to the local OS log.
- **No upsells**: Premium/billing flows are disabled and never offered.
- **Own identity**: app name "Pass-Y", own icon, own bundle IDs (`de.aiity.passy*`), own App Group and Keychain group.
- Everything else is the upstream client: login with 2FA, vault, folders, search, attachments, TOTP, Send, organizations/collections,
  generator, AutoFill extension, passkeys, Face ID/PIN unlock, offline cache, editing, share/action extensions.
- The cryptography is **not** reimplemented: it stays in the Bitwarden SDK (`sdk-swift`, a public Swift package).
  The UI is plain Swift/SwiftUI.

Removed from the upstream repository: the Authenticator app, the Apple Watch app/widget, TestHarness, Bitwarden CI workflows and
fastlane release automation.

## Origin and license

Pass-Y is derived from <https://github.com/bitwarden/ios> (full git history is preserved). Copyright (c) Bitwarden Inc. and contributors.
"Bitwarden" is a trademark of Bitwarden Inc.; Pass-Y is not affiliated with or endorsed by Bitwarden.
This project is licensed under the **GNU General Public License v3.0** (see [LICENSE.txt](LICENSE.txt)); the upstream
copyright and license notices are kept unchanged. Changes by Pass-Y are also released under GPLv3.

## Build

Requirements: Xcode (tested with 27.1), `xcodegen`, `swiftgen`, `sourcery` (e.g. `brew install xcodegen swiftgen sourcery`).

```sh
xcodegen --spec project-bwk.yml
xcodegen --spec project-pm.yml
open Bitwarden.xcworkspace          # scheme "Bitwarden" (product name Pass-Y)
```

Signing defaults live in `Configs/Common-bwpm.xcconfig` (team, bundle prefix, app group). Override them in an untracked
`Configs/Local-bwpm.xcconfig` for your own team.

Simulator unit tests (ad-hoc signed, needed for the App Group entitlement):

```sh
xcodebuild test -project Bitwarden.xcodeproj -scheme Bitwarden -testPlan Bitwarden-Unit \
  -destination 'platform=iOS Simulator,name=<your simulator>' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO
```

## Testing against a throwaway Vaultwarden (never your real server)

```sh
git clone --depth 1 https://github.com/dani-garcia/vaultwarden && cd vaultwarden
cargo build --release --features sqlite,vendored_openssl      # or use the official Docker image
ROCKET_ADDRESS=127.0.0.1 ROCKET_PORT=8088 DATA_FOLDER=/tmp/vw-data WEB_VAULT_ENABLED=false \
  SIGNUPS_ALLOWED=true DOMAIN=http://localhost:8088 ./target/release/vaultwarden
python3 Scripts-passy/vaultwarden/seed_account.py http://localhost:8088
```

Throwaway test account (test values only, local server only): `passy-test@example.test` / `PassY-Test-Only-2026!`.
In the app choose server `http://localhost:8088` (simulator only).

## Branding assets

`swift Scripts-passy/generate_branding.swift .` regenerates the icon and wordmark.

## Tests

- Unit tests (`Bitwarden-Unit` plan): 5855 XCTest + 724 Swift Testing cases green (upstream baseline: 5859 XCTest, 0 failures;
  the difference is removed/rewritten cloud-region tests).
- UI tests (`PassYUITests`, XCUITest, need the throwaway Vaultwarden above): landing/server-first, login + sync,
  TOTP create/view, generator, settings (no upsell), lock/unlock, dark mode and AX-XXXL Dynamic Type screenshots.
  The create/search/edit/delete test (`test03_createSearchEditDelete`) is currently **not green**: after saving, the item
  list did not show the new item within the timeout in the test runner (the same flow works manually/in the TOTP test).
- Not verifiable in the simulator: Face ID, real AutoFill in other apps, passkeys on a device, push (disabled).
