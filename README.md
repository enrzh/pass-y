<p align="center"><img src="Branding/passy-logo-512.png" width="128" alt="Pass-Y logo"></p>

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
  `test03_createSearchEditDelete` (create, search, edit, delete) passed in the implementer's run after fixing two test errors
  (see Round 2); an independent validator run could not confirm it because the app hit a Debug-only assertion in the error
  logger (now removed) and the simulator service then hung, so treat it as UNVERIFIED until re-validated.
- Not verifiable in the simulator: Face ID, real AutoFill in other apps, passkeys on a device, push (disabled).

## Screenshots (M1: tile home)

![Home, iPhone 17 Pro](Docs/screenshots/m1-home-iphone17pro.png)
![Detail, iPhone 17 Pro](Docs/screenshots/m1-detail-iphone17pro.png)

The palette uses light/dark variants of the system colors; dark mode screenshots were taken in Round 2.

## M3: iPad and iPhone Duo

Layout depends only on container size (no `UIScreen`/idiom checks): content is capped to a readable width and centered, tiles
reflow into more columns, bars come from the system (`TabView`/navigation bars, which the OS renders vertically on Duo).

![Home, iPad Pro 13"](Docs/screenshots/m3-home-ipad-pro13.png)
![Home, iPhone Duo (outer display)](Docs/screenshots/m3-home-iphone-duo-outer.png)

Not done / UNVERIFIED: a `NavigationSplitView` master-detail layout (the vault navigation is coordinator/UIKit based; a split view
would mean rewriting the navigation layer), Duo open/half-folded/rotated poses and reserved-region handling (the simulator pose
controls were not available in this run), Stage Manager/Slide Over, keyboard shortcuts and pointer polish.

## M2: performance measurement (2000-item vault)

Measured with `PassYUITests/PassYPerfTests` (wall clock, iPhone 17 Pro simulator, Debug build, local Vaultwarden seeded with
`Scripts-passy/vaultwarden/seed_ciphers.py 2000`; median of 3):

| Metric | before | after |
|---|---|---|
| Unlock tap to populated vault list | 2.72 s | 2.68 s |
| 30 fast swipes (dominated by XCUITest idle waits) | 43.9 s | 44.6 s |

The only code change (single-pass tile/list split instead of repeated `Equatable` comparisons) is within measurement noise;
the item list was already lazy (`LazyVStack`). No Instruments trace was taken, so scroll hitch rate and memory are UNVERIFIED.
The search timing test did not complete (UNVERIFIED). Added: light haptic feedback on tile taps.

## M4: Mac

**Decision: "Designed for iPad/iPhone" (the iOS app running on Apple Silicon Macs), not Mac Catalyst and not a native macOS target.**
Reason: the Bitwarden SDK binary (`BitwardenFFI.xcframework` from `sdk-swift`) ships only `ios-arm64` and
`ios-arm64_x86_64-simulator` slices. A Catalyst or native macOS build cannot link the SDK (crypto/sync) without building it
from `sdk-internal` for macOS, which is out of scope. The iOS build already supports the Mac destination
(`xcodebuild -destination 'platform=macOS,variant=Designed for iPad'` succeeds, exit 0) and keeps the Keychain group, App Group and
AutoFill behaviour of the iOS app unchanged, so there is no compatibility risk for the vault data.

Not done / UNVERIFIED: running the app on this Mac (needs a UI session and the Accessibility permission), a real Mac menu bar,
window sizing, keyboard shortcuts, Mac AutoFill. A future native/Catalyst target needs the SDK built with macOS slices first.

## Round 2 (R1-R6)

Done:
- **R4** `test03_createSearchEditDelete` is green. Root cause: test errors, not a product bug. The vault list is a `LazyVStack`
  sorted by name, so a new row is below the fold and not in the accessibility tree; and with a 2000-item vault fast typing in the
  search field dropped characters (the main thread is busy after each keystroke), so the test now types slowly and looks the item up via search.
- **R2** Dark mode and AX-XXXL Dynamic Type screenshots via `simctl ui <udid> appearance dark` / `content_size`:
  ![dark](Docs/screenshots/r2-home-dark-iphone17pro.png) ![XXXL](Docs/screenshots/r2-home-xxxl-iphonese.png)
  The "Introducing Archive" promo card (which filled the whole screen at XXXL) is no longer shown.
- **R1 (partial)** Menu bar / hardware keyboard commands (iPad, Mac): New Login (Cmd+N), Copy Password (Cmd+Shift+C), Copy Verification Code
  (Cmd+Option+C), Lock Vault (Cmd+L), implemented as `UIKeyCommand`s in `AppDelegate.buildMenu` that post notifications observed by the processors.
- **R6 (partial)** The watch app runs on a watchOS 27 simulator (paired with an iOS 27 simulator):
  ![watch](Docs/screenshots/r6-watch-empty-state.png) (empty state, not yet synced).

Not done / UNVERIFIED: iPad/Duo `NavigationSplitView` master-detail; Duo open/half-folded poses with reserved regions (the Duo simulator got stuck on the
splash screen in the inner-display landscape pose in this run and was not investigated further); Cmd+F search shortcut; pointer hover;
running on the Mac (menu/window screenshot); a Home Screen screenshot of the new icon (only a composite preview exists); new Instruments/XCTMetric measurements; TOTP list on the watch with synced data and the complication.

## Logo

A "Y" cut like a key: two arms that meet in a keyhole, a stem with two key teeth; flat, two colors. The source is vector
(`Branding/passy-logo.svg`, plus dark and tinted variants); `swift Scripts-passy/generate_logo.swift .` renders all app icons
(iOS any/dark/tinted, Dev/Beta, action extension, watch app and widget, complication PDFs) from the same geometry.

![Pass-Y icons: any, dark, tinted; 60 pt and 29 pt](Branding/icons-preview.png)

## Round 3

- **R6 watch TOTP list**: the watch app has a debug-only demo mode (`-passyDemoCodes` launch argument, `#if DEBUG`) that shows fixture items,
  so the list and the code view were verified on a watchOS 27 simulator without a paired iPhone:
  ![watch list](Docs/screenshots/r6-watch-list.png) ![watch code](Docs/screenshots/r6-watch-totp-detail.png)
  The real WatchConnectivity sync from the iPhone and the complication were not exercised.
- **R7 icon on the Home Screen / App Library** (iOS 26.5 simulator, light and dark):
  ![icon light](Docs/screenshots/r7-icon-appLibrary-light.png) ![icon dark](Docs/screenshots/r7-icon-appLibrary-dark.png)
- **R1 iPhone Duo**: the app launches and lays out in portrait and landscape on the Duo simulator (iOS 27.1); the earlier "stuck on
  splash" was not reproducible on a freshly created simulator and was most likely a loaded host.
  ![duo portrait](Docs/screenshots/r1-duo-portrait-intro.png) ![duo landscape](Docs/screenshots/r1-duo-landscape-intro.png)
  Open/half-folded poses with reserved regions could not be driven (the simulator only exposes rotation).
- **R5 metrics** (2000-item vault, iPhone 17 Pro simulator, Debug): unlock to populated list 2.70 s (before: 2.72 s); 10 fast swipes:
  wall clock 22.3 s, app CPU time 4.2 s (about 19 % of wall time, the rest is XCUITest idle waits), peak physical memory about 92 MB.
  No optimization was made, so there is no before/after improvement; the search timing test still does not finish.

Still not done (UNVERIFIED): iPad/Mac `NavigationSplitView` master-detail (the vault navigation is built on UIKit coordinators, a
split view needs that layer rewritten), Cmd+F focusing the search field (`.searchable` has no programmatic focus on the iOS 15 deployment
target), Stage Manager window sizes, pointer hover polish, and running/screenshotting on the Mac ("Designed for iPad" needs an
interactive session with the Accessibility permission, which was not changed).

## Round 4

- **R1 two-column layout (iPad, wide windows)**: on containers at least 900 pt wide (measured from the container, not the device idiom) the vault
  list shows the category tiles as a single-column sidebar next to the item list, instead of tiles on top. This is a thin SwiftUI layout change
  inside the existing vault list view, not a UIKit `UISplitViewController`/`NavigationSplitView` replacement of the coordinators.
  ![iPad portrait](Docs/screenshots/r1-ipad-pro13-portrait-two-column.png)
  ![iPad landscape](Docs/screenshots/r1-ipad-pro13-landscape-two-column.png)
- **Cmd+F** (menu "Vault > Search") focuses the system search field of the front window; tiles have a pointer hover highlight.
  Both were only code-reviewed and built, not exercised with a hardware keyboard or pointer.
- **R3 Mac**: `xcodebuild test -destination 'platform=macOS,variant=Designed for iPad' -only-testing:BitwardenTests` starts the app as an iOS process on
  macOS (the log shows `Bitwarden.app` loading `/System/iOSSupport` accessibility bundles), but the XCTest bundle fails to load `SnapshotTesting.framework`
  under the Mac sandbox, so the run fails and there is no window screenshot. The app on the Mac is therefore only partly verified.
- **iPhone Air**: `devicectl` reports the device as `unavailable`, so the device build was not refreshed in this round.

Still not done (UNVERIFIED): a true `NavigationSplitView`, Stage Manager window sizes, keyboard/pointer behavior at runtime, a Mac window screenshot.

## Round 5

- **R1 second iPad type (iPad Air 11", 834 pt wide in portrait)**: below the 900 pt threshold the tiles stay on top in four columns, in landscape
  the two-column sidebar layout applies. ![Air portrait](Docs/screenshots/r1-ipad-air11-portrait-tiles-on-top.png)
  ![Air landscape](Docs/screenshots/r1-ipad-air11-landscape-two-column.png)
  Stage Manager window sizes cannot be driven in the simulator; the layout only depends on the container width, so any window width follows the same rule.
- **R5 optimization with before/after** (2000+ item vault, iPhone 17 Pro simulator, Debug, same session, `PassYPerfTests`): the last-row detection in
  the vault and search lists used a deep `Equatable` comparison of whole items and now compares ids.

  | Metric | before | after |
  |---|---|---|
  | unlock to populated list | 2.91 s | 2.92 s |
  | 30 fast swipes (XCUITest-dominated) | 45.4 s | 44.5 s |
  | search to exact hit (incl. 1.7 s typing delay) | 11.3 s | 11.8 s |
  | 10 swipes, app CPU time | 7.2 s | 6.2 s (RSD 14 %) |
  | peak memory | 91.9 MB | 91.9 MB |

  The differences are within measurement noise (CPU time varies between sessions: 4.2 s in an earlier session), so there is **no demonstrated improvement**.
  The list was already lazy; the dominant costs are inside the SDK/search pipeline and XCUITest, not the SwiftUI layer.
- **R3 Mac, direct launch**: `open Bitwarden.app` on the Mac build fails with "The application cannot be opened because it has an incorrect executable format"
  (an iOS binary cannot be started outside Xcode/App Store installation), so there is no Mac window screenshot or menu check. UNVERIFIED.
- **R1 Duo poses**: only the poses the simulator exposes were captured (portrait on the outer display, landscape on the inner display, see Round 3);
  half-folded poses and reserved regions cannot be set by `simctl`.

## Native SwiftUI rewrite (in progress)

Plan and inventory: `~/harness/specs/20261112-passy-swiftui-rewrite.md` (outside the repo). The views are rewritten group by group on top of the unchanged
Store/Processor/Service layer (Bitwarden SDK untouched), with the same accessibility identifiers so the UI tests keep working.

- **G1 (done): Landing and master-password Login** are now native `Form` screens (inset grouped sections, SF Symbols, system colors and fonts,
  prominent system buttons, `SecureField` with reveal toggle):
  ![landing light](Docs/screenshots/g1-landing-light.png) ![landing dark](Docs/screenshots/g1-landing-dark.png)
  ![landing XXXL](Docs/screenshots/g1-landing-xxxl.png)
- Not yet rewritten: Unlock, two-step login, registration screens, vault list/search, item view/edit, generator, send, settings, folders/collections,
  import/export, extensions, and the UIKit coordinators (NavigationStack/NavigationSplitView).
