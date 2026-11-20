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

## Status of v1.19 (read this first)

**Apple-style (native SwiftUI structure, Apple-like look):** vault list and search results (`List`), vault home bar (profile menu top right, search and `+` menu in a floating bottom bar), item view (large title, tap to copy), Add/Edit item (`Form`), generator (`Form`), Send (bottom bar, native empty state, `List`), Folders (`List`, last row clear of the add button), Settings (account row, `List`), Appearance / Other / Account security / Autofill / About (settings worker), Export and Registration start (import/registration worker), SF Symbols for all icons, P logo (black/white).

**Not native / UNVERIFIED (be skeptical of these):**
- Navigation between screens is still UIKit coordinators; `NavigationStack` / `NavigationSplitView` are not used (ui-r3: the root is now a plain UIKit container, `PassYShellController`, no `UITabBarController`; see the ui-r3 section).
- Mac window screenshot: not possible (`My Mac (Designed for iPad)` builds, but UI tests are unsupported there and `open` on the product fails with "incorrect executable format"; no Mac Catalyst target).
- Extensions (Action, AutoFill, Share, Notification) and the Watch app are embedded in the signed device build but were not run or screenshotted; widgets/complications, Duo poses and Stage Manager are unverified.
- The Send empty state (SF Symbol instead of the illustration) has no screenshot (the test vault always contains sends); `Docs/screenshots/send-add-menu-light.png` is from the older state.
- The Send add form and several sub-screens (Import file picker flow, Two-step login screens) still use the shared card components (`ContentBlock`/`BitwardenField`).
- Known edge case (v1.19, tab bar era; not re-checked in ui-r3): after opening a search result and switching screens and back, a keyboard without caret could stay until the cancel (X) button is tapped once. In ui-r3 the search text is cleared when the screen is switched from the avatar menu.
- The Unit plan crashed once in `CombinedSingleAutofillVaultListDirectorStrategyTests` on a first run after a fresh DerivedData and passed on every rerun (alone, too).
- UI tests that need a fresh install (`test01`, `PassYLandingShotsTests`, `PassYImportRegShotsTests/test_registrationStart`) must run right after an uninstall; the others log in themselves. Under heavy machine load (load average 50 to 400 with several workers) several UI tests failed in the login step and passed alone; `PassYZAppearanceTests/test_largeText` failed once in the last full run (401 s, "Could not reach the vault list") at a low load average of about 4 and passed alone in 34 s, so its cause is not established (possibly order dependent after `test_darkMode`). The Send check in `test18` is skipped when no "PassY Send" rows exist (it relies on `test16` having created some).
- Earlier validator verdict files that lived in a local `~/harness` folder were lost in a cleanup; verdicts from `Docs/verdicts/` on are kept in the repository.

**Tests at this version:** Bitwarden-Unit 5859 XCTest + 725 Swift Testing, ViewInspector 606, BitwardenKit unit, UI tests test01-18 (+ perf, dark mode, large text, shots, export, registration) on an iPhone 17 Pro simulator against a throwaway Vaultwarden.

**Please check on your iPhone:** bottom search bar and `+` menu, profile menu, light/dark switch, item view (reveal, copy), Send tab (create a text send: the system share sheet for the link opens), folders list, settings sub-screens.

## ui-r3, phase A (branch `passy/ui-r3`, not merged)

Feedback on v1.19 (iPhone Air): items 1, 3, 4, 5, 6 are done in phase A; items 2 and 7 (restyling all secondary pages, onboarding, settings, generator ... like Apple Passwords) are phase B (see the next section).

- **Shell without tab bar (5)**: `PassYShellController` (replaces `BitwardenTabBarController`) shows one top-level navigator at a time. Vault, Send, Generator and Settings are reachable only from the avatar menu top right (`PassYAvatarMenu`, same menu also has accounts, Sync now, Lock now). The iPad sidebar/tab bar is gone as well (the same avatar menu is used on iPad); `TabCoordinator` and `TabRoute` are unchanged.
- **Avatar (6)**: plain 30 pt avatar as a toolbar item; on iOS 26 the system toolbar capsule around it is removed (`sharedBackgroundVisibility(.hidden)`), so there is no container in a container.
- **One search container (4)**: the `UISearchBar` text field fill and border are cleared, only the glass capsule remains.
- **Search bar always at the bottom (3)**: the bar (search + "+" menu) is hosted by the shell, not by single screens, so it stays at the bottom on root screens and on pushed pages (item lists/groups, folders, settings sub pages, generator, send). It rides above the keyboard; pages get a bottom safe-area inset equal to the bar. Screens that can search (vault list, group lists, send list) register as search target (`passYSearchTarget`) and also provide the "+" entries; typing in the bar on any other page (Settings, Generator, an item, folders) opens the vault search at the vault root. Switching screens from the avatar menu clears the search. The old top `UISearchController`s of group lists and typed send lists, the group floating add menu, and the old `VaultBottomBar`/`SendBottomBar` are removed. Bar background is the grouped background color on every page (pages with a plain white background show a slightly different band: not adjusted).
- **Category tiles (1)**: larger (padding 16, 42 pt badge, title-size count and name, min column 160 pt).
- Tests: `PassYFlowTests` test01-18 use the avatar menu instead of the tab bar (`goTo(app, "Settings")`), new `test19` (no tab bar, avatar menu entries and navigation, avatar size), `test20` (single search field at the bottom on vault, item list, send, generator, settings, vault settings, folders; searching from the folders page shows vault results), `test21` (tile size). Audit screenshots light/dark before and after: `Docs/screenshots/ui-r3/before-*` and `after-*` (landing, server setup, login, vault home, item list/view/edit, add menu/form, search, generator, send, settings and sub pages, folders; produced by `PassYAuditShotsTests`).
- Fixed on the way: an `onChange` closure for the "+" entries saw stale entries (menu showed only "Folder" after launch), solved with `task(id:)`.
- UNVERIFIED / not done in phase A: iPad and iPad sidebar replacement screenshots (no iPad run), Duo, XXXL Dynamic Type with the new bar, VoiceOver order of the avatar menu, AutoFill/Action/Share extensions (unchanged, not run), running on a real iPhone, a hardware-keyboard Cmd+F with the new bar (Cmd+F posts to the front window's search field; the bar is now in the shell, not re-checked). Results of the phase A run (iPhone 17 Pro simulator, iOS 27.0, Vaultwarden 1.37.5): Bitwarden-Unit 5859 XCTest (45 skipped) + 726 Swift Testing, 0 failures; ViewInspector 601 executed (17 skipped), 0 failures (the two group floating-add-button tests were removed, the send bar tests became `addEntries` tests, the profile menu test became an avatar menu test); UI `PassYFlowTests` test01-10, 12-21 (test11 does not exist) all passed in one fresh-install run, plus `PassYLandingShotsTests`, `test_registrationStart` (alone, fresh install), `test_exportVault`, `test_shots`, `test_darkMode`, `test_largeText`. `PassYPerfTests` were not run. Run-order note: `test_registrationStart` fails after `test_exportVault` in one combined run (it needs a fresh install).
- Test environment note: the throwaway Vaultwarden must be a release tag (1.37.5 was used); a build of the git HEAD of 2026-11-15 rejected the app's master password hash ("Username or password is incorrect") while the same hash worked with a script, so HEAD is not usable for the UI tests.

## ui-r3, phase B (branch `passy/ui-r3`, not merged)

Goal: everything looks like Apple's Passwords app (pure SwiftUI, bottom search bar on every page). Done as four commits with before/after screenshots (light and dark) in `Docs/screenshots/ui-r3/` (`s1-*` onboarding, `s2-*` settings, `s3-*` generator/send, `s4-*` lists, items, sheets; `sN-before-*` is the state before the step, `sN-after-*` after; produced by `PassYAuditShotsTests`).

- **B1 onboarding**: intro carousel with own SF Symbols (lock.shield, faceid, wand, devices), large title, system background, prominent capsule button + plain "Log in"; self-hosted server settings are a native `Form` (identifiers kept). Landing, login, unlock and registration were already native `Form`s from earlier steps.
- **B2 settings**: Vault settings list, add/edit folder, delete account, app extension screen (SF Symbol instead of the illustration) are native. The folders page adds with a toolbar plus button; the leftover floating blue plus is gone.
- **B3 generator/send**: the generator and the Send list were already native; the shared cards (`ContentBlock`, `BitwardenTextField`, `BitwardenField`, `BitwardenMenuField`, `DateFieldPicker`) now use 22 pt continuous corners and section headers are sentence case (no more all caps). Send info moved into the "..." options menu next to the avatar (same as the generator).
- **B4**: Edit on the item view and Send view is a toolbar button instead of the floating pencil. The bottom bar has no opaque grouped-grey band any more: a blurred material that fades in from the top, so white and grey pages look the same; the plus is tint coloured everywhere.
- Tests: `test22` (Edit in toolbar, About Send in the menu), `test23` (bar at the bottom on vault/generator/send), `test24` (vault settings rows, folders add button in the toolbar, no floating plus, native name field); `test17` now checks the last folder row against the bottom search bar; ViewInspector tests adapted (folders add button, send/item edit button, send info menu).
- Results (iPhone 17 Pro-class simulator "PassY-R3", iOS 27.0, Vaultwarden 1.37.5): Bitwarden-Unit 5859 XCTest (45 skipped) + 726 Swift Testing, 0 failures; ViewInspector 601 executed (17 skipped), 0 failures; UI: `PassYFlowTests` all 24 tests (test01-24 without test11) passed in one fresh-install run except test22, which failed once because it tried the avatar menu on the pushed item list; fixed in the test, test22-24 then passed (run alone); `PassYLandingShotsTests`, `test_exportVault`, `test_shots`, `test_darkMode`, `test_largeText` passed, `PassYAuditShotsTests` (5 tests) passed; `test_registrationStart` failed in the combined run (needs a fresh install, known) and passed alone after an uninstall.
- UNVERIFIED / not done: **iPad** (an iPad Pro 11 simulator was created for one run; the login typed a wrong password because of the simulator's keyboard locale, so no iPad screenshot exists; deleted again), snapshot tests (`Bitwarden-Snapshot` not run, reference images for changed views are out of date), `PassYPerfTests`, Send type list and file Send screens, the item "..." menu and Attachments screenshots (the audit test did not reach them), two-factor, PIN unlock, SSO and other rare auth screens (`PasswordHint`, `LoginWithDevice`, `SetMasterPassword` ...) still use the shared card components, item view/edit, Send add/edit and attachments are restyled only through the shared components (rounded cards, sentence-case headers), not converted to native `Form`/`List`; the autofill "Turn on now" action card is still the Bitwarden card; Duo, XXXL Dynamic Type, VoiceOver, extensions, Watch, a real iPhone.

## ui-r4 (branch `passy/ui-r4`, not merged)

Goal: item, Send and rare auth screens in native `Form`/`List` (Apple Passwords look). Before/after screenshots in `Docs/screenshots/ui-r4/` (`s1-*` item/attachments/history, `s2-*` Send, `s3-*` auth and setup sections, `s4-*` tiles, `s5-*` iPad). "before" files exist only where ui-r3 already had the screen (item view/edit, send list, autofill, vault home); for the rest (menu, attachments, history, send add, hint, SSO, ...) there is no before picture.

- **1 Item**: new environment value `isNativeForm` (BitwardenKit, `nativeFormRows()`): inside a `Form` the shared components (`SectionView` becomes a `Section`, `ContentBlock` its rows, `BitwardenField`/`TextField`/`MenuField`/`DateFieldPicker`/`TextView`/`Toggle`/`Stepper`) draw plain rows without own card/background, outside a form they look as before. Item view, item add/edit (all types through the shared sections), attachments and password history (`List`) use it. The item "..." menu itself is the unchanged system menu.
- **2 Send**: add/edit (text, file), Send view are `Form`s; delete is a destructive row; link/copy/share are rows with SF Symbols. The type list (tap Text/File on the Send screen) is the existing `List`.
- **3 Auth**: password hint, login with device, SSO, set master password are `Form`s (2FA incl. email/recovery already were). The autofill "Turn on now" card, the account security "set up unlock" card and the vault settings "import" card are a native `NativeSetupSection` (headline row, action, optional learn-more, dismiss).
- **4 Tiles**: tile name is `.headline`, one line, shrinks (min 0.6) instead of wrapping, so tiles in a row have equal height; accessibility sizes stay one column.
- **5 Screenshots**: item edit, item menu (needs a full-screen shot; app screenshots omit system menus), attachments, send type list, file send, iPad. iPad: the earlier login failure was the keyboard layout of the simulator; setting `AppleKeyboards` to `en_US@sw=QWERTY` (`simctl spawn <udid> defaults write -g AppleKeyboards ...`) and rebooting fixed typing, login works. iPad run: iPad Pro 11 (M5), iOS 27.0, light screenshots of vault, item list/view/edit, send, settings.
- Tests: UI `PassYFlowTests` now 27 tests (test01-10, 12-27; new `test25` tile heights/no wrap, `test26` item view/edit are native lists, `test27` setup section rows); ViewInspector tests adapted (setup section, text fields) plus `NativeSetupSectionTests`; `PassYUiR4ShotsTests` produces the screenshots.
- Results (iPhone 17 Pro-class simulator "PassY-R3", iOS 27.0, Vaultwarden 1.37.5): Bitwarden-Unit 5859 XCTest (45 skipped) + 726 Swift Testing, 0 failures; Bitwarden-ViewInspector 604 executed (17 skipped), 0 failures; UI: `PassYLandingShotsTests` (1), `PassYFlowTests` 27 tests in one fresh-install run (893 s), `test_exportVault`, `test_shots`, `test_darkMode`, `test_largeText` (4), `test_registrationStart` alone after uninstall: all green.
- **Fix round after the validator (ui-r4 fixes)**: (1) the UI tests no longer depend on `test_shots`: `Scripts-passy/vaultwarden/seed_ciphers.py` now also creates the fixtures GitHub (with an authenticator key, so the "Verification codes" tile exists), Netflix and Bank (idempotent), and `test_shots` only adds them through the UI when missing. Proof: fresh database, `seed_account.py` + `seed_ciphers.py 25`, uninstall, `PassYFlowTests` complete in one run: 27 tests, 0 failures (1070 s). Run order for a clean run: seed scripts, uninstall, Landing, Flow, then the rest; `test27` dismisses the autofill set-up section, so it needs a fresh install. (2) `test26` also checks the Send add form; `test27` must see the set-up rows and dismiss them. (3) ViewInspector tests check title, message and actions of the `NativeSetupSection` per screen again and the label of the hint/SSO text field (604 executed, 17 skipped, 0 failures). (4) `s1-after-*-10/11-add-login` re-taken (the bottom shot now shows the scroll end). (5) `test_shots` took 4128 s in the validator run: not a regression of the app. With the machine quiet it takes 67 to 120 s; during our runs a Spotlight indexing burst (`mdwork`, load average 15 to 20) made every interaction wait 60 s for "App animations complete" (a test03 run reached only test03 after 3500 s and was stopped). Two real test flakes were fixed: the UI login now clears the password field before retyping (a mistyped attempt under load was appended on each retry and Vaultwarden answered "Username or password is incorrect"), and `test03` uses `focusSearch` (the first tap on the bottom search bar is sometimes ignored). Unit 5859 XCTest (45 skipped) + 726 Swift Testing, 0 failures, rerun after the fixes.
- UNVERIFIED / not done: login with device, set master password, 2FA email/recovery and PIN screens are converted (or already native) but have no screenshot (the test account has no device approval, SSO org or 2FA; the SSO screenshot shows the form under an "SSO sign-in is not available" alert); add forms for bank account, passport, driver's license and SSH key were not reachable in the add menu of this build, so only login, card, identity and secure note have shots (the code path is the same shared sections); iPad dark mode (the appearance switch had no effect on the iPad simulator, only light shots), iPad sidebar/landscape; Duo; XXXL/accessibility Dynamic Type only for the tiles (XL and AX-L shots), not for the new forms; VoiceOver; extensions (AutoFill/Share/Action) and Watch; Send in the Share extension (uses the same `AddEditSendItemView`, not run); `Bitwarden-Snapshot` (reference images out of date) and `PassYPerfTests` not run; no real iPhone; Apple Passwords similarity is subjective. Disclosure rows in the item "Additional options" and custom-field boolean rows were seen only in code, not in a screenshot.

## ui-r5 (branch `passy/ui-r5`, not merged)

Goal: look and behave like Apple's Passwords app. **Reference:** the real app (`com.apple.Passwords`) is installed in the iOS 27.0 simulator and was opened and screenshotted (`Docs/screenshots/ui-r5/ref/ref-*.png`: home light/dark, "All" list, item detail, item edit; sample data of the app). Our screens: `Docs/screenshots/ui-r5/before/` (state of ui-r4) and `after/` (this round), iPad in `ipad/` (light and dark, portrait and landscape), screens that the test account cannot reach in `screens/` (rendered by `PassYScreenTests`, see below).

| Deviation found (Apple Passwords vs ui-r4) | Fix in ui-r5 | Status |
|---|---|---|
| Home title centered, small, inline | Left-aligned large title (`prefersLargeTitles` on the vault navigator, `.large` on the home); avatar stays top right | fixed (test28) |
| Tiles: bold black count, grey bold name, 42 pt badge, 110 pt high | Count `.title2` secondary, name `.title3` primary, 36 pt badge, 12 pt padding, 20 pt corners, min height 96 | fixed (test21, test25) |
| Item detail: name and icon left in a row | Big centered 64 pt icon (rounded square) and centered title in the header card, no separator under it | fixed (test28) |
| Item rows: stacked label over value, grey label / black value | Item view and Send view (`readOnlyFieldStyle`): label black left, value grey right (stacked only if it does not fit and at accessibility sizes). The inline layout is limited to these read-only views (environment `isReadOnlyFieldStyle`), edit forms keep the stacked card rows | fixed (test28) |
| Logins without a website icon show a globe in a circle | First letter of the name on a grey rounded square (rows and item header) | fixed |
| Item list rows: circular/bare icon, regular title | 40 pt rounded-square icon with hairline, semibold title | fixed |
| List rows end with a chevron, "..." not shown | kept the "..." more button (many UI tests use `CipherOptionsButton`; replacing it needs a long-press context menu and a rewrite of those flows) | not done in ui-r5, done in ui-r6 |
| Group list nav title shows "N Items" as subtitle and a Select button | "Items (28)" section header kept; no Select mode | not done |
| iPad lists stretch across the whole window (Apple limits the reading width) | Vault home and group lists are limited to 760 pt and centered | fixed |
| Add menu with 7 types at AX-XXXL cut off "Login" (the menu opens upwards and scrolls; `test_largeText` failed in the validator run) | Order is now Login, Card, Identity, Secure note, then the new types, nearest to the button first (`passYAddMenuOrdered`) | fixed (`test_addMenuAccessibilityXXXL`, `test_largeText`) |
| Copy haptics | already present (`UINotificationFeedbackGenerator` on tap-to-copy, light impact on tiles) | present |
| Unlock with PIN | already a native `Form` (the earlier claim that it used cards was wrong; `screens/pinUnlock.*`) | no change needed |
| Tile count contrast and Dynamic Type of the avatar initials (accessibility audit) | count in primary at 70 %; avatar uses a text style and a `ScaledMetric` size (30 pt at the default size) | fixed; section header contrast not fixed |

- **B: previously unreachable screens.** The add forms for bank account, passport and driver's license are hidden by the server feature flag `pm-32009-new-item-types` (`VaultRepository.getItemTypesUserCanCreate`); Vaultwarden 1.37.5 started with `EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types` serves it, no app change. Shots (light/dark): `after/b-01..03-*-add-bank-account|passport|license`. The SSH key type cannot be created in the app at all (it is import only, `canCreateCases`), so its form is shown through the new snapshot-style test. Login with device, set master password, 2FA email and recovery code, PIN unlock and the SSH key form are rendered by `BitwardenShared/UI/Auth/PassYScreenTests.swift` (class `PassYScreenSnapshotTests`; it lives in the Unit target because in this fork the `BitwardenSharedSnapshotTests` target compiles no sources: `buildPhase: none` in `project-common.yml`, 0 tests executed). References are in `BitwardenShared/UI/Auth/__Snapshots__/PassYScreenTests/` (light and dark; the AX sizes are covered by the UI tests because a key-window render cannot draw the very tall accessibility sizes). Dynamic Type on the new forms: `after/b-*-xl|accessibilityl|accessibilityxxxl-add-bank|add-login`. iPad dark: the appearance cannot be switched from XCUITest on the iPad simulator; `xcrun simctl ui <udid> appearance dark` before the run works (script in the test comment). iPad landscape: the app screenshot of a rotated simulator is cropped, `XCUIScreen` shots are used and turned upright with `sips`. There is no sidebar on iPad since ui-r3 (avatar menu shell). VoiceOver: `test_voiceOverLabels` asserts labels and reading order of avatar, tiles, search field and add button and the avatar menu entries, and runs `performAccessibilityAudit` (home: contrast of counts/section headers, avatar and section header Dynamic Type; item view: Edit contrast and the unlabeled username value; findings are printed as `R5AUDIT`, not failing). The audit does not replace a real VoiceOver pass.
- **C: test27** now asserts that the action and dismiss are rows of the native list (not a card outside it), that Dismiss removes the section (`waitForDisappearance`) and that the dismissal persists after a relaunch (autofill page loads again without the section). The old always-true assert is gone.
- Tests: UI `PassYFlowTests` 28 tests (new test28; test21 minimum tile height is 96 again), `PassYUiR5ShotsTests` (compare, new type forms, Dynamic Type forms with hard asserts including AX-XXXL, add menu at AX-XXXL, VoiceOver, iPad shell); ViewInspector unchanged; Unit plus `PassYScreenTests` (6 tests).
- **Fix round after the first validator run (FAIL on `test_largeText`):** cause was a real product problem, not a flaky test: with the server flag on, the add menu has 7 types and at AX-XXXL the system menu scrolls, so the far entries (including Login, which was listed last, i.e. farthest from the button) were not reachable. Fixed in the product (menu order), not in the test. `test_dynamicTypeForms` no longer skips silently (`XCTAssertTrue(openAdd(...))`); `b-02-accessibilityxxxl-add-login` / `after/fix-r5-02-accessibilityxxxl-add-login.png` exist. Why the first run passed is not proven (probably the new-types flag was not loaded yet at that point, so the menu was shorter); on the validator's server it failed 2 of 2.
- Machine note: several UI runs happened while other sessions loaded the machine; results below were taken only with load average below 8 at the start (the runner scripts wait for it).

- **Results after the fix round (iPhone 17 Pro-class simulator "PassY-R3", iOS 27.0, Vaultwarden 1.37.5 with `EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types`, fresh DB seeded with `seed_account.py` + `seed_ciphers.py 25`, load average below 8 at each start):** Bitwarden-Unit 5865 XCTest (45 skipped) + 726 Swift Testing, 0 failures (the 2 SSH key snapshot references were re-recorded after the inline-row change was limited to read-only views; a rerun of `PassYScreenSnapshotTests` alone: 6 tests, 0 failures); Bitwarden-ViewInspector 604 executed (17 skipped), 0 failures; UI: `PassYLandingShotsTests` 1, `PassYFlowTests` 28 tests in one fresh-install run (880 s), 0 failures; `test_exportVault`, `test_shots`, `test_darkMode`, `test_largeText` and six `PassYUiR5ShotsTests` (10 tests), 0 failures; `test_registrationStart` alone after uninstall green; `test_ipadShell` light and dark on the iPad simulator green. `xcodebuild` hangs at the very end of some plan runs (0 percent CPU after the result line); such runs were ended by hand and the result was read from the log.
- **UNVERIFIED / not done (ui-r5):** a real iPhone and a real VoiceOver pass; extensions (AutoFill, Share, Action) and the Watch app; Duo; the `Bitwarden-Snapshot` plan (compiles no sources in this fork, 0 tests; the upstream snapshot tests are disabled with a `disabletest_` prefix and their references are stale); `PassYPerfTests`; the real "Log in with device", "Set master password" and 2FA screens inside the running app (the test account cannot reach them; only the rendered views in `screens/` exist, light and dark, no accessibility sizes); SSH key creation (the app cannot create that type); section-header contrast from the audit; list rows keep the "..." button instead of a chevron; no "N Items" subtitle and no Select mode in group lists; the Apple comparison is subjective and was made on one sample item; edit forms still use the stacked Bitwarden card rows for `BitwardenField`.

## ui-r6 (branch `passy/ui-r6`, not merged)

Goal: 1:1 Apple Passwords (pure SwiftUI, own SF Symbols, no upsell). Before shots: `Docs/screenshots/ui-r6/before/` (state of ui-r5); after shots (light/dark): `Docs/screenshots/ui-r6/after/` (`r6-01..03` rows/context menu/swipe, `r6-10/11` subtitle and Select, `r6-detail-*`, `12-*` item view taps, `r6-40..51` auth pages in the running app, `*-ipad-landscape-*`, `ipad-*-ipad-portrait-*`). Reference: `Docs/screenshots/ui-r5/ref/`.

| Deviation (Apple Passwords vs ui-r5) | Fix in ui-r6 | Status |
|---|---|---|
| "..." button in list rows | Disclosure chevron (`CipherDisclosureChevron`); options moved to a long-press context menu (copy actions, view, edit, archive, Delete) and trailing swipe actions (Delete red, More options grey). Identifier `CipherOptionsButton` is gone (UI tests did not depend on it except a fallback in test03) | fixed (`test_rowChevronContextMenuSwipe`, `test_swipeDelete`, VI tests) |
| No "N Items" subtitle, no Select | Group lists are a plain `List`; title with "N Items" subtitle (`navigationSubtitle`, iOS 26; older systems keep a section header), toolbar "Select" / "Done"; Select mode uses the system edit-mode checkmarks; actions: Delete (confirmation, soft delete, permanent inside the trash) and Move to folder (menu of folders incl. No Folder) | fixed (`test_selectModeDelete`, 3 unit tests) |
| Section header contrast (audit) | Home section headers and `SectionHeaderView` use label at 72-75 %; `R5AUDIT` no longer lists Favorites / No Folder / 28 | fixed for headers; "Login credentials" header in the item view still "nearly passed" |
| Item view: "View login" title, copy and eye icons, star, blue breach link | No title; tap a row copies (haptic + toast), long press offers Reveal/Hide and Copy; no eye/copy icons; favorite is a real toolbar star (`FavoriteToolbarButton`, toggles `favorite` through `updateCipher`); the breach check is a plain row with a shield symbol | fixed (test12 rewritten, VI tests rewritten, assertions kept) |
| Perf items showed a globe | Vaultwarden answers with its generic 19x19 px globe for unknown sites; the icon loader now treats that image as "no icon", so every login without a real favicon shows the letter on the grey square (list, item header) | fixed (`r6-list-*`) |
| Auth pages only as rendered views | Reached in the running app: password hint, SSO (the app answers "SSO sign-in is not available"), two-step login (authenticator, method sheet, recovery code) with a 2FA test account (`Scripts-passy/vaultwarden/enable_2fa.py`), Log in with device (offered after a log out, the server then knows the device) | reached (`r6-40..51`, light and dark) |
| iPad landscape shots were sideways | Rotation through `XCUIDevice.orientation`, real `simctl io screenshot` of the rotated screen at test-written markers (`test_ipadLandscapeHold` + `Scripts-passy/ipad_landscape_shots.sh`, no `sips`); list column measured at 760 pt (1520 px of 2420 px at 2x) | fixed; visually checked |

- Test seed for 2FA: `PASSY_EMAIL=passy-2fa@example.test seed_account.py`, then `enable_2fa.py` (test values only, throwaway local server).
- New tests: `PassYUiR6ShotsTests` (row chevron/context menu/swipe, Select delete, swipe delete, auth pages, 2FA, Log in with device after log out, iPad landscape hold), `VaultGroupProcessorTests` (delete, permanent delete in trash, move), VI tests for chevron/no "..." and for the login rows.
- Results (iPhone simulator PassY-R3 iOS 27.0, Vaultwarden 1.37.5 fresh DB, load below 8 at every start, one xcodebuild at a time): Bitwarden-Unit full run 5865 XCTest (45 skipped) + 726 Swift Testing, 0 failures (taken before the 3 new processor tests were added; `VaultGroupProcessorTests` alone, 53 tests incl. the 3 new, green afterwards; no full unit rerun after that); ViewInspector 604 executed, 0 failures after adapting 5 tests; UI: `PassYLandingShotsTests` 1, `PassYFlowTests` 28 tests in one fresh run, 0 failures; `PassYShotsTests`, `PassYZAppearanceTests` (dark, large text), `test_exportVault`, `PassYUiR5ShotsTests` (6 tests incl. `test_ipadShell` on the iPhone), three R6 list tests, 13 tests in total, 0 failures; `test_registrationStart` alone after uninstall green; R6 auth tests (2FA light/dark, auth pages light/dark, Log in with device light/dark) green; `test_ipadShell` light and dark on the iPad simulator and `test_ipadLandscapeHold` light and dark green. After the last small edits (header contrast, breach row) only test03, test12, test28 and `test_voiceOverLabels` were rerun (green); the full Flow/rest runs are from the commit before.
- **UNVERIFIED / not done (ui-r6):** a real iPhone and a real VoiceOver pass; extensions, Watch, Duo; `Bitwarden-Snapshot` plan (0 tests) and `PassYPerfTests`; SSO login (the app blocks it), Set master password and the master password change screens (the test account never needs them; only the rendered views from ui-r5 exist); email 2FA (Vaultwarden has no SMTP in the test setup); home-screen search rows keep a context menu but no Delete (only group lists have delete/select); no multi-select on the home list; no Move to Folder in the context menu; `navigationSubtitle` needs iOS 26 (earlier systems show a section header instead; not run, no such runtime); the iPad list is a white column on grey sides, not checked against a real Apple Passwords iPad; the audit still reports the avatar "PT" and three unlabeled elements as contrast failures, "Login credentials" as nearly passed and "Check password for data breaches" as clipped at the audit's large size (not fixed); auth pages (login, 2FA, Log in with device) are still the white-card Bitwarden layout, not Apple look; edit forms still use stacked Bitwarden rows; the Apple comparison is subjective.
- Machine note: `xcodebuild` hangs at 0 % CPU after the result at the end of most runs; the runner scripts end it after the result bundle (`Info.plist`) exists.

## ui-r7 (branch `passy/ui-r7`, not merged)

Goal: 1:1 Apple Passwords (pure SwiftUI, own SF Symbols, no upsell). Shots (light/dark): `Docs/screenshots/ui-r7/after/` (`r7-01..11` add/edit forms, `r7-*-search-*` home search, `r7-40..51` auth pages, `*-ipad-*`), "before" = the ui-r5/ui-r6 screens that were not touched in between: `Docs/screenshots/ui-r7/before/` (`r6-40..51` auth, `c-04-*-edit`, `b-0*-add-*`). There is no "before" for home search Select/Delete (the feature did not exist).

| Deviation (Apple Passwords vs ui-r6) | Fix in ui-r7 | Status |
|---|---|---|
| Edit/add rows stacked: small bold label above the value (Bitwarden) | In a native `Form`, `BitwardenTextField` (via `BitwardenFloatingTextLabel`), `BitwardenField` and `BitwardenMenuField` are Apple rows: grey label left, value right-aligned, picker with the up/down chevron; stacked again only at accessibility text sizes. Applies to login, card, identity, secure note, bank account, passport, license, SSH key, custom fields, URI, folder/owner pickers | fixed (`test_addEditFormsAreInlineRows`, test03) |
| "New custom field" outlined capsule button | Plain blue row with a plus, like "Add website" | fixed |
| Auth pages "white Bitwarden cards" | Honest finding: Login, 2FA (all methods), Log in with device, Unlock, Landing, Server settings, Registration, Password hint, SSO and Set master password were already native `Form`s since earlier rounds; the white rounded groups are the system inset-grouped style (same as Apple Passwords). New in ui-r7: Update master password and Remove master password (key connector) converted from card stacks to `Form`s. Login with device/Unlock biometric/PIN unchanged | partly fixed, see UNVERIFIED |
| Home search results: no Delete, no Select | Context menu "Delete" (confirmation, soft delete), trailing swipe Delete + More options, toolbar Select/Done with Move and Delete (same shared `CipherBulkActions` as the group lists) | fixed (`test_homeSearchSelectDelete`, 5 processor tests) |
| Accessibility audit: avatar "PT" contrast, section header "Login credentials", "Check password for data breaches" clipped | Avatar: initials white on a darkened account color; native form section headers label 72 %; breach row is an HStack that wraps (no clipping); darker badges for the light tile colors | code changed for these three; **not shown by an audit run**: the earlier "home 7 -> 6, item 6 -> 4" numbers are withdrawn (their logs were lost and the vault state differed). Same-server before/after runs (`Docs/audit/`, `f4567dce6` vs HEAD) both give home 2, item 2 findings (`test_voiceOverLabels` asserts the three fixed ones do not come back) |
| Delete when `fetchCipher` fails showed "deleted" | Every id is tried alone (`CipherBulkActions`), failures give an error alert with the count and no success toast; failed items stay selected, Select mode stays; processed items leave the selection | fixed (unit tests) |
| Cancelling the delete confirmation ended Select mode | Selection lives in the state; only a complete successful action ends Select mode | fixed (unit test) |
| "N Items" subtitle only on iOS 26 | Before iOS 26 the count is a plain secondary text row at the top of the list (`ItemCountHeader`), same text | fixed (2 ViewInspector tests with `supportsNavigationSubtitle` false/true; not run on a real iOS < 26) |
| Icon loader dropped every 19x19 icon | Only the exact Vaultwarden placeholder (SHA-256 of the 483-byte globe PNG, fetched from `/icons/<unknown>/icon.png` of 1.37.5) is "no icon"; a real 19x19 favicon is kept. Limit: another server version with a different placeholder file would show its globe until its hash is added to `vaultwardenPlaceholderSHA256s` | fixed (3 tests incl. a generated 19x19 PNG) |

- Verdict weaknesses of ui-r6: (a) the permanent-delete test now asserts `deletedCipher == ["7"]`; (b) new unit tests for `toggleFavoritePressed` (set, unset, error, not loaded) and `CipherIconImageLoader.decodeIcon`; (c)-(e) see the table.
- Auth tests that need a new `Localizations` string: `SomeItemsCouldNotBeDeleted`, `SomeItemsCouldNotBeMoved`.
- Snapshot references of `PassYScreenSnapshotTests` (SSH key form, set master password) were re-recorded because the rows changed (`TEST_RUNNER_SNAPSHOT_TESTING_RECORD=failed`).
- test03 appends " Edited" to the name; edit fields are right-aligned now, so the test taps the trailing edge of the field first (a tap in the middle puts the caret in the middle of the text). Assertions unchanged.
- **Results (iPhone simulator PassY-R3 iOS 27.0, iPad PassY-iPad-R5, Vaultwarden 1.37.5 fresh DB `/tmp/vw-data-r7`, one xcodebuild at a time, gate load < 8 at each start; the machine was loaded by other sessions during parts of the Flow and test03 runs, see below):** Bitwarden-Unit 5885 XCTest (45 skipped) + 729 Swift Testing, 0 failures (full run after the last source change); Bitwarden-ViewInspector 606 executed (17 skipped), 0 failures; UI: `PassYLandingShotsTests` 1 green; `PassYFlowTests` fresh install: 28 tests, 27 green and `test03` failed ("edit saved": caret in the middle of the right-aligned field, test fixed as described above), `test03` alone after the fix: green (not a full Flow rerun); rest (fresh install: `PassYShotsTests`, `PassYZAppearanceTests`, `PassYUiR5ShotsTests` 6, R6 list tests 3, `PassYUiR7ShotsTests` 2, `test_exportVault`) 15 tests, 0 failures; `test_registrationStart` alone after uninstall green; R6 auth tests each after an uninstall: authPages light/dark, 2FA light, Log in with device light/dark green; **2FA dark failed twice** at the master password step of the 2FA test account ("Username or password is incorrect", a typed password was rejected, shot `after/r7-44-dark-2fa-FAILED-password-rejected.png`); the same code passed in light mode and in ui-r6 dark, cause not found (two attempts, stopped); iPad: `test_ipadShell` light/dark and `test_ipadLandscapeHold` light/dark green.
- **UNVERIFIED / not done (ui-r7):** a real iPhone and VoiceOver; extensions, Watch, Duo; `Bitwarden-Snapshot` (0 tests) and `PassYPerfTests`; the 2FA dark screen in this round (see above; ui-r6 has it); email 2FA (no SMTP), SSO (the app blocks it), LoginDecryptionOptions (not converted, unreachable), biometric unlock; Update/Remove master password screens are converted but only compile- and VI-checked, never seen in a screenshot; Set master password only as the re-recorded snapshot; the remaining audit findings: three contrast failures on elements the audit does not name (frame zero, `SwiftUI.AccessibilityNode`; my guess is the favorite row that scrolls under the translucent bottom bar, not verified), "Dynamic Type partially unsupported" for the list section header `Favorites`/count, the avatar initials and the system Edit button, "Check password" at the audit's large size, "Label not human-readable" for the username value (test data email), "Edit" button contrast nearly passed; the masked password row in the edit screenshots shows no dots (also in ui-r5), not investigated; Move to folder on the home search results has a processor test but no UI test; the iOS < 26 item-count row is only checked with ViewInspector, no such runtime; no full second Flow run after the test03 change; the Apple comparison is subjective; the "before" images for the forms and auth pages are the ui-r5/ui-r6 shots, not rebuilt from the previous commit.


### ui-r7 fix round (after the validator FAIL, `Docs/verdicts/2026-11-16-ui-r7.md`)

- **Edit form, name row:** the item name is a free field without the "Item name (required)" label (that text is its placeholder; `nativeTitleAsPlaceholder()`), so long names are no longer cut by a label. `test_addEditFormsAreInlineRows` now checks the inline layout on the username row and that the name field starts at the leading edge.
- **Password row "shows nothing":** checked without a server through new light/dark renders (`Docs/screenshots/ui-r7/render/`, `PassYItemFormSnapshotTests`, 20 tests): the value is in the field (`editLoginRevealed` shows `x1y2z3`). The masked field is blank in every capture, also in the ui-r6 reference snapshot of the set-master-password screen (`git show f4567dce6:...test_snapshot_setMasterPassword.portrait.png`), so it is not an ui-r7 layout regression; whether the dots are only missing from simulator/snapshot captures (iOS does not draw secure-field content into them) or also on screen is **not proven**. `test_editFormPasswordMaskedAndRevealed` (bullet count of the secure field equals the password length, eye shows the value) was written for this and **has not been run** (needs the server).
- **Renders of all item types** (add and edit: login, card, identity, secure note, SSH key, bank account, passport, driver's license) and of Update and Remove master password, light and dark, in `Docs/screenshots/ui-r7/render/`. These are SwiftUI renders in the unit target, not running-app screenshots.
- **`performDelete` with only non-cipher rows** (no ids) no longer shows the success toast (group list and home search, 2 unit tests).
- **Scripts outside `/tmp`:** `Scripts-passy/env.sh` (paths in `~/Library/Caches/passy-vw/`, load gate, hung-`xcodebuild` handling), `run_plan.sh`, `run_ui.sh`, `export_shots.sh`, `vaultwarden/run_local.sh` (port 8088, rate limit env, `pm-32009-new-item-types`, `--fresh` wipes the data dir). DerivedData: `~/Library/Caches/passy-vw/dd`.
- **Server runs (Vaultwarden 1.37.5 from `~/Library/Caches/passy-vw/src`, a checkout of tag 1.37.5 of the official repo; the binary was built by another agent, so its provenance is not verified by me).** The machine was loaded by foreign processes the whole time (1-minute load up to 178, 5-minute load 40 to 140 while tests ran; the runner gate only checks the load at the start). Results below are therefore weak evidence:
  - Landing green. Flow (fresh install, 28 tests): 27 green, `test08` red after a 1325 s stall under load, green when run alone. Rest (17 tests): `test_rowChevronContextMenuSwipe` red because the first login row was one of my own test items without a username (no "Copy username"), see "test hygiene"; the two new password/edit-type tests red (below); the others green. `test_registrationStart` green. Auth hell/dunkel green. Log in with device hell/dunkel green. iPad shell/landscape and the audit before/after were run, iPad shell/landscape of the earlier ui-r7 run stays the reference (not repeated).
  - **2FA hell/dunkel: not clarified.** In the main chain: light red, dark green, dark again red. The reds were once "Username or password is incorrect" for `passy-2fa@example.test` (Vaultwarden log line, 10:27:58: the app sent a wrong password) and otherwise "Log in" not found right after the uninstall; reruns (also after `simctl keychain reset`) all failed at "Log in" not found. The server log shows a refresh-token error ("InvalidSignature") from the app after the DB had been recreated, i.e. app state survives `simctl uninstall` (probably the app group container; the keychain reset did not help). I did not erase the simulator because that would also drop its keyboard settings. Treat the 2FA tests as flaky/state dependent, not as passing and not as a proven product bug.
  - **Audit before/after (same server, same test, logs in `Docs/audit/`):** before (ui-r6 worktree `f4567dce6`) home 2 findings, item 2 findings; after (ui-r7 HEAD) home 2, item 2, identical (Dynamic Type for the avatar "PT" and the Edit button, contrast of the "Trash" tile label and of Edit). **So no improvement of the audit result is shown in this state**; the earlier "7 -> 6 / 6 -> 4" numbers came from an older vault state and are withdrawn. Whether the avatar contrast, header and breach row fixes work is only supported by code, not by an audit run.
- **2FA instability explained (second server round):** on a dedicated, freshly erased simulator (`PassY-2FA`, `PASSY_ERASE=1` in `Scripts-passy/run_ui.sh`) the 2FA tests ran light -> dark -> dark again, all green (start loads 22 to 23, then 60 to 75 on the 5-minute average). Earlier reds had two causes: (a) app state survives `simctl uninstall` and `simctl keychain reset` in the simulator (the app then starts on another screen, "Log in" not found; the Vaultwarden log even showed a refresh-token error from a previous server DB), fixed for the tests by erasing the dedicated simulator (and re-applying the English QWERTY keyboard defaults); (b) a masked-field typing slip for the 2FA account ("Username or password is incorrect" in the Vaultwarden log), avoided by typing the master password into the revealed field in `test_auth2FAScreens`. Landing on the erased simulator: green.
- **Password typing finding (simulator artefact, device OK for typing, saving on the device UNVERIFIED):** in the iOS 27.0 simulator the secure password field of the add/edit login form keeps only the last typed character (`test_secureFieldTypingDiagnostic`: 1 bullet after each key of "abcdef", 1 after `typeText("ghijkl")`; the saved password read back as `t`). It reproduces at `f4567dce6`, so it is not caused by ui-r7. A device run (iPhone Air, build `7746d84d1`, same diagnostic test, artefacts in `~/Library/Caches/passy-devtest-out/`) showed 1..6 bullets for the slow "abcdef" and 12 after `typeText("ghijkl")`: on the device the field keeps every character. That the effect is specific to the simulator is therefore likely but not proven, and **no cause is claimed**; the measurement below is all there is. **Saving a typed password on the device is not verified** (the app was on its PIN/Face ID lock). The username field and the plain master-password `SecureField` of the login screen are not affected in the simulator. Tried without effect: `clearsOnBeginEditing`/`clearsOnInsertion` false through introspection; variants without `.id(title)`, without the row `onTapGesture`, without the two `.focused` modifiers, and a binding straight to `$text`. The diagnostic tests are skipped unless `PASSY_KNOWN_ISSUE_TESTS=1`.
- **Other secure fields (code review, not run):** every secure field of the add/edit forms (login password and authenticator key, card number and code, identity SSN and passport/license number, bank account number/PIN/IBAN, passport and license numbers, SSH key, hidden custom fields, Send password) is the same `BitwardenTextField` with its single `SecureField` at `BitwardenKit/.../BitwardenTextField.swift:206`, so they share the susceptibility in the simulator. The plain `SecureField`s (login, unlock, registration, self-hosted dialog, export) are separate code and were not seen to fail.
- **UI-test workaround (no product change):** `test_loginPasswordSaveAndRevealRoundTrip` types the password into the revealed (plain) field, masks it again, saves, reopens, and compares: masked bullet count equals the length of `Sup3rSecret-2026!` and the revealed value equals the typed text; then it appends "+edit" to the existing item, saves, reopens and compares again, and deletes its item. **Written, not yet run** (the machine was too loaded).
- **Password typing finding, measurement (later the same day):** an instrumented build (diagnostic code, not committed; kept outside the repo) counted the UIKit events of the secure field while `typeText` typed "abcdef" into the add form: one `textDidBeginEditing`, no `textDidEndEditing`, always the same `UITextField` instance, but per key several `textDidChange` events with the text length going `1, 1` after the first key and `1, 0, 1` after each further key, and about 6 SwiftUI updates of the field per key. So the field is not re-focused and not re-created; UIKit **clears the secure field on every insertion** after an extra programmatic-looking change event that follows each insertion (the known secure-field behaviour: text set while editing arms clear-on-next-insertion). What sets the text after each key is **not found**. Untested candidates: `.textFieldConfiguration(.password)` (content type `.password` with a username field above it, iOS Password AutoFill), `.styleGuide(.bodyMonospaced)` on the secure field, the empty `SecureField("")` title. Further runs were not possible: the machine was saturated by foreign processes (1-minute load 150 to 820, a second simulator runtime busy) and the test gate never opened or the UI queries timed out. No product change was made for this finding.
- **Fix round 3 (quiet-ish machine, gate 1-minute load < 25, dedicated erased simulator `PassY-2FA` for fresh-install runs, loads in the logs under `~/Library/Caches/passy-vw/out/`):**
  - Unit 5909 XCTest (45 skipped) + 729 Swift Testing, 0 failures (`g_unit`); ViewInspector 606 (17 skipped), 0 failures (`g_vi`, rerun `j_vi` after the list changes).
  - Landing green; `test_registrationStart` green; Auth hell/dunkel green; Log in with device hell/dunkel green; 2FA hell -> dunkel -> dunkel again green; iPad shell hell/dunkel and landscape hell/dunkel green; round-trip password test (`test_loginPasswordSaveAndRevealRoundTrip`, start load 2.3) green: a 17-character password typed through the revealed field is saved, reopened with 17 bullets, revealed identically, "+edit" appended, saved, reopened and compared, item deleted.
  - Flow 28 fresh: 27 green, `test23` red under load ("Could not reach the vault list"), green alone (start load 22.6). Rest (15 tests): 13 green, 2 red, both fixed afterwards: (1) `test_voiceOverLabels` found "Contrast failed [PT]" for the avatar on that account color (the fixed 30 % overlay was not enough for every color) -> the overlay is now computed per color for a 4.6:1 ratio (`PassYAvatarContrastTests`, 2 unit tests; audit rerun green, `PT` no longer a contrast finding); (2) **`test_homeSearchSelectDelete` crashed the app** ("Invalid number of items in section" inside SwiftUI's list diff, reproducible three times on the erased simulator, found by this run, caused by the new Select/Delete on the home search list) -> the search list is rebuilt when its result rows change (`.id` of the row ids) and the edit-mode exit is delayed; test green twice afterwards, group `test_selectModeDelete` and `test_swipeDelete` green, `test_rowChevronContextMenuSwipe` green on a rerun (red once under load, first row at that time was a leftover test item).
  - Audit: at HEAD on the erased simulator home has 6 findings (three contrast findings on unnamed nodes, Dynamic Type for Favorites/count/avatar) and the item view 6; this state (leftover items, favorites row) is **not comparable** with the earlier 2/2 runs, so no before/after claim is made (`Docs/audit/`).
  - **Not done:** app screenshots of the edit forms of the other item types (the collecting test `test_editFormOfEveryType` is still unreliable and gated); a second like-for-like audit run of the old tree on the erased simulator; the password typing finding stays a simulator artefact with UNVERIFIED saving on a device; a real iPhone/VoiceOver pass.
- **Test hygiene:** `test_editFormOfEveryType` (app screenshots of every type's edit form) only got light shots for Login and Card (and Identity in one run): from the third item on the Edit button is not found after opening the item from the search results; it creates items without a username that broke `test_rowChevronContextMenuSwipe`, so it is also behind `PASSY_KNOWN_ISSUE_TESTS=1`. App screenshots of the edit forms of the other types, light and dark, therefore do **not** exist; the renders in `Docs/screenshots/ui-r7/render/` stand in for them. `Scripts-passy/run_ui.sh` now also runs `simctl keychain reset` after an uninstall.
- Results of this round: Bitwarden-Unit 5907 XCTest (45 skipped) + 729 Swift Testing, 0 failures; Bitwarden-ViewInspector 606 executed (17 skipped), 0 failures. The new UI test `test_editFormPasswordMaskedAndRevealed` and the changed `test_addEditFormsAreInlineRows` compile but were not run.

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
Home screen on the simulator (light / dark system appearance; the springboard only switches to the dark icon variant when the user selects the Dark icon style, so both shots show the default variant; the dark and tinted variants are in `Branding/icons-preview.png`):

![home light](Docs/screenshots/logo-home-light.png) ![home dark](Docs/screenshots/logo-home-dark.png)


A "P" cut like a key: a stem with two key teeth and an open bowl; flat, black and white only (light: black on white, dark: inverted, tinted: grayscale mask). The source is vector
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
- **G1b (done): Unlock** (master password or PIN) is a native `Form` too: ![unlock](Docs/screenshots/g1b-unlock.png)
- **G2-lite (done): vault list rows** use SF Symbols (ellipsis, copy), 44 pt targets and pointer hover; the vault list ViewInspector tests were updated for category tiles vs folder rows. The list itself is still the custom tile + lazy rows layout, not a `List`.
- Not yet rewritten: two-step login, registration screens, vault list/search, item view/edit, generator, send, settings, folders/collections,
  import/export, extensions, and the UIKit coordinators (NavigationStack/NavigationSplitView).

## Audit of the remaining screens (G3 to G10)

After G1 to G2 the remaining groups were audited on the iPhone 17 Pro simulator in dark mode instead of being rewritten blindly:
![settings](Docs/screenshots/audit-settings-dark.png) ![add login](Docs/screenshots/audit-add-login-dark.png)
![generator](Docs/screenshots/audit-generator-dark.png) ![vault](Docs/screenshots/audit-vault-home-dark.png)

Findings: with the system palette, system fonts and tile home from M1, the item add/edit/detail screens (inset grouped cards with section headers),
settings (icon rows with chevrons in a rounded group), generator and vault already follow the Apple look. What is **not** native is structural:
the screens are assembled from Bitwarden's custom field/card components (`BitwardenField`, `ContentBlock`, `SettingsListItem` ...) instead of `Form`/`List`, the vault
list is a custom lazy stack instead of `List`, and navigation is owned by 22 UIKit coordinators. Replacing them is a rewrite of about 100 view files plus the
navigation layer and the matching ViewInspector/snapshot/coordinator tests; it was not started because it would change structure, not appearance,
and cannot be done incrementally without a second navigation layer. Status: **G3 to G9 audited (visual parity accepted, structural rewrite not done),
G10 (NavigationStack/NavigationSplitView replacing the coordinators) not done**, G11 legacy points unchanged (Mac window/menu, watch sync/complication,
Duo poses: UNVERIFIED as described above).

## Step B: vault list as a real `List`

The vault contents are now a native inset-grouped `List` (action card, vault filter, category tiles row, one collapsible `Section` per group, "More" swipe action
on cipher rows, pointer hover on rows) instead of a custom scroll view with a lazy stack. Items still come from the unchanged `VaultListProcessor`; the search
results screen still uses the previous lazy stack. The wide two-column sidebar layout of Round 4 was dropped in favor of the system list on iPad.
![vault list dark](Docs/screenshots/stepb-vault-list-dark.png)
Tests: vault list and row ViewInspector tests (37 executed, 3 skipped, 0 failures), UI tests test02/03/04/07 green (test07 once failed in a combined run and passed alone).

**Step B2:** the search results are a `List` as well. This exposed a bug in the first List version: a row with several default-style buttons fires all of them on one tap (opening the item and the More menu together). The row buttons now use `.plain` style so only the tapped action fires; `test03_createSearchEditDelete` (create, search, edit, delete) is green again.

**Step A (thin native shell):** on iOS 18+ the root `BitwardenTabBarController` uses `UITab` with `.tabSidebar` (floating tab bar on iPhone, sidebar toggle on iPad/Mac). Only this shell is native; the coordinators and navigation stacks inside the tabs are still UIKit (`UINavigationController`), so a full `NavigationStack`/`NavigationSplitView` replacement is not done. Before iOS 18 the classic `viewControllers` path remains (not run, no such runtime installed). Tests: 5855 XCTest + 724 Swift Testing green.
**Step C1 (generator):** the generator screen is a native `Form` (`GeneratorView` plus the shared field views in `BitwardenKit`: native `Slider`, `Stepper`, `Toggle`, menu `Picker`, `TextField`). Same Store/Processor and accessibility identifiers. Removed from this screen: the "explore the generator" guided-tour card, the premium card and the tour spotlights (Bitwarden onboarding, no longer reachable). The Password/Passphrase/Username switch is now a native segmented `Picker` (the old custom control is only kept when a policy disables a type); in dark mode the selected segment is the accent blue on the system gray, readable but not high contrast.
![generator segmented dark](Docs/screenshots/generator-segment-dark.png)
![generator light](Docs/screenshots/stepc-generator-light.png) ![generator dark](Docs/screenshots/stepc-generator-dark.png)
Tests: Bitwarden-Unit 5855 XCTest + 724 Swift Testing green; ViewInspector 609 executed, 0 failures after adapting the generator tests (menu/slider/stepper finders) and skipping `StartRegistrationViewTests.test_regionButton_tap` (failed before this change: the region selector in a text field footer is not reachable via ViewInspector).

**Step C2a (settings root):** the top-level Settings screen is a native `List(.insetGrouped)` with SF Symbols (premium card removed; plan row still conditional). Identifiers unchanged; ViewInspector 609 executed, 0 failures. The sub-screens (account security, autofill, vault, other, about, appearance) are still the previous Bitwarden-style views.
![settings light](Docs/screenshots/stepc-settings-light.png) ![settings dark](Docs/screenshots/stepc-settings-dark.png)

**Step C2b (icon set):** all ~85 remaining Bitwarden line icons in `BitwardenResources/Icons.xcassets` were regenerated from SF Symbols (`Scripts-passy/generate_sf_icons.swift`; template PDFs that embed a 12x raster of the glyph, not vector paths; same asset names, so every screen picks them up). This is a visual unification, not a structural rewrite.
![icons](Docs/screenshots/stepc-icons-home-light.png)
**Not rewritten as native List/Form (honest status):** item view/edit (all types), send, folders/collections, import/export, registration/2FA and the settings sub-screens still use the shared `ContentBlock`/`BitwardenField`/`SectionView` building blocks in system colors and fonts, hosted in UIKit coordinators. Step D/E (extensions, watch sync, Mac, Duo poses) were not extended beyond the earlier rounds.

**Step N1 (Apple-Passwords-style navigation):** the vault screen's top bar holds only a profile button that opens a native menu (accounts, add account, sync, lock, settings; `VaultProfileMenuView`). Search and the new-item menu sit in a floating bottom bar above the tab bar (`VaultBottomBar`: native `UISearchBar` + `+` menu with an SF Symbol per item type and Folder; glass on iOS 26, material before). Settings sub-screens and the settings account row are not done yet.
![vault light](Docs/screenshots/nav-home-light.png) ![vault dark](Docs/screenshots/nav-home-dark.png)
Fixed on the way: switching light/dark crashed the app (`BitwardenTabBarController` re-created its `UITab`s, UIKit asserts; found via the crash log, now updated in place + unit test); `seed_ciphers.py` needed the `Bitwarden-Client-Version` header for current Vaultwarden. UI test03 now opens the hit straight from the search results (Cancel closes the search and the item is then below the fold of the main list). Unit 5855 XCTest + 725 Swift Testing green, ViewInspector 607 executed/0 failures, UI flow test01-07 + perf + dark/large text green (test04/test07 failed once in the combined run with "could not reach the vault list" and passed when run alone: flaky after test03 with a 2000-item vault).

**Step N2 (settings account row, bottom bar fade):** the top of Settings has an Apple-ID-style account row (avatar, e-mail, menu to switch account, lock now, log out; add account stays in the vault profile menu). The vault list now fades out behind the floating bottom bar (solid background with a short gradient above, plus the iOS 26 soft scroll edge) so rows no longer shine through the glass or show between bar and tab bar.
![settings account light](Docs/screenshots/settings-account-light.png) ![settings account dark](Docs/screenshots/settings-account-dark.png) ![vault fade](Docs/screenshots/nav-home-fade-light.png)

**Step N3 (item view polish, search state):** the item view has a bold large title; tapping the username or password row copies it (with haptic), in addition to the copy icons. Fixed a bug found by the UI test: after opening a search result, UIKit ended editing in the bottom search bar while the app still thought it was editing, so the `+` button stayed hidden; the bar now follows `searchBarTextDidEndEditing` and keeps its cancel button while text is present. The item view is still the shared card layout (not a `List`/`Form`).
![item light](Docs/screenshots/item-view-light.png) ![item dark](Docs/screenshots/item-view-dark.png)

**Step N4 (iPad and large text):** the vault screen was checked on iPad (top tab bar + sidebar toggle, categories in one row, bottom search bar spanning the width) and at the accessibility XXXL text size. Two real bugs found and fixed: (1) the `+` button's tap target was only its 18 pt symbol, so on iPad a tap went through to the list row underneath and opened that row's menu instead of the add menu; it now has a full 44 pt circular hit area and the bar swallows touches in its whole area (new UI test `test08_addMenuOpensWithEntries`, green on iPhone and iPad, asserts the entries Login/Card/Identity/Folder and a full-size tap target); (2) at XXXL the search text and plus outgrew their capsules, so the bar now stops scaling at `xxxLarge` like system toolbars. UI test helper `tapNewLoginMenuItem` picks the menu entry instead of the same-named category tile.
![add menu iPad](Docs/screenshots/add-menu-ipad.png) ![add menu iPhone](Docs/screenshots/add-menu-iphone.png)
![vault iPad](Docs/screenshots/vault-ipad.png) ![vault XXXL](Docs/screenshots/vault-xxxl.png)

**Step N5 (full run on main, tap evidence, search-bar hardening):** full run on a fresh environment (Unit 5859 XCTest + 725 Swift Testing, ViewInspector 608, Kit-Unit, UI flow test01-10, 12, 13 (test11 was removed, see known issue) + perf + dark/large text). Real tap evidence by UI test: item view (`test12`: the eye reveals the password; the copy icon and tapping the row each show the "copied" toast) and Settings (`test13`: the account row shows the e-mail, its menu offers Lock now / Log out, Log out asks for confirmation and Cancel keeps the session). Search bar fixes found by the tests: the cancel X no longer leaves the field focused (UIKit re-activated it after the tap), editing state is reset and the keyboard closed when the vault tab disappears, and the settings screen "Other" is now a native `Form` with native switches (the shared `BitwardenToggle` uses the system switch). Known, not fixed: after opening a search result and switching to another tab and back, a keyboard without caret can stay visible until the X is tapped once (one tap restores the vault; the UI test `test_shots` covers that path); an attempt to clear the search when leaving the tab made the vault stay in search mode and was reverted. Intermittent: the Unit plan crashed once in `CombinedSingleAutofillVaultListDirectorStrategyTests` on the first run after a fresh DerivedData/simulator and passed on rerun (the test also passes alone).

**Step N6 (forms):** Add/Edit item is a native `Form` (each card block is a transparent form row; the "learn about new logins" tour card and its two tests are gone), Folders is an `insetGrouped` `List` with folder symbols and chevrons, Appearance is a `Form` (language row, theme `Picker`, website icons switch with its help button), Other was already a `Form`. Real taps: `test14_settingsSubscreens` opens Appearance (theme menu offers Dark, selects it and switches back), Other (Sync now exists), Vault settings and the Folders list; `test03` creates/searches/edits/deletes through the new Add/Edit form. Screenshots light/dark: `Docs/screenshots/settings-*.png`. Not yet native (UNVERIFIED/not done): Send list and add/edit, Import/Export, Registration/2FA, Account security, Autofill, Vault settings list, About; Step D/E.
![appearance light](Docs/screenshots/settings-appearance-light.png) ![other dark](Docs/screenshots/settings-other-dark.png) ![folders light](Docs/screenshots/settings-folders-light.png)

**Step N7 (Send list, settings rows):** the Send list is a native `insetGrouped` `List` (sections with counts, rows with plain button style so a tap fires only one action, the premium upsell card removed). UI test `test15` taps through Send tab -> add menu (Text/File) -> add form; the populated list is NOT verified (no sends exist in the test vault) and the empty Send state still shows the Bitwarden illustration with the search bar at the top. `SettingsListItem` (Vault settings, About, Account security, Autofill, Export) shows a native gray chevron on plain navigation rows. Add form dark mode: the card background fix keeps field cards visible in the dark sheet. UNVERIFIED / not done: Send add/edit as `Form` (only opens), Import/Export screens, Registration/2FA, Account security, Autofill and About as native forms, Step D (extensions, widgets, watch) and Step E (Mac window, Duo).
![send add menu](Docs/screenshots/send-add-menu-light.png) ![vault settings](Docs/screenshots/settings-vault-settings-light.png) ![add dark](Docs/screenshots/add-form-dark.png)

**Step D/E status (honest):** the signed device build (`de.aiity.passy`, team H8FW6W6K2D) embeds the Action, AutoFill, Share and Notification extensions and the Watch app (`Bitwarden.app/PlugIns`, `Bitwarden.app/Watch`) and compiles with the Pass-Y icons and branding; none of them was run or screenshotted in this round (extensions need the system sheets, the watch needs a paired watch simulator, and Mac "Designed for iPad" cannot launch the iOS binary here: `open` fails with "incorrect executable format"). Duo poses and the widget/complication behavior stay UNVERIFIED. Screens still in the old shared-card style: Import/Export, Registration/2FA, Account security, Autofill, About.

**Step N8 (Send, Folders, Mac attempt):** Send now has the same bottom bar as the vault (native search field + add menu with Text/File, glass on iOS 26) instead of the top search and floating button, a native-style empty state (SF Symbol, title, text, button instead of the Bitwarden illustration) and a native filled list. Found and fixed by UI tests: the section headers printed `Optional("Types")` (optional interpolated), and the last folder row sat under the add button after the List conversion (restored bottom inset). Tests: `test16_createSendAndShowList` (creates a send by real taps, restarts, shows the filled list, checks plain headers), `test17_foldersListLastRowClearOfAddButton` (creates 12 folders by taps, scrolls to the end, asserts the last row ends above the add button), SendBottomBar ViewInspector tests replace the old FAB tests. After saving a send the system share sheet for its link opens (app behavior); UI tests relaunch instead of dismissing it.
![send list](Docs/screenshots/send-list-filled-light.png) ![send dark](Docs/screenshots/send-list-filled-dark.png) ![folders end](Docs/screenshots/folders-end-light.png)
The new Send empty state (SF Symbol paperplane instead of the illustration) is UNVERIFIED by screenshot: the test vault already contains sends, and `send-add-menu-light.png` in `Docs/screenshots` is from the earlier state (old illustration, top search bar).
Mac window screenshot: UNVERIFIED. `My Mac (Designed for iPad)` builds, but UI tests are not supported on that destination ("UI tests are not supported on My Mac (Designed for iPad)") and `open` on the built product fails with "incorrect executable format"; no Mac Catalyst target exists in this project.

Not done: Cmd+F runtime check, full SwiftUI navigation (coordinator replacement), no UI regression test for tapping a row of the main (non-search) list yet.

## Settings-Untermenues + Step D/E (settings-de)

**Account security, Autofill, About** are native `Form`s now (inset grouped, SF Symbols, system colors/fonts, red destructive rows, menu `Picker`s, no cards except the existing set-up-unlock action card). A shared `NativeSettingsRow` (symbol, title, chevron / external-link / no accessory) replaces `SettingsListItem` in these screens; the flight recorder section in `BitwardenKit` was converted the same way because About embeds it. Store/Processor/State/Action and all accessibility identifiers are unchanged.
![account security light](Docs/screenshots/sd-account-security-light.png) ![account security dark](Docs/screenshots/sd-account-security-dark.png)
![autofill light](Docs/screenshots/sd-autofill-light.png) ![autofill dark](Docs/screenshots/sd-autofill-dark.png)
![about light](Docs/screenshots/sd-about-light.png) ![about dark](Docs/screenshots/sd-about-dark.png)

Evidence (iPhone simulator PassY-SD, local Vaultwarden):
- `test16_settingsAccountSecurityAutofillAbout` (real taps: timeout menu, log out alert, version copy, identifiers) passes, light and dark; it also asserts that no visible label contains `Optional(`. No string interpolation of optional values in the three views.
- Bitwarden-ViewInspector 606 executed, 17 skipped, 0 failures (Autofill picker test adapted, About/Account security tests unchanged and green); Bitwarden-Unit 5859 XCTest + 725 Swift Testing, 0 failures.
- Watch app (watchOS simulator, `-passyDemoCodes`): TOTP list ![watch](Docs/screenshots/sd-watch-totp-list.png)
- `platform=macOS,variant=Designed for iPad` builds (BUILD SUCCEEDED) with the default team signing; with ad-hoc signing it fails ("Ad Hoc code signing is not allowed with SDK 'iOS 27.1'"). Catalyst was not retried (README: SDK slices).

UNVERIFIED:
- Mac window screenshot: `open .../Debug-iphoneos/Bitwarden.app` fails with "The application cannot be opened because it has an incorrect executable format."
- iPhone Duo portrait/landscape: PassY-SD-Duo does not come up (`simctl bootstatus`: "Data Migration Failed"; screenshot: "Invalid argument").
- Action and AutoFill extensions, watch widget/complication: not started (need a host app sheet / watch face); only built and embedded.
- Real login rate limit note: the throwaway Vaultwarden needs `LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000` for UI tests (the UI helper retries login).

## ui-r8 (real-device feedback on v1.23, iPhone Air)

### (a) Responsiveness: root cause and measurements

Root causes, found by code analysis and confirmed with the counters below (not guessed variants):

1. **Dead hit area in rows (one-tap problem).** The row button (`VaultListItemRowView`) uses `.buttonStyle(.plain)` (needed so a `List` row with several buttons fires only one). With `.plain` only *drawn* content is tappable. The label had no `contentShape`, the folder/group rows have a bare `Spacer` between name and count, the disclosure chevron and the 16 pt side margins were outside the button. A tap in the blank middle or right of a row hit nothing, so the user taps again. The existing UI tests tapped the text, so they never saw it. Fix: the whole row (chevron and margins included) is one `contentShape(Rectangle())` button; same for Send rows and the section header button. ViewInspector tests `test_rowButton_wholeRowIsHitArea`, `test_groupRow_wholeRowIsHitArea`.
2. **The bottom bar host swallowed touches.** The hosting view of the bar was 88 pt tall (60 pt bar plus a 28 pt fade strip) and answered every touch in its frame. Measured in a unit test before the fix: a touch in the strip above the bar and in the left margin were captured by the bar (`PERF hit ... top=true leftMargin=true`), after: both pass through (`top=false leftMargin=false`). The bar host is now `PassYBarContainerView`: touches outside the frames of the controls go to the page below; the strip and the backdrop are gone (see (e)).
3. **Every state change rebuilt the visible rows.** `vaultItemRow` created a child `Store` per row on every body pass (each one subscribes to the parent state), the parent body ran for every toast/search-text/profile-menu change, and the editMode environment re-evaluated all rows. Now rows get plain state and closures (no `Store`), are `Equatable` cells, the Select-mode flag is row state, and the vault home list sits behind an `Equatable` boundary keyed by the state that the list really shows (`VaultListState.homeListKey`). The search list only exists while searching (it was a hidden second `List` that diffed every change; two scroll views in a screen also confuse UIKit's choice of the large-title scroll view).
4. **Icons.** No image cache: every row that scrolled back downloaded, SHA-256 hashed and decoded its icon again, and `UIImage(data:)` decodes lazily on the main thread at the first draw. Now `NSCache` plus in-flight de-duplication, decode off the main thread (`byPreparingForDisplay`) and a synchronous cache hit in the first frame.
5. Smaller: a new `UIImpactFeedbackGenerator` per tile tap (shared prepared generator now); `last == item` deep comparisons per row in the group list (id comparison now).

Not found as cause: `contextMenu` + `swipeActions` + button (no conflict found by analysis; UNVERIFIED on device), push/present itself (the processor path is synchronous up to `UINavigationController.push`/`present`, measured by the new `TapToPush` signpost, see below).

Signposts (`PassYPerf`, subsystem `de.aiity.passy`, category `perf`): `VaultListLoad` (data assigned until first row appears), `RowAppear` (event), `TapToPush` (tap until the pushed/presented screen is handed to UIKit; also logged as `tap_to_push ms=`). Known limit: `TapToPush` starts inside the `AsyncButton` task, not at touch-down.

Unit-level numbers (2000 item vault hosted in a window on the iPhone 17 Pro simulator, iOS 27.0, Debug, machine under heavy foreign load; `VaultListPerfTests`, main-thread CPU time minus the harness control run). "before" is the instrumented baseline (commit `bddef6d2c` app code), "after" the final code:

| Measurement (30 toast changes, 2000 items) | before | after |
|---|---|---|
| child `Store`s created | 306 | 0 to 30 (only the vault filter row; none per row) |
| row bodies evaluated | 240 | 0 |
| main-thread CPU per change (net of harness) | about 42 ms | about 1 ms (final run: 772 vs 740 ms control), 5 to 17 ms in earlier runs |
| rows built in the list builder per change | 8 to 10 | 0 (up to 8 in some runs before the warm-up; asserted 0 afterwards) |
| first list load (CPU) | 126 ms | 115 to 134 ms (no change expected) |

CPU numbers vary by about 20 percent between runs (control run 967 to 1269 ms for 30 settle passes); the counters are deterministic and are asserted in `test_unrelatedChanges_doNotRebuildRows`. These are NOT frame times on a device. A first attempt wrapped the `ForEach` sections in `Equatable` subviews: that disabled the lazy cell creation (2000 rows built at load, 16 s) and was dropped; `ForEach` content must stay inline in the `List`.

`PassYPerfTests` (UI, to be run later with a 2000 item vault: `seed_ciphers.py 2000`): `test_perf_tapToPush_signposts` (XCTClockMetric plus `XCTOSSignpostMetric` for `TapToPush` and `VaultListLoad`, one tap must open the list page within 1 s), `test_perf_singleTapOpensItem_2000` (30 taps on the blank part of a row, 1 s each). `PassYUiR8Tests.test01/02` do the same for item and folder with a single tap.

### (b) System typography

The style guide already used text styles, but `lineHeight(for:)` added padding, line spacing and a minimum height from the old px sizes (body 15/20, headline 15/28 ...), the weight parameter defaulted to `.regular` (so `.headline` was not semibold), the navigation bar appearance fixed the fonts (15 pt, large title 26 pt bold), segmented controls used 13 pt, there were Menlo and about 20 fixed `.system(size:)` fonts. Now: no extra leading or padding (Apple's own), weight `nil` keeps the style's weight, system appearance for navigation bar and segmented control, text styles for all symbols and letter icons, TOTP codes in SF with monospaced digits (not the monospaced design), monospaced design only for passwords and fingerprint phrases (`sensitiveInfoSmall` is the system monospaced footnote instead of Menlo). `PassYTypographyTests` scans all production sources for fixed sizes and custom fonts (`.system(size:`, `.custom(`, `UIFont(name:`, `UIFont.systemFont(ofSize: <number>`) and fails on any hit. The `PassYItemFormScreenTests`/`PassYScreenTests` reference images were re-recorded because the layout changed on purpose.

### (c) Vault button

A 44 pt glass circle (`lock.shield`, id `BottomBarVaultButton`) left of the search field on every page except the vault home (destination vault and vault stack at its root). Action: switch to the vault, pop its stack to the root, cancel the search. UIKit publishes neither KVO for pushes (measured: silent) nor a notification, so the shell compares the vault stack depth by KVO on `viewControllers` plus a 0.15 s timer (an integer compare; the model only publishes on a change), so the button can appear up to about 0.15 s after a push. Tests: `PassYShellControllerTests.vaultButton_*`, `PassYShellBarHitTests`.

### (d) Native large titles

Vault home, vault group lists, Send, Generator and Settings (tab mode) use `navigationBarTitleDisplayMode(.large)` with `prefersLargeTitles` on their navigators; the toolbar fake title `largeNavigationTitleToolbarItem` is removed. The large title collapses with the scroll view. Pushed detail pages stay inline. Short pages (empty Send, Settings) do not collapse because their content fits (UIKit behavior).

### (e) No shadow behind the bar

The `ultraThinMaterial` backdrop with the gradient mask and the 28 pt fade strip are removed (it also cost an offscreen blur pass while scrolling). The glass capsules remain; on iOS 26 the list uses the system soft scroll edge. The glass itself has the system's own soft shadow.

### (f) Back and close: static audit (not run on a device)

Pushed pages use the system back button and swipe-back: vault group lists, all Settings sub pages (account security, autofill, app extension, appearance, about, other, vault settings, export, folders), Send type lists. `hidesBackButton`/`navigationBarBackButtonHidden` are only used in the pre-login auth flow. Presented sheets cover the bar and have their own control in the toolbar (found by grep, per file): item view (Close), add/edit item (Cancel), attachments, collections, move to organization, scan code and manual key entry, Send add/edit (Cancel) and view, password history, generator (Cancel when presented), login request, pending requests, device management, delete account, export vault, item selection. `MigrateToMyItemsView` (policy flow) and the import-logins onboarding are modal in presentation by design. From every pushed page the Vault button goes straight to the vault home. `PassYUiR8Tests.test06_backAndCloseEverywhere` walks these paths.

### Tests and what was run in this round

Run: Bitwarden-Unit full (5920 XCTest, 45 skipped, 0 failures; 732 Swift Testing passed), Bitwarden-ViewInspector 609 executed, 17 skipped, 0 failures, new `VaultListPerfTests`, `PassYShellBarHitTests`, `PassYShellControllerTests` (vault button), `PassYTypographyTests`. `build-for-testing` for the `PassYUITests` scheme: succeeded.

### UNVERIFIED (ui-r8)

- No UI test was run (`PassYUiR8Tests`, extended `PassYPerfTests`): single tap on the blank row area, folder/item opening within 1 s, collapse of the large titles, Vault button on every page, pixel sampling above the bar, back/swipe-back/close paths, perf with 2000 items. No device run (iPhone Air): the real-device responsiveness is not confirmed, only the mechanism (hit area, dead strip, rebuild counts).
- The 1 to 17 ms versus 42 ms numbers are simulator, Debug, CPU time under foreign load; no frame time, no Instruments run, no `XCTOSSignpostMetric` numbers.
- Equatable cells and the home list boundary were verified with counters, ViewInspector and the hosted-window unit test (visible cells render); the visual result of the home list was not screenshot-checked.
- iOS 26 glass and the large title on the real device (collapse behavior of `List` with `readableContentWidth`, `refreshable`): UNVERIFIED; short pages stay expanded.
- Group list pages still evaluate their `ForEach` per state change (only the rows are skipped); a 2000 item group page was not measured.
- Snapshot tests of other screens (the `Bitwarden-Snapshot` plan) were not run; only the two PassY snapshot classes in the Unit plan were re-recorded. Snapshots in other plans may differ because of the typography change.
- `contextMenu` + `swipeActions` + tap interplay and the icon cache under real network were not tested.

### ui-r8 after merging main (ui-r7, v1.24)

`main` (d87f0d091) was merged without textual conflicts (commit `1f81cf44d`). The merge touched the same files as ui-r8 (`VaultListView`, `VaultGroupView`, `PassYShellModel`): main's delayed list edit mode (`listIsEditing`, `.id(searchResults)`) works together with the search list that now only exists while searching; rows now follow `listIsEditing` instead of the immediate `isSelecting` (commit after the merge), so a row stays inert while the list is still in edit mode. The avatar contrast change does not interact with the bar changes.

Run after the merge (load at start 2 to 8): Bitwarden-ViewInspector 609 executed, 17 skipped, 0 failures. Bitwarden-Unit full: first run 5920 XCTest with 5 failures (`PassYScreenSnapshotTests.test_snapshot_pinUnlock` and `test_snapshot_setMasterPassword`, both appearances, plus `VaultListPerfTests.test_perf_listLoad_2000` because the host rendered no list); the repeated single run of `PassYScreenSnapshotTests` and `VaultListPerfTests` passed (10 tests, 0 failures); the perf test now skips instead of failing when the host has no window scene. The cause of the snapshot flake in the full run is not established (the same snapshots passed in the full run before the merge and in the single rerun).

UI chain (fresh simulator PassY-R8, own Vaultwarden on port 8089, 25 items): only `PassYUiR8Tests` was run, under load of 20 to 300 from foreign processes and on a simulator on which a foreign app (an "Add server" screen of another project) was found in the foreground afterwards, so the run is contaminated. Result: `test04_vaultButtonLeftOfSearch` passed (Vault button absent on the home, left of the search field on Send, Generator, Settings and a deep Settings page, returns to the home), `test05_noBackdropBehindBar` passed; `test01`, `test03`, `test06` failed (the group list rows were not found as `VaultListItemRowButton` after one tap on the tile; `test03` failed in the unlock helper with "no keyboard focus"); `test02` produced no result line. Whether the missing row button is a real accessibility regression of the new row structure (chevron inside the button, `contentShape`, equatable cells) or the contaminated run is NOT established and must be checked first in the next run (dump `app.debugDescription` after the tile tap). Not run: Landing, Flow 28, Rest, registrationStart, Auth, 2FA, Device login, iPad, 2000 item perf with `XCTOSSignpostMetric`, a11y audit.

### ui-r8 UI chain, second attempt (blocked by the environment)

Added: `focus()` helper for text fields (taps until `hasKeyboardFocus`, used by `replaceText` and the server/e-mail steps of `ensureUnlockedVault`) for the "no keyboard focus" failure of `test03`, and `test00_dumpGroupListTree` (prints `app.debugDescription` of the group list after one tile tap) to find out why `VaultListItemRowButton` was not found. Neither produced a result:

- The simulator `PassY-R8` was found to contain foreign apps (`IEUploaderUITests-Runner`, an "Add server" screen of another project in the foreground), i.e. another project's UI tests ran on the booted simulator. It was deleted and replaced by `PassY-R8b`; a foreign process can still pick any booted simulator.
- After `simctl erase` the UI test runner exits with "signal term while preparing to run tests" (twice); without erase the run starts, but the login helper then ended on the login screen with an alert (probably the foreign interference above, not established).
- The 1-minute load swung between 2 and 540 (diskimagesiod, foreign simulators and builds); two runs were killed without a result line (cause unknown).

So the root cause of the missing `VaultListItemRowButton` after a tile tap is still NOT established: it may be a real accessibility regression of the new row structure (chevron inside the button, `contentShape`, equatable cells) or an artefact of the contaminated runs. It must be the first thing checked in the next quiet run; `test04` (Vault button) and `test05` (no backdrop) passed once, everything else of the UI chain (Landing, Flow 28, Rest, registrationStart, Auth, 2FA, Device login, iPad, 2000 item perf with `XCTOSSignpostMetric`, a11y audit) was not run.

### ui-r8: static analysis of the missing `VaultListItemRowButton` and the unattended UI chain

Line-by-line comparison with `main` (v1.24): the identifier `.accessibilityIdentifier("VaultListItemRowButton")` is still on the `AsyncButton` (same modifier order: `buttonStyle(.plain)`, identifier, `allowsHitTesting`, `hoverEffect`); the row still has `.accessibilityElement(children: .combine)` plus the row identifier on the outer `VStack`, exactly as in `main`. The differences are: the chevron moved from beside the button into the button label (it is `accessibilityHidden`), the label got `padding` and `contentShape(Rectangle())` (neither changes the accessibility tree), the trailing copy button gets its own padding, rows are wrapped in `.equatable()` cells, the Select-mode flag is state instead of the `editMode` environment. No nested button, no extra gesture and no new `accessibilityElement` was introduced. Proof at SwiftUI level: `test_vaultItem_rowButtonKeepsIdentifierAndLabel`, `test_folderRow_keepsIdentifier` (group list), `test_cell_keepsIdentifier_andTapReachesEffect`, `test_rowButton_wholeRowIsHitArea` (19 ViewInspector tests in `VaultGroupViewTests` and `VaultListItemRowViewTests`, 0 failures): the identifier sits on the tappable button, the item name is its label and a tap reaches the processor. This does NOT prove the UIKit accessibility tree (ViewInspector does not see it), so the earlier UI failure is neither explained nor excluded; the diagnosis test `test00_dumpGroupListTree` is the first step of the chain.

`Scripts-passy/ui_chain_r8.sh` runs the whole chain unattended: PID file `out-r8/chain.pid`, log `out-r8/chain.log`, one line per step in `out-r8/summary.txt`. It waits for a 1-minute load below 25 for three minutes (30 s samples), boots the own simulator only for the duration of a step and shuts it down afterwards, discards a step when a foreign user app is installed on the simulator (an own simulator is erased once; nothing foreign is ended), retries a failed step once (failed tests alone) and writes both loads into the summary.

### ui-r8: root cause of the missing `VaultListItemRowButton` (found in the UI tree dump)

Chain run 2 (HEAD `2bb85cf63`) still failed `test01/02/06`, `test_rowChevronContextMenuSwipe`, Flow `test22/26/28` and the two single-tap perf tests; the tree dump of `test00_dumpGroupListTree` after the first fix still showed one `Button` with identifier `CipherCell` per row and no `VaultListItemRowButton`. In the previous state (`out/*.log` of the ui-r7 chain) both existed as two buttons per row. The row had an outer `.accessibilityElement(children: .combine)` with the row identifier (`CipherCell`, `FolderCell`) around the inner button; with the button now carrying the chevron and the whole row content, SwiftUI collapsed container and button into one node and kept the container identifier. Moving the 16 pt margin out of the button did not change that. Fix (commit "row identifier and custom actions on the button itself"): the button is the only accessibility element of the row; the identifier `VaultListItemRowButton` and the more-options custom actions are on it, the label still combines name and subtitle (VoiceOver), the chevron stays hidden. The container identifiers (`CipherCell`, `FolderCell`, ...) are no longer set on the list rows (no UI test, unit test or product code used them; `VaultListItem.vaultItemAccessibilityId` stays for other uses).

Verified by UI run after the fix (load 14 to 6): `test00`, `test01` (one tap on the blank part of a row opens the item within 1 s), `test06` (back, swipe back, close, Vault button), `test_rowChevronContextMenuSwipe`, Flow `test18`, `test22`, `test26`, `test28` passed. `test02` (folder): the single tap opened the folder within 1 s (the assertion on the title passed); its remaining failure was a test bug, namely the home keeps its scroll position after the Vault button, so the tile was not in the tree (the test scrolls up now) and the title lookup used `navigationBars[title]` although the bar identifier is `MainHeaderBar` (static text lookup now). `test_exportVault` failed once with "no keyboard focus" in the login helper of `PassYImportRegShotsTests` (it types with `tap()` instead of the new `focus()` helper): infrastructure, not part of this fix.

### ui-r8: final checks (flow count, export test, comparison against main v1.24)

- **Flow 27 instead of 28 tests (chain 3):** `test17_foldersListLastRowClearOfAddButton` crashed the UI test runner with `Fatal error: Range requires lowerBound <= upperBound` (`for i in existing ..< 12`, more than 12 folders existed after earlier runs created folders; the loop is from main). A crashed test is listed only under "Failing tests:" and the runner restarts, so the chain script counted 27 passed tests and reported PASS although `xcodebuild` ended with `** TEST FAILED **` (only `flow` was affected, checked for all steps). Fixed the loop (`min(existing, 12) ..< 12`) and the chain script (a step is FAIL on the `TEST FAILED` marker or a "Failing tests" entry). `test17` and `test_exportVault` passed in a single run on ui-r8 HEAD (load 14 to 105, no foreign app). `test_exportVault` already logs in through `ensureUnlockedVault` with `focus()`; its earlier "no keyboard focus" failure was before that helper and did not recur in chain 3.
- **Single tap, ui-r8 against main v1.24** (`PassYUiR8CompareTests`, identical code in a temporary worktree of `main` with a separate DerivedData; same simulator, same 2000 item vault; the XCUITest idle wait gives a floor of about 2 s, so only the tap success count and relative times are meaningful):

  | measurement | main v1.24 | ui-r8 |
  |---|---|---|
  | one tap on the name part of a row opens the item (10 tries) | 10/10 | 10/10 |
  | one tap on the blank middle of a row (10 tries) | **0/10** | **10/10** |
  | tile tap to first row of the list (median of 10) | 1.79 s | 1.83 s |
  | unlock to first list row (median of 3) | 1.59 s | 1.60 s |

  This is the reported "first tap does not open": on v1.24 a tap outside the drawn text and icon does nothing. The load was 15 to 22 at the start of both runs. A second round (`cmp-*-b` in `out-r8/cmp-summary.txt`) was still running when this was written.
- **Signposts (ui-r8 only, `PassYPerfTests`, 2000 items):** `TapToPush` (tap until the screen is handed to UIKit) averages 0.001 s (5 measurements, std dev 5.8 percent); `single_tap_opens_item` 30 taps, each opened the item (median 1.97 s including the XCUITest wait); unlock to vault 2.76 s; 30 fast swipes 43.1 s; search to the exact hit 7.9 s; CPU time of the scroll metric test 4.4 s. No main numbers exist for the signposts (they do not exist there); the wall-clock tests of the previous rounds (R5: unlock 2.9 s, 30 swipes 44.5 s, search 11.8 s, CPU 6.2 s) were measured in another session and are not directly comparable.

### ui-r8 fix round after the validator verdict (`Docs/verdicts/2026-11-19-ui-r8.md`, FAIL on `e8f65a1e1`)

- **Dark mode was never rendered by the UI tests (validator finding D, confirmed).** A pixel check was added to `attach()` (background luminance at the left edge of every screenshot, dark below 0.35, light above 0.6, logged as `APPEARANCE-CHECK`). First run with the old mechanism (`XCUIDevice.shared.appearance = .dark`, then `-AppleInterfaceStyle Dark` as launch argument): 18 screenshots named "dark" had luminance 0.95 to 1.00, i.e. light (`rest` run, ui-r5/r6/r7 tests `test_compare`, `test_newTypeForms`, `test_rowChevronContextMenuSwipe`, `test_addEditFormsAreInlineRows`). `-AppleInterfaceStyle` worked once when the simulator had never been touched and stopped working after `simctl ui <sim> appearance light`, so it is not reliable. The mechanism that works is an app launch argument `-passyForceInterfaceStyle dark|light` read in `AppProcessor` (sets the windows' `overrideUserInterfaceStyle`, only when the argument is present); the tests pass it through `launchApp()` (`setPassYAppearance` replaces every `XCUIDevice.shared.appearance = ...`). Measured with it: dark screenshots luminance 0.00 to 0.11, light 0.76 to 1.00. Dark steps of the final chain: auth 4, 2FA 3 and 4, device 2, iPad 6, rest 26 screenshots, all checked dark (max luminance 0.11), 0 mismatches in the final runs. Dark variants that were switched on inside a running app (three screenshots in `PassYImportRegShotsTests`) cannot work and are now attached only when they really are dark (`attachDarkIfRendered`), otherwise a `NOTE` is printed (2 omitted in `rest`). The "Recovery code" screenshot of the 2FA test is Safari (the web vault link), not the app, and is not appearance-checked.
  **Earlier claims:** every statement in the ui-r5, ui-r6 and ui-r7 sections that a UI test screenshot or run was "dark" and came from `XCUIDevice.shared.appearance` (2FA dark, device login dark, auth pages dark, `test_darkMode`, the iPad dark shots, dark item/edit/add shots from the UI tests) is UNVERIFIED as dark: it may have been rendered light. Screenshots from `simctl ui appearance dark` (R2, logo renders) and the snapshot-test renders (`PassYItemFormSnapshotTests`, light/dark by trait) are not affected. Dark is verified (pixel check) only from the ui-r8 final chain on.
- **`PassYUiR8Tests.test02_singleTapOpensFolder` in the class run:** the folder row was found in the tree at y 871 to 927 on an 874 pt screen (under the bar) and the helper scrolled only until `exists`. The helper now scrolls until the row is `isHittable` and ends above the search bar (`maxY <= bar.minY - 4`); the home keeps its scroll position after the Vault button, so the test scrolls back up before looking for the tiles. Class runs of `PassYUiR8Tests` 7/7 green three times (chain run, `ui-r8-b` after an erase, `ui-r8-c`; the first chain attempt had one login-helper failure, see below). Product check: `PassYShellBarHitTests` show that a touch is only taken by the bar where a control is drawn; the gaps and margins pass through to the list, so a row that is visible beside or between the controls is tappable; under a glass control (search field, plus, Vault button) the control gets the touch, as designed.
- **Flow `test02_loginAndSync` (validator: 27/28 twice, alone green):** error `Failed to get matching snapshot ... SecureTextField` inside `replaceText`; the hierarchy showed the vault ("My vault", login succeeded). Cause: `ensureUnlockedVault` typed the password, tapped Log in, slept 2 s and went round the loop again; when the asynchronous login had not finished yet the password field still existed and was typed into a second time while it disappeared. A test race, not a product defect. Fix: after Log in or Unlock the helper waits (25 s) for the vault button instead of re-entering text, and its overall deadline is 180 s (a first test after an erase under load needed more than 90 s once). Flow in the final chain: 28/28 with `TEST SUCCEEDED`.
- **Chain (`Scripts-passy/ui_chain_r8.sh`) is strict:** a step is PASS only with `** TEST SUCCEEDED **`, no failed or crashed test (`Test Case ... failed` plus the `Failing tests:` list), no `TEST FAILED` marker, no runner restart and at least the expected number of passed tests (Flow 28, rest 15, UiR8 7, perf 6, audit 5 ...). A failed step is repeated once with the failed tests alone (the minimum is then the number of retried tests); both runs are in the summary with the load at start and end. `xcodebuild` is ended after its result marker by its own PID (`out-r8/run.sh` for the Unit/ViewInspector plans, `passy_run_xcodebuild` for the UI runs). Every step first sets `simctl ui <sim> appearance light` as baseline.
- **Final chain run (HEAD of the run `a079211fd` plus test-only fixes during the run, summary `out-r8/summary.txt`, own simulators only, no foreign app found):** diag, landing, flow 28/28, rest 15/15, registrationStart, auth light and dark, 2FA dark (retry) and dark again, device light and dark, iPad light, dark and landscape, perf 6/6, audit 5/5 PASS; `ui-r8` first run 6/7 (login helper: "Could not reach the vault list" for the first test after the erase at load 25), retry of that test PASS, whole class repeated twice 7/7. `2fa-light` failed twice in the chain only because of the appearance check on the Safari "Recovery code" screenshot (luminance 0.00 in light mode); after excluding that screenshot it passed in `2fa-light-b-retry` (the first attempt of that follow-up run still had the old code). Steps that needed the single retry in the chain: 2FA light (see above), 2FA dark (same cause, passed after the fix), `ui-r8`.
- **UNVERIFIED (still):** a real iPhone and VoiceOver; `TapToPush`/`VaultListLoad` signpost values were measured once (`TapToPush` about 1 ms) but not compared with main; `AppProcessor` has no unit test for the new launch-argument hook (Unit and ViewInspector were repeated after all changes: Unit 5922 XCTest (45 skipped) + 732 Swift Testing, `TEST SUCCEEDED`; ViewInspector 612 executed, 17 skipped, 0 failures, `TEST SUCCEEDED`); battery effect of the 0.15 s stack timer; the dark variant of the `PassYUiR8Tests` screens (they run light only).

### ui-r8 fix round 2 (validator FAIL on `094cd1b77`; environment: new worktree, shared DerivedData, scratch directory)

State at the end of this round (honest, the machine was saturated by foreign processes, 1-minute load 100 to 585 for hours):

- **Environment:** worktree `pass-y-r8`, one shared DerivedData `~/Library/Caches/passy-vw-dd`, Vaultwarden 1.37.5 from `vaultwarden-build` (`VW_BIN`), logs and data in `~/Library/Caches/passy-vw-scratch` (result bundles are deleted after each step). The test scripts (`Scripts-passy/env.sh`, `run_ui.sh`, `run_local.sh`, `ui_chain_r8.sh`) use these locations and own simulators created by name (`PassY-R8b`, `PassY-R8-2FA`, `PassY-R8-iPad`).
- **Release build:** `BitwardenShared` compiles in Release for the simulator (BUILD SUCCEEDED); the string `passyForceInterfaceStyle` is in the Debug binary (1 hit) and not in the Release binary (0 hits): the hook is `#if DEBUG` only.
- **Login helper (`ensureUnlockedVault`):** state driven (waits for the vault or an alert after login or unlock instead of fixed times), budget `150 s + 6 s per unit of host load above 8` (at most 600 s), an alert is dismissed and the step repeated up to three times.
- **device-dark:** not reproduced. In the first full chain of this round `device-dark` and `device-dark-b` passed (as did `device-light`, `device-light-b` after a runner crash retry). The validator's dump (device-dark.log) shows the master-password page without the "Log in with device" button, i.e. the known-device answer was `false` or the request failed: `LoginProcessor.refreshKnownDevice` swallowed a failed request (logged only) and never asked again. It now retries once (unit test `test_perform_appeared_failureThenTrue`, existing failure test adapted). This is a hardening, NOT a proven root cause; the UI test prints the full hierarchy (`DEVICE-BUTTON-MISSING`) if the button is missing.
- **Found by the chain in this round (test/data problems, fixed):** `test05_noBackdropBehindBar` compared pixels on the Trash page, which was not empty any more (8 items left by earlier tests: a white list row at the reference point, grey page near the bar; screenshot checked): it now creates its own empty folder and compares with the pixel at the bottom edge of the screen. `test_perf_search` failed because the 2000 items were seeded after the app's last sync (search found nothing, hierarchy checked): the perf step now starts with a fresh login (`erase`), and the test focuses the search field with `focusSearch`.
- **First full strict chain of the round** (`summary-chain1`): diag (retry after a load-108 failure), landing, flow 28/28, rest 15/15, registrationStart, auth light and dark, 2FA light, dark, dark2, device light and dark (and the `-b` repeat), iPad light, dark, landscape, audit 5/5 PASS; `ui-r8` 6/7 (test05, see above), perf 5/6 (search, see above).
- **Second full chain** (after the fixes above, started 14:52): diag, landing, flow 28/28, rest 15/15 and registrationStart PASS; it then waited for the load gate (below 25) from 16:38 on; auth, 2FA, device, `PassYUiR8Tests` (7/7 expected), iPad, perf and audit are NOT yet run on the final code.
- **NOT done in this round:** the final Unit and ViewInspector runs after the `LoginProcessor` change (they also did not finish under the load), the comparison against `main` v1.24 with a temporary worktree (`PassYUiR8CompareTests`, tap on the blank part of a row 0/10 on main against 10/10 on ui-r8, measured in an earlier round in the old environment and recorded above), cleaning up the three own simulators and the scratch directory.
