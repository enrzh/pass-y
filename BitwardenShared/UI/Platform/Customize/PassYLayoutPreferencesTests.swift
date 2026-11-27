import Foundation
import SwiftUI
import Testing
import UIKit

@testable import BitwardenShared

// MARK: - PassYLayoutPreferencesTests

struct PassYLayoutPreferencesTests {
    // MARK: Defaults

    /// The defaults are "no override": type tiles as cards, folders as rows, every section visible in its natural
    /// order, today's rows and codes.
    @Test
    func defaults_areTodaysLook() {
        let preferences = PassYLayoutPreferences.default
        #expect(preferences.version == PassYLayoutPreferences.currentVersion)
        #expect(preferences.home.tileOrder.isEmpty)
        #expect(preferences.home.tileRows.isEmpty)
        #expect(preferences.home.folderCards.isEmpty)
        #expect(preferences.home.cardColors == .colorful)
        #expect(preferences.home.sectionOrder.isEmpty)
        #expect(preferences.home.hiddenSections.isEmpty)
        #expect(preferences.home.collapsedSections.isEmpty)
        #expect(preferences.orderedTiles == PassYLayoutPreferences.knownTiles)
        #expect(preferences.orderedSections == PassYLayoutPreferences.knownSections)
        #expect(PassYLayoutPreferences.knownTiles.allSatisfy(preferences.isCard))
        #expect(!preferences.isCard("folder:f1") && !preferences.isCard("noFolder"))
        #expect(preferences.rows == PassYLayoutPreferences.Rows())
        #expect(preferences.rows.showsSubtitle && preferences.rows.showsIcon)
        #expect(preferences.rows.showsFavoriteBadge && preferences.rows.showsSharedBadge)
        #expect(preferences.rows.showsAttachmentBadge)
        #expect(preferences.codes.groupsDigits && preferences.codes.showsCountdownRing)
        #expect(preferences.codes.showsCountdownSeconds)
    }

    /// Default preferences leave any list unchanged: type tiles are cards, folders rows, in their natural order.
    @Test
    func defaults_partitionIsIdentity() {
        let items = ["totp", "login", "card", "trash", "folder:1", "noFolder"]
        let split = PassYLayoutPreferences.default.partitionCards(items, id: { $0 })
        #expect(split.cards == ["totp", "login", "card", "trash"])
        #expect(split.rows == ["folder:1", "noFolder"])
        let sections = ["Favorites", "Folders", "NoFolder", "Collections", "Items"]
        #expect(PassYLayoutPreferences.default.partitionSections(sections, id: { $0 }).visible == sections)
    }

    // MARK: Codable

    /// Every field survives an encode / decode round trip.
    @Test
    func codable_roundTrip() throws {
        var preferences = PassYLayoutPreferences.default
        preferences.home.tileOrder = ["login", "folder:f1", "totp"]
        preferences.home.tileRows = ["sshKey", "trash"]
        preferences.home.folderCards = ["folder:f1", "noFolder"]
        preferences.home.cardColors = .filled
        preferences.home.sectionOrder = ["NoFolder", "Favorites"]
        preferences.home.hiddenSections = ["Collections"]
        preferences.home.collapsedSections = ["Folders"]
        preferences.rows.showsSubtitle = false
        preferences.rows.showsIcon = false
        preferences.rows.showsFavoriteBadge = false
        preferences.rows.showsSharedBadge = false
        preferences.rows.showsAttachmentBadge = false
        preferences.codes.groupsDigits = false
        preferences.codes.showsCountdownRing = false
        preferences.codes.showsCountdownSeconds = false

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: data)
        #expect(decoded == preferences)
    }

    /// The encoded form has a version and only identifiers, enums and flags (nothing from the vault but folder ids).
    @Test
    func codable_encodesVersionAndOnlyIdentifiers() throws {
        var preferences = PassYLayoutPreferences.default
        preferences.setCard("card", false)
        let json = try #require(String(data: JSONEncoder().encode(preferences), encoding: .utf8))
        #expect(json.contains("\"version\":2"))
        #expect(json.contains("\"tileRows\":[\"card\"]"))
        #expect(!json.contains("hiddenTiles"))
    }

    // MARK: Versioning and migration

    /// An unversioned payload with only some fields (version 0) migrates: missing fields take their defaults,
    /// duplicate ids are dropped, the version becomes the current one.
    @Test
    func migration_unversionedPartialPayload() throws {
        let json = """
        {"home":{"tileOrder":["login","login","totp"],"hiddenTiles":["trash"]}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.version == PassYLayoutPreferences.currentVersion)
        #expect(decoded.home.tileOrder == ["login", "totp"])
        #expect(decoded.home.tileRows == ["trash"])
        #expect(decoded.rows == PassYLayoutPreferences.Rows())
        #expect(decoded.codes == PassYLayoutPreferences.Codes())
    }

    /// A full version 1 payload (wide or list layout, compact rows, monochrome tiles, hidden tiles, countdown off)
    /// decodes without loss of anything version 2 still has: hidden tiles become folder rows, the removed options are
    /// ignored (cards, comfortable rows, colourful cards), the countdown is switched back on (no switch any more).
    @Test(arguments: ["grid", "wide", "list"])
    func migration_version1Payload(layout: String) throws {
        let json = """
        {"version":1,"home":{"tileOrder":["login","totp"],"hiddenTiles":["sshKey","trash"],"tileLayout":"\(layout)",
         "sectionOrder":["Folders"],"hiddenSections":["Favorites"],"collapsedSections":["NoFolder"]},
         "rows":{"density":"compact","showsSubtitle":false,"showsIcon":true,"showsFavoriteBadge":false,
         "showsSharedBadge":true,"showsAttachmentBadge":true,"tileColors":"monochrome"},
         "codes":{"groupsDigits":false,"showsCountdownRing":false,"showsCountdownSeconds":false}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.version == 2)
        #expect(decoded.home.tileOrder == ["login", "totp"])
        #expect(decoded.home.tileRows == ["sshKey", "trash"])
        #expect(!decoded.isCard("sshKey") && decoded.isCard("login"))
        #expect(decoded.home.folderCards.isEmpty)
        #expect(decoded.home.cardColors == .colorful, "monochrome is gone: the default")
        #expect(decoded.home.sectionOrder == ["Folders"])
        #expect(decoded.home.hiddenSections == ["Favorites"])
        #expect(decoded.home.collapsedSections == ["NoFolder"])
        #expect(decoded.rows.showsSubtitle == false && decoded.rows.showsFavoriteBadge == false)
        #expect(decoded.codes.groupsDigits == false)
        #expect(decoded.codes.showsCountdownRing && decoded.codes.showsCountdownSeconds)
        // Written again as version 2 and read back unchanged.
        let again = try JSONDecoder().decode(PassYLayoutPreferences.self, from: JSONEncoder().encode(decoded))
        #expect(again == decoded)
    }

    /// A payload of a newer version with values this version does not know keeps everything it understands.
    @Test
    func versioning_newerPayloadKeepsKnownFields() throws {
        let json = """
        {"version":7,"home":{"cardColors":"gradient","tileRows":["card","futureType"],"newField":1},
         "rows":{"showsSubtitle":false},"codes":{"groupsDigits":false,"showsCountdownRing":false},"themes":{}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.home.cardColors == .colorful, "unknown colours fall back to the default")
        #expect(decoded.home.tileRows == ["card", "futureType"], "unknown ids pass through")
        #expect(decoded.rows.showsSubtitle == false)
        #expect(decoded.codes.groupsDigits == false)
        #expect(decoded.codes.showsCountdownRing == false, "a newer version keeps its own value")
    }

    /// Garbage in a field does not lose the other fields.
    @Test
    func versioning_wrongTypeFieldFallsBack() throws {
        let json = """
        {"version":2,"home":{"tileOrder":"login","folderCards":["folder:a"]},"rows":{"showsIcon":false}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.home.tileOrder.isEmpty)
        #expect(decoded.home.folderCards == ["folder:a"])
        #expect(decoded.rows.showsIcon == false)
    }

    // MARK: Reorder

    /// Moving elements like `List.onMove` stores the full order, folders included.
    @Test
    func reorder_moveElements() {
        var preferences = PassYLayoutPreferences.default
        let folders = ["folder:a", "folder:b"]
        #expect(preferences.orderedElements(folders: folders) == PassYLayoutPreferences.knownTiles + folders)
        // Move "folder:b" (last) to the front.
        let count = PassYLayoutPreferences.knownTiles.count + folders.count
        preferences.moveElements(folders: folders, fromOffsets: IndexSet(integer: count - 1), toOffset: 0)
        #expect(preferences.orderedElements(folders: folders).first == "folder:b")
        #expect(preferences.orderedElements(folders: folders).count == count)
        // Move "totp" (now second) below "login".
        preferences.moveElements(folders: folders, fromOffsets: IndexSet(integer: 1), toOffset: 3)
        #expect(Array(preferences.orderedElements(folders: folders).prefix(3)) == ["folder:b", "login", "totp"])
        #expect(Array(preferences.orderedTiles.prefix(2)) == ["login", "totp"])
    }

    /// The card menu moves: to the front, earlier, later, to the end; ends are no-ops and not offered.
    @Test
    func reorder_moveCard() {
        var preferences = PassYLayoutPreferences.default
        let cards = ["totp", "login", "folder:a", "trash"]
        #expect(!PassYLayoutPreferences.canMove("totp", .earlier, among: cards))
        #expect(!PassYLayoutPreferences.canMove("totp", .toFront, among: cards))
        #expect(PassYLayoutPreferences.canMove("totp", .later, among: cards))
        #expect(!PassYLayoutPreferences.canMove("trash", .toEnd, among: cards))
        #expect(!PassYLayoutPreferences.canMove("unknown", .later, among: cards))

        preferences.moveCard("folder:a", .toFront, among: cards)
        #expect(preferences.home.tileOrder == ["folder:a", "totp", "login", "trash"])
        preferences.moveCard("login", .earlier, among: preferences.home.tileOrder)
        #expect(preferences.home.tileOrder == ["folder:a", "login", "totp", "trash"])
        preferences.moveCard("folder:a", .later, among: preferences.home.tileOrder)
        #expect(preferences.home.tileOrder == ["login", "folder:a", "totp", "trash"])
        preferences.moveCard("login", .toEnd, among: preferences.home.tileOrder)
        #expect(preferences.home.tileOrder == ["folder:a", "totp", "trash", "login"])
        let before = preferences
        preferences.moveCard("login", .later, among: preferences.home.tileOrder)
        #expect(preferences == before)
    }

    /// Moving a card keeps the place of the elements not shown as cards (rows, folders of another account).
    @Test
    func reorder_moveCardKeepsOtherIdentifiers() {
        var preferences = PassYLayoutPreferences.default
        preferences.home.tileOrder = ["folder:gone", "login", "sshKey", "totp"]
        preferences.moveCard("totp", .toFront, among: ["login", "totp"])
        #expect(preferences.home.tileOrder == ["totp", "login", "folder:gone", "sshKey"])
    }

    /// Moving sections down and up.
    @Test
    func reorder_moveSections() {
        var preferences = PassYLayoutPreferences.default
        preferences.moveSections(fromOffsets: IndexSet(integer: 1), toOffset: 4)
        #expect(preferences.orderedSections == ["PassYTypes", "Folders", "NoFolder", "Favorites", "Collections"])
        preferences.moveSections(fromOffsets: IndexSet(integer: 4), toOffset: 0)
        #expect(preferences.orderedSections == ["Collections", "PassYTypes", "Folders", "NoFolder", "Favorites"])
    }

    /// An order applies to the data present; items the order does not know keep their natural position.
    @Test
    func reorder_unknownItemsKeepTheirPosition() {
        let items = ["totp", "login", "card", "bankAccount", "identity"]
        let ordered = PassYLayoutPreferences.ordered(items, by: ["identity", "card", "totp", "login"], id: { $0 })
        #expect(ordered == ["identity", "card", "totp", "bankAccount", "login"])
    }

    /// `passYMove` matches SwiftUI's `move(fromOffsets:toOffset:)` for several moves.
    @Test
    func reorder_moveMatchesSwiftUISemantics() {
        var array = ["a", "b", "c", "d", "e"]
        array.passYMove(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        #expect(array == ["b", "d", "a", "c", "e"])
        var other = ["a", "b", "c", "d", "e"]
        other.passYMove(fromOffsets: IndexSet(integer: 4), toOffset: 1)
        #expect(other == ["a", "e", "b", "c", "d"])
    }

    // MARK: Reachability

    /// Nothing disappears: cards and rows together are exactly the input, in order, for any switch combination.
    @Test(arguments: [
        Set<String>(),
        ["trash", "archive"],
        ["totp", "login", "card", "identity", "secureNote", "sshKey", "archive", "trash", "folder:a"],
        Set(PassYLayoutPreferences.knownTiles + ["folder:a", "folder:b", "noFolder"]),
    ])
    func reachability_everyElementIsCardOrRow(switched: Set<String>) {
        var preferences = PassYLayoutPreferences.default
        for id in switched {
            preferences.setCard(id, !preferences.isCard(id))
        }
        preferences.moveCard("login", .toEnd, among: PassYLayoutPreferences.knownTiles)
        let input = PassYLayoutPreferences.knownTiles + ["folder:a", "folder:b", "noFolder"]
        let split = preferences.partitionCards(input, id: { $0 })
        #expect(Set(split.cards).isDisjoint(with: split.rows))
        #expect(Set(split.cards + split.rows) == Set(input))
        #expect((split.cards + split.rows).count == input.count)
    }

    /// Switching an element back restores the defaults.
    @Test
    func cardSwitch_toggleBack() {
        var preferences = PassYLayoutPreferences.default
        preferences.setCard("sshKey", false)
        preferences.setCard("folder:a", true)
        #expect(!preferences.isCard("sshKey") && preferences.isCard("folder:a"))
        #expect(preferences.home.tileRows == ["sshKey"] && preferences.home.folderCards == ["folder:a"])
        preferences.setCard("sshKey", true)
        preferences.setCard("folder:a", false)
        #expect(preferences == .default)
        preferences.setSection("Favorites", visible: false)
        preferences.setSection("Favorites", collapsed: true)
        #expect(!preferences.isSectionVisible("Favorites"))
        #expect(preferences.home.collapsedSections == ["Favorites"])
    }

    // MARK: Filled cards

    /// White text and symbols keep at least 4.5:1 on every filled card fill, in light and dark mode.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    @MainActor
    func filledCards_whiteContrast(style: UIUserInterfaceStyle) {
        let groups: [VaultListGroup] = [
            .archive, .bankAccount, .card, .driversLicense, .identity, .login, .passport, .secureNote, .sshKey, .totp,
            .trash, .folder(id: "f", name: "Work"), .noFolder,
        ]
        let traits = UITraitCollection(userInterfaceStyle: style)
        for group in groups {
            let fill = UIColor(group.filledCardColor).resolvedColor(with: traits)
            let ratio = Self.contrast(.white, fill)
            #expect(ratio >= 4.5, "\(group.tileIdentifier): \(ratio)")
        }
    }

    /// The WCAG contrast ratio of two colours.
    private static func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ value: CGFloat) -> Double {
                let value = Double(value)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let (high, low) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (high + 0.05) / (low + 0.05)
    }
}
