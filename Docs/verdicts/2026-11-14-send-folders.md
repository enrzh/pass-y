# Validation: passy/send-folders (Send bottom bar, Folders list)

Validated commit: 362108ad0c77cb38c7e7aeedc647ab2976d7d414 (branch passy/send-folders, base main 80fbfef5d). Validator fixed nothing.

## Commands run
- git rev-parse HEAD; git status --short (clean); git diff main..HEAD --stat
- grep/read of SendListView.swift, SendBottomBar.swift, FoldersView.swift, PassYFlowTests.swift, README N8
- grep of ~/harness/runs/passy/{full8_unit,full8_vi,full8_kit,ui_full8,ui_full8b}.log
- viewed screenshots in Docs/screenshots
- curl http://127.0.0.1:8088/alive -> 200
- xcodebuild test -project Bitwarden.xcodeproj -scheme PassYUITests -destination id=$(cat /tmp/passy_ip) -derivedDataPath /tmp/passy-dd -only-testing:PassYUITests/PassYFlowTests/test16_createSendAndShowList -only-testing:PassYUITests/PassYFlowTests/test17_foldersListLastRowClearOfAddButton CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO

## Key output
- Own run: test16 passed (46.626 s), test17 passed (24.030 s), "** TEST SUCCEEDED **", exit 0 (load average ~2.5 at start)
- full8_unit.log: "Executed 5859 tests, with 45 tests skipped and 0 failures"; "Test run with 725 tests in 78 suites passed"
- full8_vi.log: "Executed 605 tests, with 17 tests skipped and 0 failures"
- full8_kit.log: 42 XCTest, 0 failures; Swift Testing 12 passed
- ui_full8.log: 23 tests, 4 failures (test09, test12, test13, test_perf_scroll); all others incl. test15/16/17 passed
- ui_full8b.log: the four rerun alone, 4 tests 0 failures, TEST SUCCEEDED
- diff stat: 12 files (FoldersView, SendBottomBar new, SendListView, its ViewInspector tests, VaultBottomBar access-level only, 5 screenshots, PassYFlowTests, README). No unexpected files.

## Per-claim verdict
1. Send tab: PASS (code + screenshots). SendBottomBar uses VaultSearchBarRepresentable and BarBackground (made non-private in VaultBottomBar, only change there), Menu with doc.text/doc symbols, direct button when restrictedSendType set; insetGrouped List, headers only when section.name != nil, formatted "\(name) (\(count))" (no Optional); .buttonStyle(.plain) present; send-list light/dark screenshots show "Types (2)", "All Sends (n)", bottom search + plus, no top search/FAB. Empty state with borderedProminent button present in code. Not run: restrictedSendType path visually, premium card absence only by grep (no match for "premium").
   - Issue (documentation, not code): Docs/screenshots/send-add-menu-light.png is stale. It shows the OLD Bitwarden illustration and a top search bar, not the new SF Symbol paperplane empty state. It is not part of this branch diff. It does not match claim 1 and no new-style empty-state screenshot exists. Empty-state visuals are therefore UNVERIFIED by image. Replace or re-shoot.
2. FoldersView: PASS. insetGrouped list, folder icon + chevron, safeAreaInset with FloatingActionButton.bottomOffsetPadding; folders-end light/dark show last row (Folder 11) clear above the add button; own test17 run passed.
3. Tests: PASS. SendBottomBar ViewInspector tests ran in the green VI run; test15, test16, test17 present and passed in the full run, test16/17 passed again in my run. test16 asserts the send is listed after relaunch, no 'Optional(' label, add control exists. Weakness: test16 depends on the vault's duplicate "PassY Send A" sends (list screenshots show 5-6 identical rows), so "is listed" would pass from leftovers and does not prove the new send was created. The Optional( check only guards against headers if a section header shown; fine.
4. Disclosures: Mac screenshot UNVERIFIED is honest and matches README N8. Lost harness verdict files noted, not checkable. Test16 redesign (one send, relaunch because the share sheet covers the list) is consistent with the test code and README.
5. Load-flake judgement for test09/12/13/test_perf_scroll: JUSTIFIED. Failure messages cited (vault list unreachable, MasterPasswordEntry tap) are login/unlock-stage failures before any Send/Folders UI is touched; the same code passed in the full run for neighbours and all four passed on isolated rerun; test09 took 426 s showing contention. These tests do not exercise the changed screens. Residual risk: flake causality is inferred, not proven by load logs.
6. README N8: HONEST, with the stale-screenshot caveat above (it embeds send-list-filled-light, send-list-filled-dark, folders-end-light, which are correct). "Not done" line retained.

## Overall verdict
PASS with notes: code and tests verified; fix or replace stale send-add-menu-light.png, and note test16 cannot distinguish a new send from leftover duplicates. Mac screenshot UNVERIFIED.
