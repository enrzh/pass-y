# ui-r8 chain summaries (fix round 2)

## summary-chain1
```
2026-11-20 11:13:27 chain start (pid 82555)
2026-11-20 11:19:54 diag: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYUiR8Tests/test00_dumpGroupListTree ; load start 108.41 end 145.83; foreign: none)
2026-11-20 11:22:35 diag-retry: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 22.47 end 36.56)
2026-11-20 11:29:04 landing: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 27.13 end 176.39)
2026-11-20 11:51:12 flow: PASS (28 of >= 28 tests; TEST SUCCEEDED; load start 21.58 end 4.42)
2026-11-20 12:12:36 rest: PASS (15 of >= 15 tests; TEST SUCCEEDED; load start 9.43 end 3.28)
2026-11-20 12:14:48 regstart: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 9.02 end 177.43)
2026-11-20 12:19:47 auth-light: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 22.10 end 137.94)
2026-11-20 12:23:38 auth-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 22.01 end 159.37)
2026-11-20 12:28:47 2fa-light: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 67.02 end 198.30)
2026-11-20 12:33:48 2fa-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 21.36 end 109.69)
2026-11-20 12:38:14 2fa-dark2: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 18.90 end 113.45)
2026-11-20 12:42:19 device-light: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 32.18 end 160.17)
2026-11-20 12:50:35 device-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 19.09 end 278.50)
2026-11-20 13:11:03 device-light-b: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed:  ; load start 44.35 end 134.62; foreign: none)
2026-11-20 13:15:01 device-light-b-retry: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 29.56 end 201.42)
2026-11-20 13:21:08 device-dark-b: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 21.89 end 141.42)
2026-11-20 13:43:04 ui-r8: FAIL (passed 6 of >= 7; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYUiR8Tests/test05_noBackdropBehindBar ; load start 23.23 end 2.28; foreign: none)
2026-11-20 13:54:42 ui-r8-retry: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYUiR8Tests/test05_noBackdropBehindBar ; load start 7.54 end 2.67; foreign: none)
2026-11-20 14:05:08 ipad-light: PASS (2 of >= 2 tests; TEST SUCCEEDED; load start 54.33 end 10.74)
2026-11-20 14:11:05 ipad-dark: PASS (2 of >= 1 tests; TEST SUCCEEDED; load start 13.64 end 13.44)
2026-11-20 14:13:12 ipad-landscape: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 17.38 end 139.32)
2026-11-20 14:25:17 perf: FAIL (passed 5 of >= 6; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYPerfTests/test_perf_search ; load start 24.41 end 4.00; foreign: none)
2026-11-20 14:35:59 perf-retry: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYPerfTests/test_perf_search ; load start 4.00 end 3.60; foreign: none)
2026-11-20 14:46:33 audit: PASS (5 of >= 5 tests; TEST SUCCEEDED; load start 5.47 end 4.37)
2026-11-20 14:46:34 chain done
```

## summary
```
2026-11-20 14:52:08 chain start (pid 21258)
2026-11-20 14:56:24 diag: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 9.39 end 46.22)
2026-11-20 14:59:08 landing: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 20.36 end 181.54)
2026-11-20 15:29:14 flow: PASS (28 of >= 28 tests; TEST SUCCEEDED; load start 19.94 end 5.00)
2026-11-20 15:52:16 rest: PASS (15 of >= 15 tests; TEST SUCCEEDED; load start 9.08 end 3.15)
2026-11-20 15:54:50 regstart: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 3.14 end 189.76)
2026-11-20 16:38:11 auth-light: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed:  ; load start 21.88 end 460.33; foreign: none)
2026-11-20 22:15:53 auth-light: retry skipped (load)
2026-11-21 00:31:09 auth-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 36.83 end 68.67)
2026-11-21 00:37:25 2fa-light: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 32.32 end 209.80)
2026-11-21 00:42:22 2fa-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 22.78 end 200.27)
2026-11-21 00:57:48 2fa-dark2: FAIL (passed 0 of >= 1; succeeded-marker 0; failed-marker 1; runner restarts 0; failed: PassYUITests.PassYUiR6ShotsTests/test_auth2FAScreens ; load start 23.28 end 2.87; foreign: none)
2026-11-21 00:58:59 2fa-dark2-retry: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 2.87 end 3.84)
2026-11-21 01:02:35 device-light: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 8.17 end 283.44)
2026-11-21 01:08:09 device-dark: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 27.60 end 169.09)
2026-11-21 01:13:42 device-light-b: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 16.03 end 167.22)
2026-11-21 01:19:26 device-dark-b: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 20.75 end 219.45)
2026-11-21 01:32:09 ui-r8: PASS (7 of >= 7 tests; TEST SUCCEEDED; load start 25.74 end 3.92)
2026-11-21 01:37:56 ipad-light: PASS (2 of >= 2 tests; TEST SUCCEEDED; load start 3.68 end 30.41)
2026-11-21 01:43:11 ipad-dark: PASS (2 of >= 1 tests; TEST SUCCEEDED; load start 24.63 end 15.64)
2026-11-21 01:45:07 ipad-landscape: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 21.23 end 136.88)
```

## summary-follow
```
2026-11-21 03:10:55 chain start (pid 61801)
2026-11-21 03:15:58 auth-light-b: PASS (1 of >= 1 tests; TEST SUCCEEDED; load start 7.32 end 143.80)
2026-11-21 03:28:00 perf-b: PASS (6 of >= 6 tests; TEST SUCCEEDED; load start 23.63 end 2.81)
2026-11-21 03:38:13 audit-b: PASS (5 of >= 5 tests; TEST SUCCEEDED; load start 5.94 end 2.51)
2026-11-21 03:38:14 follow2 done
```

## summary-compare
```
cmp-main: passed=3 failed=0 load { 7.70 43.37 41.60 }
R8CMP row_tap_name_opens_within_1_5s n=10 median=2.00 all=["2.07", "2.07", "2.00", "2.00", "1.99", "1.96", "1.99", "1.99", "1.98", "2.05"] opened=10/10
R8CMP row_tap_blank_opens_within_1_5s n=0 median=-1.00 all=[] opened=0/10
R8CMP tile_tap_to_list n=10 median=1.80 all=["1.88", "1.80", "1.77", "1.79", "1.81", "1.81", "1.78", "1.81", "1.75", "1.79"] 
R8CMP unlock_to_first_row n=3 median=1.60 all=["1.61", "1.60", "1.60"] 
cmp-r8: passed=3 failed=0 load { 3.37 30.52 39.56 }
R8CMP row_tap_name_opens_within_1_5s n=10 median=1.98 all=["2.08", "1.98", "2.01", "1.95", "1.98", "1.97", "1.94", "1.96", "2.02", "1.95"] opened=10/10
R8CMP row_tap_blank_opens_within_1_5s n=10 median=1.96 all=["1.95", "2.11", "1.95", "1.98", "1.95", "1.97", "1.96", "1.96", "1.93", "1.93"] opened=10/10
R8CMP tile_tap_to_list n=10 median=1.80 all=["61.98", "1.80", "1.79", "1.80", "1.80", "1.80", "1.78", "1.77", "1.78", "1.76"] 
R8CMP unlock_to_first_row n=3 median=1.56 all=["1.58", "1.56", "1.56"] 
compare done; temporary worktree and DerivedData removed
```

## Unit (after the LoginProcessor change)
```
unitF:  Executed 5923 tests, with 45 tests skipped and 0 failures (0 unexpected) in 86.264 (88.760) seconds | ✔ Test run with 732 tests in 78 suites passed after 1.168 seconds. | ** TEST SUCCEEDED ** | load { 19.12 28.29 30.13 }
FINALDONE
```
## perf-b (2000 items)
```
PERF scroll_30_fast_swipes median=40.57 all=["41.99", "40.57", "39.75"]
measured [CPU Time (passy), s] average: 4.091, relative standard deviation: 2.127%, values: [4.201023, 4.082264, 3.988363], performanceMetricID:com.apple.dt.XCTMetric_CPU-de.aiity.passy.time, baselineName: "", baselineAv
PERF search_exact_1999 median=7.90 all=["7.90", "7.94", "7.87"]
PERF single_tap_opens_item median=1.95 all=["2.05", "1.93", "1.95", "1.96", "1.93", "1.95", "2.10", "1.96", "1.93", "1.95", "1.93", "1.93", "1.92", "1.92", "2.00", "1.95", "1.96", "1.90", "1.94", "1.95", "1.96", "2.03", 
measured [Duration (TapToPush), s] average: 0.001, relative standard deviation: 13.691%, values: [0.001322, 0.001540, 0.001068, 0.001209, 0.001102], performanceMetricID:com.apple.dt.XCTMetric_OSSignpost-TapToPush.duratio
PERF unlock_to_vault median=2.73 all=["2.73", "2.76", "2.69"]
```
