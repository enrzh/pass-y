# Changelog

Condensed history, newest first. Versions are git tags (`git tag -l 'v1.*'`); each round was checked by an independent
validator whose verdict is linked (all in [Docs/verdicts](Docs/verdicts/README.md)). Screenshots of older rounds are no longer
in the working tree; they stay in git history (`git log --stat -- Docs/screenshots`).

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
