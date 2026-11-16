# Verdict ui-r5 Recheck (unabhaengiger Validator)

- Kandidat: `passy/ui-r5`, HEAD `0a9889d2f75b42644dedff1311c3584b71e1180d` (per `git rev-parse HEAD` bestaetigt), Base `7e1cf6c02`, vorher `0a000301f` (FAIL). Untracked `Bitwarden.xcworkspace/xcshareddata/` erhalten; `git status` nach den Laeufen: nur diese beiden untracked Pfade (Verdict ui-r5 + dieses), keine Aenderung an getrackten Dateien (Unit-Lauf hat keine Snapshot-Referenzen neu geschrieben).
- Umgebung: Vaultwarden `/tmp/passy-vw/.../vaultwarden`, alte Instanz beendet, frische DB `/tmp/vw-data-val7`, Port 8088, Env wie im Brief; `/api/config` meldet `pm-32009-new-item-types: true`. `seed_account.py`, `seed_ciphers.py 25`. Simulator PassY-R3 (iPhone), PassY-iPad-R5. Skripte `/tmp/val7_*.sh` (warten auf Load < 8), eigener DerivedData `/tmp/passy-val7-dd`, Logs `/tmp/val7out/`. Load beim Start jedes Laufs 2 bis 6.9 (hoechster: Flow 6.92, also unter 8). Ein xcodebuild zugleich. Kein Hang noetig zu beenden.

## Eigene Laeufe
| Lauf | Ergebnis |
|---|---|
| Bitwarden-Unit | 5865 XCTest (45 skipped) + 726 Swift Testing, 0 Failures, TEST SUCCEEDED; PassYScreenSnapshotTests (6) bestehen gegen die neuen Referenzen |
| Bitwarden-ViewInspector | 604 Tests (17 skipped), 0 Failures |
| PassYLandingShotsTests (nach Uninstall) | gruen |
| PassYFlowTests (nach Uninstall, frische DB, ein Lauf) | 28 Tests, 0 Failures, 1030 s |
| rest (10 Tests): test_shots, test_exportVault, test_darkMode, **test_largeText**, test_compare, **test_dynamicTypeForms**, test_newTypeForms, test_voiceOverLabels, **test_addMenuAccessibilityXXXL**, test_ipadShell (iPhone) | 10/10 gruen, 0 Failures |
| **test_largeText einzeln auf dem Kandidaten** | gruen (44 s) |
| test_registrationStart allein nach Uninstall | gruen |
| test_ipadShell hell und dunkel (iPad, `simctl ui appearance`) | beide gruen |
| Bitwarden-Snapshot | nicht gelaufen (leer, 0 Tests, unveraendert zu ui-r5-Verdict): fuer Abdeckung UNVERIFIED |

## Behauptungen
1. test_largeText / Add-Menue-Reihenfolge: **PASS.** test_largeText gruen (im Gesamtlauf und einzeln), neuer Test `test_addMenuAccessibilityXXXL` gruen. Screenshot `after/fix-r5-01-axxxl-add-menu.png` angesehen: Login/Card/Identity/Secure note sichtbar, Login am unteren Ende (naechst zum Button), Rest scrollt. Die Ursache (7 Typen, Menue scrollt, Login war zuletzt) ist plausibel und das Diff passt (`passYAddMenuOrdered`, nur Reihenfolge, in Home und Gruppenliste). Hinweis: der neue Test prueft nur `menuItems["Login"].exists || Button "Login"`; eine strenge Assertion der Reihenfolge fehlt. Warum der Lauf auf Base/vorher gruen war, nicht geprueft (UNVERIFIED, nicht noetig).
2. test_dynamicTypeForms harte Asserts + Bild: **PASS.** Diff zeigt `XCTAssertTrue(openAdd(...))` statt `if`; Test gruen; `after/fix-r5-02-accessibilityxxxl-add-login.png` existiert und zeigt "Add login" bei AX-XXXL (Item name, Folder, Login credentials; sehr gross, aber lesbar).
3. test21 Mindesthoehe 96: **PASS.** Diff 88 -> 96, test21 im Flow-Lauf gruen.
4. Read-only-Feldstil, Buchstaben-Icons, iPad-Lesebreite 760, Avatar ScaledMetric, Kachel-Kontrast: **PASS** (Code im Diff, Flow/Unit/VI gruen, Bilder angesehen). Details unter Optik. Einschraenkung: Der Wert wird mit `opacity 0.6` abgeblendet (nicht echte Systemfarbe); Edit-Formulare unveraendert (Diff: nur bei `isReadOnlyFieldStyle`). PIN-Entsperrung war schon natives Form (Behauptung nicht separat verifiziert; README-Korrektur plausibel, Screens `pinUnlock.*` vorhanden). Nicht gemachte Punkte (Chevron statt "...", Section-Header-Kontrast, "N items"/Select) sind im README als "not done" offen genannt: stimmt mit dem Code ueberein.
5. Testzahlen: **PASS** (Unit 5865+726, VI 604, Landing, Flow 28 in einem Lauf auf frischer DB, Rest, reg, ipad hell/dunkel: alle selbst bestaetigt).
6. SSH-Key-Snapshot-Neuaufnahme legitim: **PASS.** Alt (0a000301f) zeigte Private key/Public key/Fingerprint inline (Label links, Wert rechts, im Edit-Formular), neu stapelt Label ueber Wert wie in allen Edit-Formularen. Das ist genau die behauptete Aenderung (Inline-Layout nur im Read-only-Stil). Inhalt sonst identisch (Titel, Felder, Werte), keine Abschwaechung; kein Test geloescht, keine Toleranz erhoeht. Gegen die neuen Referenzen laufen die 6 Tests gruen.

## Scope-Diff
`0a000301f..HEAD`: 16 nicht-PNG-Dateien (139 +/33 -): UI-Code (BitwardenField, NativeForm, PassYShellModel, ViewSendItemView, VaultGroupView, VaultAddMenuView, VaultListItem, VaultListView, ViewItemDetailsView, ViewItemView, CategoryTilesView, VaultItemDecorativeImageView, VaultListItemRowView), PassYFlowTests (nur test21 verschaerft), PassYUiR5ShotsTests (Asserts verschaerft, neuer Test), README, ca. 50 PNG. Kein Scope Creep: keine Logik, Daten, Netzwerk, Repository- oder Gating-Aenderung; `passYAddMenuOrdered` aendert nur die Anzeigereihenfolge (`shouldUseCustomPlaceholderContent` in VaultListItem nur Anzeige). Keine Tests entfernt oder abgeschwaecht. Gegen Base `7e1cf6c02` insgesamt weiterhin nur UI, Tests, README, Screenshots (Stichprobe der Diff-Dateiliste, kein Voll-Review der ersten 5 Commits, die im ersten Verdict schon geprueft wurden).

## Optik vs. ref/ (Bilder angesehen)
- Detail (`fix-r5-03-light-detail`) vs `ref-04`: jetzt Label schwarz links, Wert grau rechts, Buchstaben-Quadrat "B" statt Globus, zentrierter Titel, Rounded-Square-Icon: deutlich naeher an Apple. Offene Abweichungen: Sheet-Titel "View login" + X statt Zurueck-Pfeil, Sektion "Login credentials", Kopier- und Augen-Icons, Stern, "..." im Header, blauer "Check password for data breaches", Edit blau; "No Folder" Zeile; Created/Last edited Text. Weiter klar mehr Bitwarden als Apple.
- Liste (`fix-r5-02-light-list`): 40-pt-Rounded-Square-Icons, fette Titel, Buchstaben fuer B/G/N. **Abweichung/Luecke:** die 25 "Perf Item"-Eintraege zeigen weiter ein Globus-Icon (Web-Icon-Platzhalter, vermutlich weil sie eine URI haben); "Letter icons instead of globe" gilt damit nur fuer Logins ohne URI. "..." statt Chevron, "Items (28)" statt Untertitel, keine Auswahl: offen, im README genannt.
- Home (`fix-r5-01-light-home`): Large Title "My vault" (kleiner als Apples fetter "Passwords"), 2-Spalten-Kacheln, Zaehler jetzt dunkler; 10 statt 6 Kacheln, Avatar oben rechts. Nahe an Apple.
- AX-XXXL Add-Login: sehr grosse Typo, Titel/Labels brechen um, Formular nutzbar, aber "Login credentials"-Header riesig und Zeilen stapeln (erwartet bei AX-XXXL).
- iPad: `after/fix-r5-11-ipad-landscape-list.png` ist **seitlich gedreht** (nicht aufrecht, iPhone-Format 1206x2622): die Landscape-Bilder in `after/` sind nicht verwertbar; die README sagt, die Bilder in `ipad/` seien aufrecht gedreht (nicht erneut einzeln angesehen). Lesebreite 760 pt dort nicht visuell von mir geprueft (UNVERIFIED), nur im Code und mit gruenem ipadShell-Test.
- Auth-Seiten/PIN: nicht neu bewertet (unveraendert zum ersten Verdict, weiter weisse Karten bei Auth, weit weg von Apple).
Gesamt Optik: ehrlich etwa 70 % Annaeherung an Apple Passwords auf Home/Liste/Detail-Werte; Header, Sheet-Chrome, Edit-Formulare, Auth bleiben Bitwarden-typisch. Alle bekannten Abweichungen sind im README genannt, ausser dass Perf-Items weiter Globus zeigen (hier offengelegt).

## UNVERIFIED / nicht geprueft
- Bitwarden-Snapshot (0 Tests), PassYPerfTests, echtes iPhone und VoiceOver, Extensions/Watch/Duo, Auth-Screens in der laufenden App, AX-Renders der Auth-Screens.
- iPad-Lesebreite 760 pt visuell, iPad-Landscape-Bilder (die Dateien in `after/` sind seitlich).
- Ob `test_largeText` auf `7e1cf6c02` gruen/rot war (nicht gelaufen).
- Vaultwarden-Tag 1.37.5 (Binary meldet gitHash 6ed6921c, nicht gegen Tag geprueft).
- Strenge Assertion der Menue-Reihenfolge fehlt im Test (nur Erreichbarkeit von Login).

## Gesamturteil: **PASS**
Alle sechs Behauptungen bestaetigt (1 bis 6), der zuvor fehlgeschlagene `test_largeText` ist auf dem Kandidaten gruen und das stille Skip ist durch harte Asserts samt AX-XXXL-Bild ersetzt, alle Testlaeufe gruen auf ruhiger Maschine, keine Abschwaechung, kein Scope Creep. PASS bezieht sich auf die Fix-Round-Behauptungen und die genannten Testlaeufe; "Apple-Passwords-aehnlich" gilt nur teilweise (siehe Optik), und die UNVERIFIED-Punkte bleiben offen.
