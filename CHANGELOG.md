# Changelog

Condensed history, newest first. Versions are git tags (`git tag -l 'v1.*'`); each round was checked by an independent
validator whose verdict is linked (all in [Docs/verdicts](Docs/verdicts/README.md)). Screenshots of older rounds are no longer
in the working tree; they stay in git history (`git log --stat -- Docs/screenshots`).

## Unreleased

## v1.28.0 (2026-11-24) - Apple polish round
Not tagged and not version-bumped yet; no validator verdict yet.

- Lists as cards: vault home, group pages, search results, Send and folders are native inset-grouped lists (rounded
  cards on the grouped page colour, system separators aligned to the item name); group pages open fully formed (no
  spinner, the title and "N Items" subtitle are there from the first frame, no title jump).
- Native menus: row options, the swipe "More" action and the bar's "+" are pull-down menus with SF Symbols (no centered
  action sheet); icon-only swipe actions Delete and More on item rows.
- Vault home: tinted rounded-square category tiles with rounded tabular counts and a press state; avatar toolbar
  button 44 pt like the neighbouring glass buttons.
- Toasts: Liquid Glass capsule with an SF Symbol (copied / success / failure), snappy transition, haptic feedback,
  dismiss after about 3 s.
- Customize ("Anpassen", from Settings): per device, not synced. Home: cards and folder rows (see round 2 below);
  show/hide, order and "collapsed when opened" of the sections; rows of hidden sections stay reachable under "More" at
  the end of the home. Rows: user names, icons (website icons: the existing switch), favourite / shared / attachment
  marks. Verification codes: digit grouping. Live preview and Reset to defaults; the defaults are the previous look.
- Customize, home round 2: long press on a home card opens its native menu from the card (Move to Front /
  Earlier / Later / to End, Show as Folder Row, Customize…); type and folder rows offer Show as Card and Customize…;
  the avatar menu has no Customize entry any more and Settings lists "Anpassen" first, above Kontosicherheit. Nothing
  disappears: every type and folder is a card or a folder row (types switched off are rows of a "Types" section,
  folders switched on are cards that open the folder, ordered with the other cards). Cards only (tile layouts
  removed), comfortable rows only (density removed), card colours "Bunt" or "Vollfarbig" (the whole card in a deep
  type colour, white content at 4.5:1 or more; monochrome removed). The countdown ring / seconds switches left
  Customize; digit grouping explains itself (123 456 / 123456). Preferences version 2: hidden tiles of version 1
  become rows, removed options are ignored, the countdown is switched back on.
- New logo (solid shield with a Y knocked out) and an Icon Composer app icon (`PassY.icon`, light / dark / tinted).
- Minimum iOS 26 (deployment target and Info.plist).
- Unlock: the vault list is warmed up (decrypted off the main actor) while the shell is built, and the unlock waits up
  to 0.3 s for it; no privacy cover (splash) over the unlock page while the Face ID prompt is up, the app switcher
  snapshot stays covered.
- Empty group / folder pages show the same page colour above the bottom bar as every other page.
- Toasts on the vault, group and Send pages sit just above the bottom bar (they floated about 80 pt higher, over the
  list, because the bar's height was added twice).
- Code (no visible change): pre-iOS 26 checks and fallbacks removed, list pages share one set of helpers, all DEBUG
  diagnostics in one folder (none in Release builds).
- Open issues: the XCUITest idle stall after unlock has no known root cause; the Face ID splash change is verified only
  by unit tests (the simulator unlocks without a prompt); the reported back-navigation delay was not reproducible in
  the simulator; an item opened from the home search results shows its sheet with the search keyboard still up (seen
  in the simulator, not changed).

## v1.27.0 (2026-11-24) - Watch back, preload security fix, cleanup
Verdicts: four validator runs, all FAIL, each on a different single UI test:
[v1.27](Docs/verdicts/2026-11-24-v1.27.md), [recheck](Docs/verdicts/2026-11-24-v1.27-recheck.md),
[idle-fix](Docs/verdicts/2026-11-24-v1.27-idle-fix.md), [hardening](Docs/verdicts/2026-11-24-v1.27-hardening.md).
Released without a PASS on the maintainer's judgment: every unit plan is green (6608 / 597 / 654 / 67 tests), Release
builds carry no diagnostics, and no red test was traced to a product defect. Open: the XCUITest idle stall after unlock
(cause not found, seen in 3 of 11 full-phone runs) and the Send text typing reorder (1 run) below.

- Known issue (UI tests, not reproduced): one validator run reordered the first typing into the Send text field
  (a lost capital and a caret jump); 0 of 30 in a loop, product code unchanged since v1.26. The typing helper's clear
  no longer leaves text after a mid-text caret (see [Docs/Testing.md](Docs/Testing.md)).
- Hardening (not a proven fix): unlocking with the master password or PIN releases the field's focus before the vault
  appears; a rejected attempt focuses it again. Against an XCUITest "App animations complete notification not
  received" stall right after unlock whose cause was not reproduced (0 stalls in 6 later full-phone runs).
- Keystroke loss in the masked add/edit fields diagnosed as an XCUITest `typeText` artifact with two masked fields (not
  field re-creation; software keyboard taps and a real iPhone Air keep every character); product and test helpers
  unchanged, finding and probes in [Docs/Testing.md](Docs/Testing.md) / `KeystrokeProbeTests`.
- iPad: the landing's "Server: Not set" row (and the registration's server row) is tappable on its whole width; after
  cancelling the first server sheet a tap in the middle of the wide row did nothing.
- Swipe Delete in item lists no longer uses a destructive-role button: it removed the row before the confirmation (gone
  after Cancel) and the later real removal could crash the list diff ("Invalid number of items in section").
- Settings > Account security: no "Authenticator sync" row; the sync with Bitwarden's Authenticator app is always off
  (a stored "on" is ignored), since Pass-Y's own bundle IDs/app group/team cannot reach it.
- Tests: Pass-Y unit/ViewInspector tests named by feature instead of round (`PassYAppHygieneTests`, `PassYIdleTests`,
  `PassYVaultNoRefreshControlTests`, `PassYItemPreloadTests`, `PassYAvatarMenuViewInspectorTests`); new UI tests
  `IPadLandingTests.test_serverSheetReopensAfterCancel`, `ItemListActionsTests.test_swipeDeleteKeepsRowUntilConfirmed`.
- Security: the item preload drops results that arrive after the 1 s timeout or after lock, logout or account switch, cancels running fetches, wipes untaken entries by timer, and no item opens after a lock.
- Apple Watch app, widget and the Connect to Watch setting restored (removed in v1.26); Mac and visionOS stay off.
- Versioning: one scheme `MAJOR.MINOR.PATCH`, next release 1.27.0 (was 2026.4.0 upstream scheme); tags `vX.Y.Z`, see [Docs/Releasing.md](Docs/Releasing.md).
- Removed unused Authenticator test plans/xcconfigs and the dead `TwoStepLoginService`; the Premium web-upgrade fallback and the archive "Restart Premium" card no longer open the server's upgrade page.
- CI workflow (`.github/workflows/ci.yml`): build and a small unit-test subset, no secrets or signing (unverified until it runs on GitHub).
- README reduced to one page, history moved here, one current screenshot set.

## v1.26-ui-r9 (2026-11-22) - Apple-style rework, iOS/iPadOS only
Verdict: [2026-11-22 FAIL](Docs/verdicts/2026-11-22-ui-r9.md), then [2026-11-23 final PASS](Docs/verdicts/2026-11-23-ui-r9-final.md).
- No splash/launch page, soft top and bottom fades instead of blur blocks, no loading flicker after opening a page
  (item view preloaded, group lists start streaming first, spinner delayed 0.4 s).
- Avatar menu shows the server URL and has Sync now and Pending login requests; no "web vault" links anywhere.
- Pull-to-refresh on the vault home removed on purpose (its refresh control stalled XCUITest idle); Sync now is in the avatar menu.
- Watch app, widget and WatchConnectivity removed (restoration is on another branch); Mac and visionOS off.
- Idle stall traced to the interactive glass of the "+" menu and fixed with a plain glass background (108 loop rounds, 0 stalls).
- Hardening: preload cache timeout (1 s), double-tap guard, cache cleared on lock. `ui_chain.sh` takes the port from `VW_PORT`.
- Open: swipe-delete SIGABRT not reproduced, lost keystrokes in the master password field, VoiceOver and real-device checks.

## v1.25-ui-r8 (2026-11-21) - Tap responsiveness
Verdicts: [2026-11-19 FAIL](Docs/verdicts/2026-11-19-ui-r8.md), [2026-11-20 recheck FAIL](Docs/verdicts/2026-11-20-ui-r8-recheck.md),
[2026-11-21 final PASS](Docs/verdicts/2026-11-21-ui-r8-final.md).
- Whole row is tappable (row accessibility and hit area; blank part of a row opened the item 0/10 on v1.24, 10/10 now).
- Bottom bar with a Vault button, native large titles, system typography, no shadow behind the bar.
- Strict UI test chain (`ui_chain.sh`, load gate, own simulators and Vaultwarden, retry rules). The chain log of the last fix
  rounds (diag, flow 28/28, rest 15/15, auth/2FA/device, iPad, perf, audit) is not kept; its results are in the verdicts.
- Open then: an intermittent XCUITest "App animations complete" stall (observation O1), solved in ui-r9.

## v1.24-ui-r7 (2026-11-18) - Inline Apple form rows
Verdicts: [2026-11-16 FAIL](Docs/verdicts/2026-11-16-ui-r7.md), [2026-11-18 recheck PASS](Docs/verdicts/2026-11-18-ui-r7-recheck.md).
- Add/edit forms use Apple rows (grey label left, value right); home search got Delete, swipe actions and Select with bulk
  Move/Delete; bulk actions report failures honestly.
- Renders of all item-type forms (light/dark), accessibility audit before/after, test scripts moved out of `/tmp` into `Scripts-passy`.
- Simulator finding: the secure field of the add form keeps only the last typed character; UI test works around it.

## v1.23-ui-r6 (2026-11-16) - Chevron rows, context menus
Verdict: [2026-11-16 PASS](Docs/verdicts/2026-11-16-ui-r6.md).
- List rows with a disclosure chevron, long-press context menu and swipe actions, "N Items" subtitle and Select mode.
- Native item detail (tap row to copy, favorite star in the toolbar), letter icons for logins without a favicon.
- Real auth screens reached in the app (password hint, SSO, 2FA incl. methods and recovery) with a 2FA test account; iPad landscape shots.

## v1.22-ui-r5 (2026-11-16) - Apple Passwords polish
Verdicts: [2026-11-16 FAIL](Docs/verdicts/2026-11-16-ui-r5.md), [recheck PASS](Docs/verdicts/2026-11-16-ui-r5-recheck.md).
- Compared against the real Apple Passwords app in the simulator: left-aligned large titles, tile and header restyling, iPad width cap.
- Add menu reordered so Login stays reachable at AX-XXXL (fixed a real `test_largeText` failure); previously unreachable new item types tested.

## v1.21-ui-r4 (2026-11-16) - Native forms
Verdicts: [2026-11-15 PASS with conditions](Docs/verdicts/2026-11-15-ui-r4.md), [recheck PASS](Docs/verdicts/2026-11-15-ui-r4-recheck.md).
- Item, Send and rare auth pages as native `Form`/`List`; equal-height tiles; fixture seeding (GitHub with TOTP, Netflix).

## v1.20-ui-r3 (2026-11-15) - Shell, avatar menu
Verdict: [2026-11-15 PASS](Docs/verdicts/2026-11-15-ui-r3.md).
- No tab bar: Vault, Send, Generator and Settings through the avatar menu; persistent bottom search bar with `+` menu.
- Native onboarding, settings, generator and Send; edit as toolbar button. Lists kept the "..." button until ui-r6.

## v1.19-forms-complete (2026-11-14) and v1.1 to v1.18
Verdicts: [v1.19 final PASS with caveats](Docs/verdicts/2026-11-14-v1.19-final.md),
[send/folders](Docs/verdicts/2026-11-14-send-folders.md) (+ [unlock reruns](Docs/verdicts/2026-11-14-send-folders-unlock-reruns.md)),
[import/registration](Docs/verdicts/2026-11-14-importreg.md), [settings sub-screens](Docs/verdicts/settings-de-validator.md).
Earlier validator files were lost in a local cleanup and are not available.
- v1.19: forms, Send and Folders completed; search keyboard fix; known `test_largeText` flake documented.
- v1.18 forms/send, v1.17 search hardening, v1.16 iPad add-menu fix, v1.15 item view polish (large title, tap to copy).
- v1.14 settings account row, v1.13 native segmented generator, v1.12 "P" logo, v1.11 avatar menu with bottom search/add bar.
- v1.10/v1.9 settings root and icons, v1.8 generator as `Form`, v1.7 sidebar step, v1.6/v1.5 vault list and search as real `List`.
- v1.4 audit of remaining screens (no code change), v1.3 rows, v1.2 native unlock, v1.1 native login.

## v1.0-round5 (2026-11-12) - Fork baseline
Server-first onboarding, no telemetry, no upsells, own identity and icon. Round 5 added iPad Air screenshots, perf measurement
(2000-item vault: unlock to list 2.7 s, no gain from the one change tried) and the result that a Mac "Designed for iPad" run is
not possible for UI tests.
