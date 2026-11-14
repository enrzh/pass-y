# Validator verdict: passy/importreg (2026-11-14)

Candidate commit: eaaead32f (base main 80fbfef5d). Validator: fresh general-purpose subagent (sonnet), read-only.

Overall verdict: PASS (points 1-4), UNVERIFIED for real-tap evidence (point 5 / UI tests).

1. PASS: `git diff main..eaaead32f --stat` -> 42 files, +925/-549; `git diff --name-only | grep -Ei 'Processor|State\.swift|Service|Coordinator'` -> no hits (exit 1).
2. PASS: accessibility identifiers preserved (ExportSettings ids now set via row helper `.accessibilityIdentifier(id)`, grep artifact). No ViewInspector test deleted/commented; StartRegistration region test was XCTSkip in main and is now active; locators adapted (TextField/Picker/identifier based). Note: confirm-file-password test uses findAll(...)[1].
3. PASS: iOS 15 target; scrollContentBackground only inside `#available(iOS 16, *)` helper `passYNativeFormBackground()`; LabeledContent/toolbar(.hidden) replaced or guarded.
4. PASS: `/tmp/passy-ir-vi.sh -only-testing:...(9 classes)` -> EXIT=0, "Executed 47 tests, with 3 tests skipped and 0 failures" (skips pre-existing toggle tests). Full runs by builder: ViewInspector plan "Executed 607 tests, with 16 tests skipped and 0 failures" EXIT=0; Unit plan "Executed 5859 tests, with 45 tests skipped and 0 failures" + Swift Testing 725 passed, EXIT=0.
5. UNVERIFIED overall / PASS visual: 5 screenshots (reg-complete-dark, export-vault-encrypted-light, 2fa-email-dark, import-logins-intro-light, import-cxf-dark) show native Form look with visible cards in dark mode. They come from a render test (PassYImportRegRender+ViewInspectorTests), not real taps. UI tap tests (PassYUITests/PassYImportRegShotsTests) failed on host overload: "Failed to prepare device for impending launch / Timed out while preparing execution worker" (load average 400-800).
