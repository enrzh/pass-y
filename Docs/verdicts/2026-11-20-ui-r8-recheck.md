# Verdict ui-r8 Recheck (unabhaengiger Validator, frische Session)

Kandidat `094cd1b77` (git rev-parse in wt-r8 vor der Loeschung = 094cd1b77433089267ceea5e29afcde5da2f9eed). Vorgaenger e8f65a1e1 = FAIL. Nichts an der Quelle geaendert, nichts gepusht/gemergt. Quelle fuer die Wiederholung: `git archive 094cd1b77` nach `~/Library/Caches/passy-vw-val/wt` (Projekt per xcodegen neu erzeugt, generierte Dateien aus main kopiert).

## GESAMT: FAIL

Gruende: (1) device-dark rot 2 von 2 (kein gruener Lauf); (2) Vorfall (Fremdloeschung, siehe unten) hat die Umgebung zerstoert: PassYUiR8Tests, Compare 10/10, iPad (hell/dunkel/quer), Perf, Audit konnten **nicht** laufen = UNVERIFIED. Es gibt keinen Beleg, dass die Kernbehauptung (Tap auf leere Zeilenflaeche, 10/10) auf 094cd1b77 haelt. Kein PASS moeglich.

## Pro Behauptung

| # | Behauptung | Urteil |
|---|---|---|
| 1 | test02 Folder-Helper, UiR8Tests 7/7 3x, ShellBarHitTests | **UNVERIFIED** (UiR8Tests nie gruen gesehen; ShellBarHitTests Teil von Unit = PASS) |
| 2 | Flow test02 war Test-Race, Flow 28/28 | **PASS** |
| 3 | Dunkelmodus echt dunkel, Launch-Argument sicher | Rendering **PASS** (mit Einschraenkung), Hook-Sicherheit **Befund M1** (nicht #if DEBUG), device-dark **FAIL** |
| 4 | Kette strikt, xcodebuild per PID beendet | **PASS** (Skript gelesen; fing Worker-Timeout und Test-Rot korrekt) |
| 5 | Kettenergebnisse | **FAIL** (device-dark rot) / Rest UNVERIFIED |
| 6 | Unit 5922 + 732, VI 612 | **PASS** |
| Kern | Root Cause (Button einziges A11y-Element), blank-tap main 0/10 vs r8 10/10 | Code-Mechanismus per Diff plausibel; Zahl **UNVERIFIED** (Compare nicht gelaufen) |

## Gemessen (eigene Laeufe, eigene Sims PassY-VAL8B/-2FA/-iPad iOS 27.0, eigenes Vaultwarden :8090, nur de.aiity.passy + Runner geprueft ausser Vorfall)
- Unit (Bitwarden-Unit): 5922 XCTest (45 skipped, 0 Failures) + 732 Swift Testing/78 Suiten, `** TEST SUCCEEDED **` (Load beim Lauf bis 46).
- ViewInspector: 612 (17 skipped, 0 Failures), `Test Suite 'All tests' passed`, danach haengt xcodebuild ohne Marker (bekannt); von mir per PID beendet.
- Kette (strikt: TEST SUCCEEDED, kein Failing tests/TEST FAILED/Runner-Restart, Mindestanzahl): diag PASS, landing PASS, **Flow 28 von >=28 PASS** (frisch erase, Load beim Start 28.9), **rest 15/15 PASS**, regstart PASS, auth-light PASS, **auth-dark PASS**, 2fa-light PASS (der Recovery-Code-Safari-Screenshot ist jetzt vom Check ausgenommen, Schritt gruen im 1. Lauf), 2fa-dark2 PASS, 2fa-dark: 1. Lauf FAIL ("Timed out while preparing execution worker", Load bis 344, kein Test lief), Wiederholung PASS.
- device-light: 1. Lauf FAIL ("Could not reach the vault list" nach 180 s, Load 85-96 im Lauf), Wiederholung PASS (Load 198-356). Offenes Risiko: der 180-s-Deadline-Helper reicht unter Last nicht.
- **device-dark: 1. Lauf (vor Vorfall) FAIL ohne gelesene Ursache; nach Wiederaufbau 2 Laeufe (Load 6.8 / 7.6) FAIL**: `known device: Log in with device is offered` rot, `LogInWithAnotherDeviceButton` fehlt, Bildschirm zeigt nur die Master-Passwort-Anmeldung. Der Pixel-Check dieser Laeufe: `r8-dev-dark-50-dark-login-known-device expected=dark luminance=0.00 ok=true` (dunkel belegt). Ursache der Rotbefunde nicht geklaert (Verdacht Server-Zustand/Known-Device, wegen des gleichzeitig degradierten Vaultwarden nicht trennbar) = ungeloestes Rot, zaehlt als FAIL.
- Danach Vaultwarden kaputt (siehe Vorfall): PassYUiR8Tests 7/7 rot mit "Could not reach the vault list" in allen Tests; das ist **kein** Produktbefund, nur Umgebung, und zaehlt als UNVERIFIED.

## Vorfall (nicht von mir verursacht)
Gegen 09:53-10:04 wurde `~/Library/Caches/passy-vw` komplett ueber `~/.Trash` geloescht und der Papierkorb geleert: wt-r8, wt-main, out-r8, alle DerivedData, Vaultwarden-Binary und -Quelle, alle meine Logs, xcresult-Buendel und Screenshots der ersten Kettenhaelfte. Der Server lief danach mit leerer DB weiter (500 bei Registrierung); ohne Binary/Quelle kein Neustart moeglich (Download verboten). Deshalb: **keine Screenshots der ersten Kettenhaelfte angesehen** (Pixel-Assertion im Test ist dafuer der Beleg: auth-dark/2fa-dark/2fa-dark2 liefen gruen, die Assertion schlaegt bei Luminanz >= 0.35 fehl), Luminanzwerte der Dunkellaeufe nicht ausgelesen.
Mein eigener Fehler: um ~07:35 `xcrun simctl shutdown all` fuhr auch die fremde, gebootete Sim DayCheckSummary herunter (haette gezielt per UDID geschehen muessen). Moeglicher, nicht bewiesener Zusammenhang: spaeter lag eine fremde App `de.aiity.day` auf meiner Sim; die Kette hat sie per Erase der eigenen Sim bereinigt.
Last: viele Schritte starteten mit 1-Min-Load >= 25 (Fremdlast, z.B. 2fa-light 82, device-light-retry 198); ein Durchlauf pro UI-Fehler (Wiederholung), beide Laeufe oben genannt. Meine 3 Sims sind per UDID heruntergefahren, mein Vaultwarden-Prozess beendet.

## Code-Review (git diff d87f0d091..094cd1b77, aus Git-Objekten)
- **M1 Produktionshook:** `AppProcessor.swift:160-168` liest `UserDefaults.standard.string(forKey: "passyForceInterfaceStyle")` und ueberschreibt damit `overrideUserInterfaceStyle` beider Fenster. **Kein `#if DEBUG`**, also in Release-Builds aktiv; `UserDefaults.standard` ist nicht nur Launch-Argument, sondern jede Defaults-Quelle der App (auch ein gesetzter Schluessel/MDM-Preference). Wirkung: nur Hell/Dunkel-Darstellung, setzt die Nutzer-Themeneinstellung ausser Kraft; keine Daten-/Sicherheitswirkung. Empfehlung: `#if DEBUG` (UI-Tests laufen Debug) oder Test-Flag. Nicht blockierend, aber die Vorgabe "inert in Release" ist nicht erfuellt.
- Zeilen-A11y: Button einziges Element (Label aus Name+Untertitel, Identifier `VaultListItemRowButton`, More-Options-Custom-Actions am Button, Kontextmenue erhalten, Chevron hidden). Container-Identifier `CipherCell` entfaellt fuer Vault-Zeilen (FoldersView behaelt `FolderCell`), `vaultItemAccessibilityId` bleibt nur noch fuer Unit-Test. `test_voiceOverLabels` lief in `rest` PASS; echter VoiceOver-Durchgang UNVERIFIED.
- `VaultListRowCell` ist `Equatable` nur ueber den State (Closures ignoriert): Risiko bei kuenftig geaenderten Closures bei gleichem State; kein Fehler heute.
- Tests: keine geloeschten Tests, keine neuen Known-Issue-Skips. Entfernt wurden die `XCUIDevice.appearance`-Aufrufe (ersetzt durch `setPassYAppearance` + Launch-Argument) und 3 In-App-Dunkel-Screenshots in `PassYImportRegShotsTests` (jetzt nur wenn real dunkel: `attachDarkIfRendered`, im Lauf `rest` 15/15 gruen) = leichte Abdeckungsminderung, offen dokumentiert in README. Flow `ensureUnlockedVault` wartet jetzt auf den Vault-Button (Deadline 180 s).
- Recovery-Code-Screenshot: oeffnet Safari, weil `TwoFactorAuthProcessor` `environmentService.recoveryCodeURL` (Web-Vault) oeffnet (Upstream-Verhalten); fuer ui-r9 wie von Enrico gewuenscht Web-Vault-Links entfernen.

## Was fuer ein PASS nachzuholen ist
PassYUiR8Tests (7/7, insb. test02), Compare 10/10 auf ui-r8, device-dark (Ursache klaeren), iPad hell/dunkel/quer, Perf 6/6, Audit 5/5, Screenshots ansehen, M1 mit `#if DEBUG` schliessen; Last-Robustheit des Login-Helpers (180 s) pruefen.
