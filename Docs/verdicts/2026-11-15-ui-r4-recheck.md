# Verdikt ui-r4 Recheck (unabhaengige Validierung, 2026-11-15/16)

Kandidat: Branch `passy/ui-r4`, `git rev-parse HEAD` = 726077dedb2dc734842949db19ca54f7f6e4cb66 (verifiziert; Basis main bbaa5f4ad; vorheriger Kandidat b2b9a72f3). Arbeitsbaum: nur untracked `Bitwarden.xcworkspace/xcshareddata/` (erhalten). Kein Quellcode vom Validator geaendert.

## Umgebung
- Alter Vaultwarden (PID 83760) beendet; frische DB `/tmp/vw-data-val5`; Binary release-1.37.5, Env wie gebrieft (Port 8088, LOGIN_RATELIMIT_SECONDS=1, BURST=1000, SIGNUPS_ALLOWED=true, WEB_VAULT_ENABLED=false).
- `seed_account.py` (200 registered), `seed_ciphers.py 25`: Ausgabe `fixture GitHub`, `fixture Netflix`, `fixture Bank`, `seeded 25`. Zweiter Aufruf `seed_ciphers.py 0`: keine Fixture-Zeilen (idempotent, bestaetigt).
- Simulator PassY-R3 (3AF691E6-...), vor jedem UI-Lauf `simctl uninstall de.aiity.passy`. Seriell via `/tmp/val5_run.sh` (Logs `/tmp/val5_out/`) und `/tmp/val5_rerun.sh`.
- Maschinenlast stark schwankend (bis Load ~270 durch fremde Sessions). Der erste Lauf von rest/reg/Unit ist unter dieser Last abgebrochen (siehe unten); wiederholt mit Wartebedingung Load 1min < 8.

## Befehle und Zahlen
- `PassYLandingShotsTests`: TEST SUCCEEDED.
- `PassYFlowTests` komplett, EIN Lauf, frische DB, frische Installation, OHNE vorheriges test_shots: **27 Tests, 0 Failures** (1441 s, unter hoher Last; 27x passed im Log). Die fuenf frueher fehlgeschlagenen Tests (test10, 12, 18, 20, 25) sind gruen.
- Erster Lauf `rest` und `reg` (22:46/22:53): TEST FAILED durch Infrastruktur (Runner-Absturz "Early unexpected exit ... handleStalledWait", CoreSimulator "Shutdown"/Mach error -308) bei Load ~250. Nicht gewertet, wiederholt.
- Wiederholung `rest2` (Load < 8): `test_exportVault` 66.6 s, `test_shots` **74.3 s**, `test_darkMode` 51.2 s, `test_largeText` 48.3 s: 4 Tests, 0 Failures. `reg2` `test_registrationStart` allein nach Uninstall: gruen (28.7 s).
- `Bitwarden-ViewInspector`: 604 Tests (17 skipped), 0 Failures, TEST SUCCEEDED.
- `Bitwarden-Unit`, erster Lauf: TEST FAILED, weil `SendListProcessorTests.test_perform_search_error` unter Load ~250 das 10-Minuten-Limit riss (waitFor-Timeout). Nicht gewertet. Wiederholung `unit2` (Load < 8): **5859 XCTest (45 skipped), 0 Failures; Swift Testing 726 Tests in 78 Suites passed; TEST SUCCEEDED.**

## Diff-Check b2b9a72f3..HEAD (23 Dateien, +175/-39, davon 10 PNG)
- Keine Testfunktion entfernt oder auskommentiert, keine Assertion gestrichen. Scope: nur Tests, Seed-Skript, README, 10 PNG, Verdict-Datei; kein Produktcode geaendert.
- `replaceText` (Login-Retry): leert das Feld vor erneutem Tippen, loest einen echten Testfehler (angehaengter Text); schwaecht keine Assertion. Legitim.
- test03 `focusSearch` (sorgt fuer Tastatur-Fokus, Assertions unveraendert): legitim.
- test26: prueft zusaetzlich Item-Edit-Abbruch und Send-Add (SendNameEntry, native Liste, Deletion-Date-Zeile). test27: else-Zweig weg, verlangt Setup-Zeilen, tippt Dismiss, prueft Verschwinden. Verschaerft, nicht abgeschwaecht.
- Kleiner Mangel (kein Blocker): in test27 ist `XCTAssertFalse(app.buttons["Turn on now"].exists && !action.exists)` praktisch immer wahr (action existiert laut vorheriger Assertion), also wirkungslos; die uebrigen Assertions tragen den Test.
- ViewInspector: Titel/Aktion pro Screen wieder geprueft (`find(setupSection:)` per Headline; getStarted+dismiss; Beschreibungstext fuer AutoFill/Import; Hidden-Faelle pruefen Section und Aktion; Label-Check fuer SSO/PasswordHint-Textfeld). Schaerfer als b2b9a72f3. Badge "1" weiter nicht geprueft (Badge gewollt entfernt).

## Verdikte pro Behauptung
1. Fresh-DB-Fixtures per `seed_ciphers.py`, PassYFlowTests 27/27 in einem Lauf ohne test_shots: **PASS** (Evidenz oben; Seed idempotent bestaetigt).
2. test26 prueft Item view/edit und Send add; test27 ohne else-Zweig, muss Section sehen und wegklicken: **PASS** (Diff + gruener Lauf; Nebenmangel s.o.).
3. ViewInspector-Tests geschaerft (Titel/Beschreibung/Aktionen pro Screen): **PASS** (Diff gelesen; 604 gruen).
4. `s1-after-light/dark-10` vs `-11-add-login` unterscheiden sich, 11 zeigt Scroll-Ende: **PASS** (md5 alle vier verschieden; light und dark 11 selbst angesehen: Ende der Liste mit "Additional options", "Add website", kein Folgeinhalt).
5. test_shots-Langsamkeit war Maschinenlast, keine Regression: **PASS (mit Einschraenkung)**. test_shots 74 s bei ruhiger Maschine; Laeufe bei Load ~250 liefen amok (Runner-Abstuerze, Unit-Timeout). Kein Vergleichslauf auf main, daher "keine Regression" nur indirekt belegt (ui-r4 aendert dafuer keinen Produktcode, nur Tests).
6. Login-Retry- und test03-Fixes legitim, keine Abschwaechung: **PASS** (Diff).
7. Testplaene: Unit 5859 + 726, ViewInspector 604, Landing, exportVault, shots, darkMode, largeText, registrationStart: **PASS** (jeweils nach Wiederholung bei ruhiger Maschine; die unter Last fehlgeschlagenen Erstlaeufe wurden nicht gewertet und sind oben offengelegt).

## Gesamt: PASS
Der FAIL-Punkt des Vorlaufs (Flow 27/27 in einem Lauf auf frischer DB) ist behoben und belegt. Kein Produktfehler, keine Testabschwaechung gefunden.

## UNVERIFIED (unveraendert aus dem Vorverdikt)
Login with device, Set master password, 2FA-Screens (kein Screenshot); Add-Formulare bank/passport/driver license/SSH; iPad dark/Landscape/Sidebar; Dynamic Type fuer die neuen Forms; VoiceOver; Extensions/Watch; Send im Share-Extension; Bitwarden-Snapshot, PassYPerfTests, PassYAuditShotsTests nicht gelaufen; echtes iPhone; "test_shots keine Regression" nur indirekt (kein main-Vergleich); Apple-Passwords-Aehnlichkeit subjektiv. Der Flow-Lauf (1441 s) lief bei hoher Maschinenlast; er war gruen, die Dauer ist nicht aussagekraeftig.
