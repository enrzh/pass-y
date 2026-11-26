import Foundation
import Testing

@testable import BitwardenShared

// MARK: - PassYLayoutPreferencesTests

struct PassYLayoutPreferencesTests {
    // MARK: Defaults

    /// The defaults are "no override": every tile and section visible in its natural order, today's rows and codes.
    @Test
    func defaults_areTodaysLook() {
        let preferences = PassYLayoutPreferences.default
        #expect(preferences.version == PassYLayoutPreferences.currentVersion)
        #expect(preferences.home.tileOrder.isEmpty)
        #expect(preferences.home.hiddenTiles.isEmpty)
        #expect(preferences.home.tileLayout == .grid)
        #expect(preferences.home.sectionOrder.isEmpty)
        #expect(preferences.home.hiddenSections.isEmpty)
        #expect(preferences.home.collapsedSections.isEmpty)
        #expect(preferences.orderedTiles == PassYLayoutPreferences.knownTiles)
        #expect(preferences.orderedSections == PassYLayoutPreferences.knownSections)
        #expect(preferences.rows == PassYLayoutPreferences.Rows())
        #expect(preferences.rows.density == .comfortable)
        #expect(preferences.rows.showsSubtitle && preferences.rows.showsIcon)
        #expect(preferences.rows.showsFavoriteBadge && preferences.rows.showsSharedBadge)
        #expect(preferences.rows.showsAttachmentBadge)
        #expect(preferences.rows.tileColors == .colorful)
        #expect(preferences.codes.groupsDigits && preferences.codes.showsCountdownRing)
        #expect(preferences.codes.showsCountdownSeconds)
    }

    /// Default preferences leave any list unchanged (identity transform).
    @Test
    func defaults_partitionIsIdentity() {
        let items = ["totp", "login", "card", "folder-1", "trash"]
        let split = PassYLayoutPreferences.default.partitionTiles(items, id: { $0 })
        #expect(split.visible == items)
        #expect(split.hidden.isEmpty)
        let sections = ["Favorites", "Folders", "NoFolder", "Collections", "Items"]
        #expect(PassYLayoutPreferences.default.partitionSections(sections, id: { $0 }).visible == sections)
    }

    // MARK: Codable

    /// Every field survives an encode / decode round trip.
    @Test
    func codable_roundTrip() throws {
        var preferences = PassYLayoutPreferences.default
        preferences.home.tileOrder = ["login", "totp"]
        preferences.home.hiddenTiles = ["sshKey", "trash"]
        preferences.home.tileLayout = .wide
        preferences.home.sectionOrder = ["NoFolder", "Favorites"]
        preferences.home.hiddenSections = ["Collections"]
        preferences.home.collapsedSections = ["Folders"]
        preferences.rows.density = .compact
        preferences.rows.showsSubtitle = false
        preferences.rows.showsIcon = false
        preferences.rows.showsFavoriteBadge = false
        preferences.rows.showsSharedBadge = false
        preferences.rows.showsAttachmentBadge = false
        preferences.rows.tileColors = .monochrome
        preferences.codes.groupsDigits = false
        preferences.codes.showsCountdownRing = false
        preferences.codes.showsCountdownSeconds = false

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: data)
        #expect(decoded == preferences)
    }

    /// The encoded form has a version and only identifiers, enums and flags (nothing from the vault).
    @Test
    func codable_encodesVersionAndOnlyIdentifiers() throws {
        var preferences = PassYLayoutPreferences.default
        preferences.setTile("card", visible: false)
        let json = try #require(String(data: JSONEncoder().encode(preferences), encoding: .utf8))
        #expect(json.contains("\"version\":1"))
        #expect(json.contains("\"hiddenTiles\":[\"card\"]"))
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
        #expect(decoded.home.hiddenTiles == ["trash"])
        #expect(decoded.home.tileLayout == .grid)
        #expect(decoded.rows == PassYLayoutPreferences.Rows())
        #expect(decoded.codes == PassYLayoutPreferences.Codes())
    }

    /// A payload of a newer version with values this version does not know keeps everything it understands.
    @Test
    func versioning_newerPayloadKeepsKnownFields() throws {
        let json = """
        {"version":7,"home":{"tileLayout":"masonry","hiddenTiles":["card","futureType"],"newField":1},
         "rows":{"density":"ultraCompact","showsSubtitle":false},"codes":{"groupsDigits":false},"themes":{}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.home.tileLayout == .grid, "unknown layout falls back to the default")
        #expect(decoded.home.hiddenTiles == ["card", "futureType"], "unknown ids pass through")
        #expect(decoded.rows.density == .comfortable, "unknown density falls back to the default")
        #expect(decoded.rows.showsSubtitle == false)
        #expect(decoded.codes.groupsDigits == false)
    }

    /// Garbage in a field does not lose the other fields.
    @Test
    func versioning_wrongTypeFieldFallsBack() throws {
        let json = """
        {"version":1,"home":{"tileOrder":"login"},"rows":{"showsIcon":false}}
        """
        let decoded = try JSONDecoder().decode(PassYLayoutPreferences.self, from: Data(json.utf8))
        #expect(decoded.home.tileOrder.isEmpty)
        #expect(decoded.rows.showsIcon == false)
    }

    // MARK: Reorder

    /// Moving a tile like `List.onMove` stores the full order.
    @Test
    func reorder_moveTiles() {
        var preferences = PassYLayoutPreferences.default
        // Move "trash" (last) to the front.
        preferences.moveTiles(fromOffsets: IndexSet(integer: PassYLayoutPreferences.knownTiles.count - 1), toOffset: 0)
        #expect(preferences.orderedTiles.first == "trash")
        #expect(preferences.orderedTiles.count == PassYLayoutPreferences.knownTiles.count)
        #expect(Set(preferences.orderedTiles) == Set(PassYLayoutPreferences.knownTiles))
        // Move "totp" (now second) below "login".
        preferences.moveTiles(fromOffsets: IndexSet(integer: 1), toOffset: 3)
        #expect(Array(preferences.orderedTiles.prefix(3)) == ["trash", "login", "totp"])
    }

    /// Moving sections down and up.
    @Test
    func reorder_moveSections() {
        var preferences = PassYLayoutPreferences.default
        preferences.moveSections(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(preferences.orderedSections == ["Folders", "NoFolder", "Favorites", "Collections"])
        preferences.moveSections(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(preferences.orderedSections == ["Collections", "Folders", "NoFolder", "Favorites"])
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

    /// Hiding tiles never makes a type unreachable: visible and hidden together are exactly the input, in order.
    @Test(arguments: [
        Set<String>(),
        ["trash", "archive"],
        ["totp", "login", "card", "identity", "secureNote", "sshKey", "archive", "trash"],
        Set(PassYLayoutPreferences.knownTiles),
    ])
    func reachability_hiddenTilesStayReachable(hidden: Set<String>) {
        var preferences = PassYLayoutPreferences.default
        for id in hidden {
            preferences.setTile(id, visible: false)
        }
        preferences.moveTiles(fromOffsets: IndexSet(integer: 0), toOffset: 5)
        let input = PassYLayoutPreferences.knownTiles
        let split = preferences.partitionTiles(input, id: { $0 })
        #expect(Set(split.visible).isDisjoint(with: split.hidden))
        #expect(Set(split.visible + split.hidden) == Set(input))
        #expect((split.visible + split.hidden).count == input.count)
        #expect(Set(split.hidden) == hidden)
    }

    /// Showing a tile again brings it back.
    @Test
    func visibility_toggleBack() {
        var preferences = PassYLayoutPreferences.default
        preferences.setTile("sshKey", visible: false)
        #expect(!preferences.isTileVisible("sshKey"))
        preferences.setTile("sshKey", visible: true)
        #expect(preferences.isTileVisible("sshKey"))
        #expect(preferences == .default)
        preferences.setSection("Favorites", visible: false)
        preferences.setSection("Favorites", collapsed: true)
        #expect(!preferences.isSectionVisible("Favorites"))
        #expect(preferences.home.collapsedSections == ["Favorites"])
    }
}
