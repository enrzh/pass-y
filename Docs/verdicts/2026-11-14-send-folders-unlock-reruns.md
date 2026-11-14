# Addendum to 2026-11-14-send-folders.md: the four unlock failures

Validated commit: 362108ad0 plus a test-only commit (unique send name in test16, README note).
Environment: iPhone 17 Pro simulator (iOS 27.0), machine load average at the rerun start 50.81 / 50.09 / 69.09 (1/5/15 min), several parallel workers (settings, import/registration) building and testing.

Command (full suite, run 1): `xcodebuild test -scheme PassYUITests -destination id=<iPhone sim> -skip-testing:PassYUITests/PassYLandingShotsTests` (log ui_full8.log)
Command (rerun of the four, alone): `xcodebuild test ... -only-testing:...test09_searchCancelRestoresVault -only-testing:...test12_itemViewRevealAndCopyTaps -only-testing:...test13_settingsAccountMenu -only-testing:PassYUITests/PassYPerfTests/test_perf_scroll` (log ui_full8b.log)

| Test | run 1 | rerun alone |
|---|---|---|
| test09_searchCancelRestoresVault | failed 137.7 s, "Could not reach the vault list" | passed 426.1 s |
| test12_itemViewRevealAndCopyTaps | failed 298.3 s, "Failed to tap MasterPasswordEntry" | passed 81.5 s |
| test13_settingsAccountMenu | failed 501.6 s, "Could not reach the vault list" | passed 23.9 s |
| test_perf_scroll | failed 113.2 s, "Could not reach the vault list" | passed 140.2 s |

All four failed inside `ensureUnlockedVault` (login/unlock) before touching any changed screen; all four passed alone. test09 needing 426 s instead of ~25 s shows the machine was starved. Conclusion: load flake, not an unlock regression. Not proven by load logs, inferred from the behavior (limitation noted by the validator).
