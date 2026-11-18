# Verdict ui-r7 recheck (unabhaengiger Validator)

- Kandidat `passy/ui-r7`, HEAD `3cfd3b7e417c6b0d7d453eb0a47d0e2bb8fa62e7` (per `git rev-parse` bestaetigt), Base `f4567dce6`. Untracked `Bitwarden.xcworkspace/xcshareddata/` erhalten, keine Quelle geaendert, nichts heruntergeladen, Worktree `wt-r8` nicht beruehrt.
- Aufbau: eigener Cache `~/Library/Caches/passy-val/` (DerivedData-Klon, eigenes Vaultwarden 1.37.5 mit frischer DB, Konten frisch geseedet), ein xcodebuild zugleich, Gate 1-min-Load < 25 beim Start. Simulatoren PassY-R3 (Flow, Rest, Auth, Device, Roundtrip, Suche), PassY-2FA (2FA), PassY-iPad-R5 (iPad); Fresh-Install-Laeufe mit `PASSY_ERASE=1`.
- Lastoffenlegung: Die Maschine war durch fremde Prozesse stark belegt. Der Gate prueft nur den Start: 1-min-Load 2 bis 24 beim Start, aber 5-min-Load oft 50 bis 100 und End-Load bis 230. Alle Start-/End-Loads stehen in `~/Library/Caches/passy-val/out/chain*.txt`.

## Eigene Laeufe (Ergebnis | Start-1-min-Load)
| Lauf | Ergebnis | Load |
|---|---|---|
| Bitwarden-Unit voll | 5909 XCTest (45 skipped) + 729 Swift Testing, 0 Failures; xcresult 6598 passed / 45 skipped | 10.3 |
| Bitwarden-ViewInspector voll | 606 (589 passed, 17 skipped), 0 Failures | ruhig |
| Landing | gruen | 12.6 |
| Flow, frisch (erase) | **28/28 gruen** (besser als die Builder-Angabe 27/28; test23 war bei mir gruen) | 22.2 |
| Rest (Shots, ZAppearance, R5 voll, 3 R6-Listentests, ganze R7-Klasse, exportVault) | 18 Tests, 16 gruen, 2 skipped (die beiden `PASSY_KNOWN_ISSUE_TESTS`-Tests), 0 Failures; enthaelt Roundtrip und Suche | 4.4 |
| registrationStart allein | gruen | 2.3 |
| Auth hell / dunkel | gruen / gruen | 20.8 / 21.4 |
| Log in with device hell | **rot** ("Could not reach the vault list", Load 21, 5-min 58), **ein Einzel-Repeat gruen** (Load 20.5) | 21.4 / 20.5 |
| Log in with device dunkel | gruen | 22.9 |
| Roundtrip (17 Zeichen) allein | gruen | 21.9 |
| `test_homeSearchSelectDelete` zweimal (erst frisch, dann ohne Erase) | gruen, gruen | 19.3 / 18.5 |
| Gruppenliste (`test_selectModeDelete`, `test_swipeDelete`) | gruen | 22.3 |
| 2FA hell (PassY-2FA frisch) | gruen | 20.6 |
| 2FA dunkel | gruen | 21.1 |
| 2FA dunkel nochmal | **rot** (Authenticator-Screen nicht erreicht; Vaultwarden-Log: "Username or password is incorrect" fuer `passy-2fa`, 5-min-Load 99), **ein Einzel-Repeat gruen** (Load 24, 5-min 50) | 22.2 / 24.0 |
| iPad Shell hell | **rot** ("Could not reach the vault list", 612 s Laufzeit, Load 5.6 aber 5-min 61), **ein Einzel-Repeat gruen** (Load 18.8, 5-min 100) | 5.6 / 18.8 |
| iPad Shell dunkel, Landscape hell, Landscape dunkel | gruen, gruen, gruen | 9 / 21 / 22 |

Drei rote Erstlaeufe (Device hell, 2FA dunkel2, iPad hell) unter hoher Hintergrundlast; je ein Einzel-Repeat gruen. Ursache nicht bewiesen (Last plausibel, nicht belegt).

## Behauptungen
1. **Edit-Formulare: PASS fuer Namensfeld, Roundtrip. UNVERIFIED fuer Tippen in das maskierte Feld auf Geraet/Speichern auf Geraet.**
   - Name: freies Feld, Platzhalter statt Label; Render `editLogin` zeigt langen Namen ohne Label-Abschneiden; `test_addEditFormsAreInlineRows` (App, hell+dunkel, 326 s) gruen inkl. `name.minX < 60`.
   - Roundtrip gruen (2 Laeufe: eigener Einzellauf und im Rest): 17 Zeichen ueber das aufgedeckte Feld getippt, nach Speichern/Neuoeffnen entspricht die Bullet-Zahl der Laenge, aufgedeckter Wert identisch, "+edit" angehaengt, gespeichert, erneut verglichen, Item geloescht. Einschraenkung: der Test umgeht das maskierte Feld per Workaround, er beweist Speichern/Anzeige, nicht das Tippen.
   - Artefakt-Doku: Artefakte unter `~/Library/Caches/passy-devtest-out/` vorhanden; ihre `R7DIAG`-Zeilen (Geraet: langsam [1..6], schnell 12) stimmen mit der README ueberein. README ist ehrlich: "wahrscheinlich, nicht bewiesen", Ursache offen, Speichern auf Geraet unverifiziert. Offenes Risiko: Bleibt der Effekt auf einem echten Geraet doch bestehen, wuerden Passwoerter beim Tippen verstuemmelt; das ist nicht ausgeschlossen, nur nicht gemessen.
   - Das maskierte Passwortfeld ist in allen Renders leer (Snapshot-Capture); Punkte auf dem Bildschirm sind durch die Bullet-Zahl (XCUI-`value`) belegt, optisch nicht von mir als Screenshot beurteilt.
   - README-Fehler: nennt `test_editFormPasswordMaskedAndRevealed` ("compile but not run"); dieser Test existiert im Code nicht mehr (ersetzt durch den Roundtrip). Veraltete Aussage.
2. **Update/Remove Master Password + Item-Typen: UNVERIFIED als App-Verhalten; PASS nur als Render.** 20 Renders vorhanden und vom Test erzeugt (im gruenen Unit-Lauf). Angesehen: editLogin, editLoginRevealed, updateMasterPassword hell, removeMasterPassword dunkel, editBankAccount dunkel. Inline-Zeilen (Label links, Wert rechts, Picker-Chevron) sichtbar, Namensfeld frei. Maengel: Remove Master Password ist weiter ein Karten-/Pillen-Layout mit Fliesstext in der Karte (kaum Apple-Form), Titel "Update master passwo..." abgeschnitten. App-Screenshots der Edit-Formulare der Nicht-Login-Typen existieren nicht; `test_editFormOfEveryType` ist per `PASSY_KNOWN_ISSUE_TESTS` abgeschaltet (lief bei mir als skipped) und nicht ausfuehrbar gemacht.
3. **A11y: Avatar-Kontrast PASS; Vorher/Nachher UNVERIFIED (README ehrlich).** README zieht "7->6 / 6->4" ausdruecklich zurueck und nennt den Vergleich "nicht vergleichbar". Mein Audit (Rest-Lauf, `test_voiceOverLabels` gruen): Home 6 Meldungen (1x Kontrast auf unbenanntem Node, Dynamic Type Favorites/Anzahl/PT), Item 4 eindeutige Zeilen; kein Kontrastfehler fuer `[PT]`, kein `131072`-Clipping, kein `[Login credentials]`. Die neuen Asserts greifen also. Avatar: `darkening(for:)` per Farbe, 2 Unit-Tests gruen; sie rechnen mit derselben Formel wie der Produktcode (zirkulaer), geprueft sind 9 Farben, der Fall "Cap 0.6 erreicht" wird nicht geprueft; der reale Nachweis ist nur der Audit mit einer Kontofarbe. Kein Before/After-Lauf von mir.
4. **Absturz Home-Suche: PASS.** Diff gelesen: Liste wird bei geaenderter Ergebniszeilen-Menge per `.id(searchResults.map(\.id))` neu aufgebaut, Edit-Modus-Ausstieg 500 ms verzoegert (Gruppenliste gleich). Zweimal gruen plus Gruppenliste gruen. Vorbehalte: Timing-Workaround (Wurzelursache in SwiftUI nicht belegt), `.id` setzt bei jeder Ergebnisaenderung Scroll-Zustand zurueck; keine Datenwirkung. Auswahl-IDs (`VaultListItem.id`) und Cipher-IDs werden in `applyBulkOutcome` gleichgesetzt; durch Unit-Tests und Lauf gestuetzt.
5. **2FA hell/dunkel/dunkel: PASS mit Flaky-Offenlegung; Robustheit UNVERIFIED.** Diff: nur Passwort ueber aufgedecktes Feld getippt (Fallback `replaceText` bleibt), Asserts unveraendert, kein Test entfernt oder abgeschwaecht. Meine Laeufe: hell gruen, dunkel gruen, dunkel2 rot (Server-Log: Passwort abgelehnt, obwohl ueber das aufgedeckte Feld getippt), Repeat gruen. Damit ist die README-Erklaerung (b) "Tippfehler im maskierten Feld" nicht vollstaendig: ein Tippfehler trat auch mit dem Workaround auf (unter Last). Erklaerung (a) (App-Zustand ueberlebt Uninstall, geloest durch Erase) ist durch meine gruenen Fresh-Laeufe gestuetzt. Der Test selbst ist schwach (Assert nur: 2FA-Screen erreicht; Recovery-Schritt bedingt).
6. **`performDelete` leere ID-Liste ohne Erfolgs-Toast: PASS** (2 Unit-Tests im gruenen Unit-Lauf, Code gelesen).
7. **Ergebniszahlen des Builders: PASS (Unit 5909+729, VI 606, Landing, registrationStart, Auth, Device, iPad, Rest, Flow).** Abweichung nach oben: Flow 28/28 statt 27/28. Rote Erstlaeufe bei Device hell, 2FA dunkel2, iPad hell unter Last mit Einzel-Repeat gruen (oben).

## Diff-Pruefung (`f4567dce6..HEAD`, 92 Nicht-Bild-Dateien)
- Keine entfernten/abgeschwaechten Tests: im Diff nur drei geaenderte Altzeilen in Tests (Tap-Koordinate test03 `dx 0.98` bei unveraendertem Assert, erweiterte Audit-Logzeilen, 2FA-Passworteingabe) und Hinzufuegungen. Die 45 Skips im Unit-Lauf sind dieselben wie im Base-Stand (Profile-Switcher, Landing u. a., keine neuen).
- `PASSY_KNOWN_ISSUE_TESTS` ueberspringt genau zwei neue Tests: `test_editFormOfEveryType` (haette App-Screenshots aller Typen geliefert) und `test_secureFieldTypingDiagnostic` (dokumentiert den offenen Tippbefund). Beides steht in README/Testing.md/Skip-Meldung, also ehrlich, aber die Abschaltung nimmt genau die Pruefung weg, die Claim 2 belegen wuerde.
- Datenwirksam: `CipherBulkActions` (Soft-/Permanent-Delete, Move) je ID einzeln, fehlende Cipher = Fehler, kein "geloescht"-Toast, Fehlgeschlagene bleiben markiert: Code in Ordnung, Unit- und UI-Laeufe gruen. Home-Suche loescht jetzt (weich) mit Bestaetigung. `appeared()` laedt zusaetzlich Ordner, Fehler werden zu leerer Liste verschluckt (Move-Menue dann nur "No folder"). Icon-Loader verwirft nur die Vaultwarden-1.37.x-Globe-Bytes per SHA-256; andere Serverversionen zeigen ihr Globe (nur Optik).
- Kein Scope-Creep gefunden (Edit-Zeilen, Bulk-Aktionen, Suche, Avatar, Icon-Loader, Scripts, Docs, README, Screenshots).
- README-Unstimmigkeiten: veralteter Verweis auf `test_editFormPasswordMaskedAndRevealed`; zwei konkurrierende Zahlen im Block (Unit 5907 vs 5909, die 5909 ist durch meinen Lauf bestaetigt).

## Gesamturteil: **PASS (mit UNVERIFIED-Punkten, kein ungeloestes Rot)**
- PASS: Unit, ViewInspector, Landing, Flow 28/28, Rest, registrationStart, Auth, Device-Login, iPad, 2FA (je nach Einzel-Repeat), Roundtrip, Home-Suche-Absturzfix (2x), Gruppenliste, performDelete-Toast, Diff ohne abgeschwaechte Tests.
- UNVERIFIED: Tippen und Speichern eines Passworts im maskierten Feld auf einem echten Geraet (Simulator-Artefakt weiter nur Hypothese), App-Screenshots der Edit-Formulare der Nicht-Login-Typen und von Update/Remove Master Password (nur Renders), Audit-Vorher/Nachher, Robustheit des 2FA-Tests, iOS < 26 Zeile.
- Unter Last drei Einzel-Rote (Device hell, 2FA dunkel2, iPad hell) nur per Wiederholung gruen; keine Regression im Code nachgewiesen.
