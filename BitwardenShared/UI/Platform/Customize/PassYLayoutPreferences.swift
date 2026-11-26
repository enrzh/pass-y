import Foundation

// MARK: - PassYLayoutPreferences

/// The on-device layout preferences of Pass-Y ("Customize"): what the vault home shows and in which order, how list
/// rows look and how verification codes are drawn. Stored per device in the app settings (`AppSettingsStore`), never
/// synced to the server and never containing vault data: only fixed tile and section identifiers, enums and flags.
///
/// The defaults are "no override" (empty orders, nothing hidden), so the default preferences draw exactly the look of
/// the app without them. Orders and sets are keyed by stable identifiers (`VaultListGroup.tileIdentifier`, the vault
/// list section ids); identifiers the app does not know yet (a type added later) keep their natural position.
///
struct PassYLayoutPreferences: Codable, Equatable, Sendable {
    // MARK: Constants

    /// The version written by this app. Older payloads decode field by field (missing fields take their defaults),
    /// newer ones keep every field this version understands.
    static let currentVersion = 1

    /// The defaults: today's look.
    static let `default` = PassYLayoutPreferences()

    // MARK: Properties

    /// The version of the payload.
    var version = Self.currentVersion

    /// The vault home.
    var home = Home()

    /// The list rows.
    var rows = Rows()

    /// The verification codes.
    var codes = Codes()

    // MARK: Initialization

    /// Creates preferences.
    init(home: Home = Home(), rows: Rows = Rows(), codes: Codes = Codes()) {
        self.home = home
        self.rows = rows
        self.codes = codes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A payload without a version is the (never shipped) unversioned format: same fields, version 0.
        let version = container.lenient(Int.self, .version) ?? 0
        home = container.lenient(Home.self, .home) ?? Home()
        rows = container.lenient(Rows.self, .rows) ?? Rows()
        codes = container.lenient(Codes.self, .codes) ?? Codes()
        self = migrated(from: version)
    }

    private enum CodingKeys: String, CodingKey {
        case version, home, rows, codes
    }

    /// Brings decoded preferences of `version` to the current version (drops duplicates, stamps the version).
    private func migrated(from version: Int) -> PassYLayoutPreferences {
        var result = self
        result.home.tileOrder = home.tileOrder.uniqued()
        result.home.sectionOrder = home.sectionOrder.uniqued()
        result.version = Self.currentVersion
        return result
    }

    // MARK: Home

    /// What the vault home shows.
    struct Home: Codable, Equatable, Sendable {
        /// The tile identifiers in the user's order (empty: the natural order).
        var tileOrder: [String] = []

        /// The tiles that are not shown on the home (they stay reachable in the "More" section).
        var hiddenTiles: Set<String> = []

        /// How the tiles are laid out.
        var tileLayout: TileLayout = .grid

        /// The section identifiers in the user's order (empty: the natural order).
        var sectionOrder: [String] = []

        /// The sections that are not shown on the home.
        var hiddenSections: Set<String> = []

        /// The sections that are collapsed whenever the vault opens.
        var collapsedSections: Set<String> = []

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tileOrder = container.lenient([String].self, .tileOrder) ?? []
            hiddenTiles = container.lenient(Set<String>.self, .hiddenTiles) ?? []
            tileLayout = container.lenient(TileLayout.self, .tileLayout) ?? .grid
            sectionOrder = container.lenient([String].self, .sectionOrder) ?? []
            hiddenSections = container.lenient(Set<String>.self, .hiddenSections) ?? []
            collapsedSections = container.lenient(Set<String>.self, .collapsedSections) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case tileOrder, hiddenTiles, tileLayout, sectionOrder, hiddenSections, collapsedSections
        }
    }

    /// The layout of the home tiles.
    enum TileLayout: String, Codable, CaseIterable, Sendable {
        /// Cards in columns (two on an iPhone, more on wide screens): today's look.
        case grid

        /// One column of wide cards.
        case wide

        /// A compact list of rows.
        case list
    }

    // MARK: Rows

    /// How list rows look.
    struct Rows: Codable, Equatable, Sendable {
        /// The row density.
        var density: Density = .comfortable

        /// Whether rows show their subtitle (the user name of a login).
        var showsSubtitle = true

        /// Whether rows show their icon tile.
        var showsIcon = true

        /// Whether the favourite star is shown.
        var showsFavoriteBadge = true

        /// Whether the shared mark is shown.
        var showsSharedBadge = true

        /// Whether the attachments mark is shown.
        var showsAttachmentBadge = true

        /// The colours of the icon tiles.
        var tileColors: TileColors = .colorful

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            density = container.lenient(Density.self, .density) ?? .comfortable
            showsSubtitle = container.lenient(Bool.self, .showsSubtitle) ?? true
            showsIcon = container.lenient(Bool.self, .showsIcon) ?? true
            showsFavoriteBadge = container.lenient(Bool.self, .showsFavoriteBadge) ?? true
            showsSharedBadge = container.lenient(Bool.self, .showsSharedBadge) ?? true
            showsAttachmentBadge = container.lenient(Bool.self, .showsAttachmentBadge) ?? true
            tileColors = container.lenient(TileColors.self, .tileColors) ?? .colorful
        }

        private enum CodingKeys: String, CodingKey {
            case density, showsSubtitle, showsIcon, showsFavoriteBadge, showsSharedBadge, showsAttachmentBadge
            case tileColors
        }
    }

    /// The density of list rows.
    enum Density: String, Codable, CaseIterable, Sendable {
        /// 56 pt rows: today's look.
        case comfortable

        /// 44 pt rows.
        case compact
    }

    /// The colours of icon tiles.
    enum TileColors: String, Codable, CaseIterable, Sendable {
        /// Each category / name in its own tint: today's look.
        case colorful

        /// One neutral tint for every tile.
        case monochrome
    }

    // MARK: Codes

    /// How verification codes are drawn.
    struct Codes: Codable, Equatable, Sendable {
        /// Whether codes are split into two groups ("123 456").
        var groupsDigits = true

        /// Whether the countdown ring is shown.
        var showsCountdownRing = true

        /// Whether the seconds left are shown.
        var showsCountdownSeconds = true

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            groupsDigits = container.lenient(Bool.self, .groupsDigits) ?? true
            showsCountdownRing = container.lenient(Bool.self, .showsCountdownRing) ?? true
            showsCountdownSeconds = container.lenient(Bool.self, .showsCountdownSeconds) ?? true
        }

        private enum CodingKeys: String, CodingKey {
            case groupsDigits, showsCountdownRing, showsCountdownSeconds
        }
    }
}

// MARK: - Home tiles and sections

extension PassYLayoutPreferences {
    /// The tiles of the vault home in their natural order (their `VaultListGroup.tileIdentifier`).
    static let knownTiles: [String] = [
        "totp", "login", "card", "bankAccount", "identity", "driversLicense", "passport", "secureNote", "sshKey",
        "archive", "trash",
    ]

    /// The reorderable sections of the vault home in their natural order (their vault list section ids).
    static let knownSections: [String] = ["Favorites", "Folders", "NoFolder", "Collections"]

    /// The known tiles in the user's order.
    var orderedTiles: [String] {
        Self.ordered(Self.knownTiles, by: home.tileOrder, id: { $0 })
    }

    /// The known sections in the user's order.
    var orderedSections: [String] {
        Self.ordered(Self.knownSections, by: home.sectionOrder, id: { $0 })
    }

    /// Whether a tile is shown on the home.
    func isTileVisible(_ id: String) -> Bool {
        !home.hiddenTiles.contains(id)
    }

    /// Whether a section is shown on the home.
    func isSectionVisible(_ id: String) -> Bool {
        !home.hiddenSections.contains(id)
    }

    /// Shows or hides a tile.
    mutating func setTile(_ id: String, visible: Bool) {
        if visible { home.hiddenTiles.remove(id) } else { home.hiddenTiles.insert(id) }
    }

    /// Shows or hides a section.
    mutating func setSection(_ id: String, visible: Bool) {
        if visible { home.hiddenSections.remove(id) } else { home.hiddenSections.insert(id) }
    }

    /// Sets whether a section is collapsed when the vault opens.
    mutating func setSection(_ id: String, collapsed: Bool) {
        if collapsed { home.collapsedSections.insert(id) } else { home.collapsedSections.remove(id) }
    }

    /// Moves tiles like `List.onMove` (offsets in `orderedTiles`).
    mutating func moveTiles(fromOffsets source: IndexSet, toOffset destination: Int) {
        var tiles = orderedTiles
        tiles.passYMove(fromOffsets: source, toOffset: destination)
        home.tileOrder = tiles
    }

    /// Moves sections like `List.onMove` (offsets in `orderedSections`).
    mutating func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        var sections = orderedSections
        sections.passYMove(fromOffsets: source, toOffset: destination)
        home.sectionOrder = sections
    }

    /// Splits items into those shown on the home and those only in the "More" section. Both keep the user's order and
    /// together they are exactly the input: hiding never makes anything unreachable.
    ///
    /// - Parameters:
    ///   - items: The items in their natural order.
    ///   - id: The identifier of an item.
    ///
    func partitionTiles<Item>(_ items: [Item], id: (Item) -> String) -> (visible: [Item], hidden: [Item]) {
        let ordered = Self.ordered(items, by: home.tileOrder, id: id)
        var visible: [Item] = []
        var hidden: [Item] = []
        for item in ordered {
            if home.hiddenTiles.contains(id(item)) { hidden.append(item) } else { visible.append(item) }
        }
        return (visible, hidden)
    }

    /// Splits sections into those shown on the home and the hidden ones, both in the user's order.
    func partitionSections<Item>(_ items: [Item], id: (Item) -> String) -> (visible: [Item], hidden: [Item]) {
        let ordered = Self.ordered(items, by: home.sectionOrder, id: id)
        var visible: [Item] = []
        var hidden: [Item] = []
        for item in ordered {
            if home.hiddenSections.contains(id(item)) { hidden.append(item) } else { visible.append(item) }
        }
        return (visible, hidden)
    }

    /// Orders `items` by `order`: the items whose identifier is in `order` swap places among themselves to follow it;
    /// every other item keeps its natural position. An empty order returns the items unchanged.
    static func ordered<Item>(_ items: [Item], by order: [String], id: (Item) -> String) -> [Item] {
        guard !order.isEmpty else { return items }
        var rank: [String: Int] = [:]
        for (index, key) in order.enumerated() where rank[key] == nil {
            rank[key] = index
        }
        let ranked = items.filter { rank[id($0)] != nil }.sorted { rank[id($0)]! < rank[id($1)]! }
        var next = ranked.makeIterator()
        return items.map { rank[id($0)] != nil ? next.next()! : $0 }
    }
}

// MARK: - Helpers

private extension KeyedDecodingContainer {
    /// Decodes a value, `nil` when it is missing or cannot be decoded (an unknown enum case of a newer version).
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}

private extension Array where Element: Hashable {
    /// The elements without repeats, first occurrence kept.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    /// Moves elements like `MutableCollection.move(fromOffsets:toOffset:)` of SwiftUI (no SwiftUI import here).
    mutating func passYMove(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().filter { indices.contains($0) }.map { self[$0] }
        let before = source.count(in: 0 ..< Swift.min(destination, count))
        for index in source.sorted(by: >) where indices.contains(index) {
            remove(at: index)
        }
        insert(contentsOf: moving, at: Swift.max(0, Swift.min(destination - before, count)))
    }
}
