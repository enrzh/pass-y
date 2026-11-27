import Foundation

// MARK: - PassYLayoutPreferences

/// The layout preferences of Pass-Y ("Customize"): what the vault home shows as cards and as folder rows and
/// in which order, how list rows look and how verification codes are drawn. Stored per device in the app settings
/// (`AppSettingsStore`), never synced to the server and never containing vault data: only fixed element and section
/// identifiers (folders by their id), enums and flags. Only if the user switches it on, they are mirrored into the
/// user's iCloud key-value store (`PassYLayoutCloudSync`).
///
/// The defaults are "no override" (empty orders, type tiles as cards, folders as rows), so the default preferences
/// draw exactly the look of the app without them. Orders and sets are keyed by stable identifiers
/// (`passYHomeElementId`, the vault list section ids); identifiers the vault does not have (a deleted folder, a type
/// added later) are ignored or keep their natural position.
///
struct PassYLayoutPreferences: Codable, Equatable, Sendable {
    // MARK: Constants

    /// The version written by this app. Older payloads decode field by field (missing fields take their defaults),
    /// newer ones keep every field this version understands.
    ///
    /// - 1: tiles could be hidden (moved to "More"), tile layout, row density, monochrome tiles.
    /// - 2: every home element is a card or a folder row (old hidden tiles become rows), folders can be cards, cards
    ///   only, comfortable rows only, card colours colourful or filled; the countdown switches left Customize (they are
    ///   switched back on).
    static let currentVersion = 2

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
        if version < 2 {
            // Version 2 has no switches for the countdown ring and seconds any more: nobody keeps a hidden countdown
            // without a way back.
            result.codes.showsCountdownRing = true
            result.codes.showsCountdownSeconds = true
        }
        result.version = Self.currentVersion
        return result
    }

    // MARK: Home

    /// What the vault home shows. Every element of the home is either a card (the grid at the top) or a folder row
    /// (a list row below): type tiles are cards unless switched to rows, folders are rows unless switched to cards.
    /// Nothing is ever removed from the home.
    struct Home: Codable, Equatable, Sendable {
        /// The element identifiers (`passYHomeElementId`) in the user's order (empty: the natural order).
        var tileOrder: [String] = []

        /// The type tiles shown as folder rows instead of cards (version 1: the hidden tiles).
        var tileRows: Set<String> = []

        /// The folders (`folder:<id>`, `noFolder`) shown as cards instead of folder rows.
        var folderCards: Set<String> = []

        /// The colours of the home cards.
        var cardColors: CardColors = .colorful

        /// The section identifiers in the user's order (empty: the natural order).
        var sectionOrder: [String] = []

        /// The sections that are not shown on the home.
        var hiddenSections: Set<String> = []

        /// The sections that are collapsed whenever the vault opens.
        var collapsedSections: Set<String> = []

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            tileOrder = container.lenient([String].self, .tileOrder) ?? []
            tileRows = container.lenient(Set<String>.self, .tileRows)
                ?? legacy.lenient(Set<String>.self, .hiddenTiles)
                ?? []
            folderCards = container.lenient(Set<String>.self, .folderCards) ?? []
            cardColors = container.lenient(CardColors.self, .cardColors) ?? .colorful
            sectionOrder = container.lenient([String].self, .sectionOrder) ?? []
            hiddenSections = container.lenient(Set<String>.self, .hiddenSections) ?? []
            collapsedSections = container.lenient(Set<String>.self, .collapsedSections) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case tileOrder, tileRows, folderCards, cardColors, sectionOrder, hiddenSections, collapsedSections
        }

        /// Fields of version 1 that are read once and then written under their new name.
        private enum LegacyKeys: String, CodingKey {
            case hiddenTiles
        }
    }

    /// The colours of the home cards.
    enum CardColors: String, Codable, CaseIterable, Sendable {
        /// A white card with a tinted symbol tile: today's look ("Bunt").
        case colorful

        /// The whole card filled with the type colour, white content ("Vollfarbig").
        case filled
    }

    // MARK: Rows

    /// How list rows look.
    struct Rows: Codable, Equatable, Sendable {
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

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            showsSubtitle = container.lenient(Bool.self, .showsSubtitle) ?? true
            showsIcon = container.lenient(Bool.self, .showsIcon) ?? true
            showsFavoriteBadge = container.lenient(Bool.self, .showsFavoriteBadge) ?? true
            showsSharedBadge = container.lenient(Bool.self, .showsSharedBadge) ?? true
            showsAttachmentBadge = container.lenient(Bool.self, .showsAttachmentBadge) ?? true
        }

        private enum CodingKeys: String, CodingKey {
            case showsSubtitle, showsIcon, showsFavoriteBadge, showsSharedBadge, showsAttachmentBadge
        }
    }

    // MARK: Codes

    /// How verification codes are drawn.
    struct Codes: Codable, Equatable, Sendable {
        /// Whether codes are split into two groups ("123 456").
        var groupsDigits = true

        /// Whether the countdown ring is shown (no switch in Customize since version 2; the code rows still read it).
        var showsCountdownRing = true

        /// Whether the seconds left are shown (no switch in Customize since version 2; the code rows still read it).
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

// MARK: - Home elements and sections

extension PassYLayoutPreferences {
    /// The type tiles of the vault home in their natural order (their `VaultListGroup.tileIdentifier`).
    static let knownTiles: [String] = [
        "totp", "login", "card", "bankAccount", "identity", "driversLicense", "passport", "secureNote", "sshKey",
        "archive", "trash",
    ]

    /// The id of the home section with the type tiles shown as folder rows.
    static let typeRowsSectionId = "PassYTypes"

    /// The reorderable sections of the vault home in their natural order (their vault list section ids).
    static let knownSections: [String] = [typeRowsSectionId, "Favorites", "Folders", "NoFolder", "Collections"]

    /// Whether an element identifier is a folder (`folder:<id>` or `noFolder`): a row unless switched to a card.
    static func isFolderElement(_ id: String) -> Bool {
        id.hasPrefix(VaultListGroup.folderElementPrefix) || id == "noFolder"
    }

    /// The known type tiles in the user's order.
    var orderedTiles: [String] {
        Self.ordered(Self.knownTiles, by: home.tileOrder, id: { $0 })
    }

    /// The type tiles and the given folder elements in the user's order (folders after the types by default).
    func orderedElements(folders: [String]) -> [String] {
        Self.ordered(Self.knownTiles + folders, by: home.tileOrder, id: { $0 })
    }

    /// The known sections in the user's order.
    var orderedSections: [String] {
        Self.ordered(Self.knownSections, by: home.sectionOrder, id: { $0 })
    }

    /// Whether a home element is shown as a card (otherwise as a folder row).
    func isCard(_ id: String) -> Bool {
        Self.isFolderElement(id) ? home.folderCards.contains(id) : !home.tileRows.contains(id)
    }

    /// Shows a home element as a card or as a folder row.
    mutating func setCard(_ id: String, _ isCard: Bool) {
        if Self.isFolderElement(id) {
            if isCard { home.folderCards.insert(id) } else { home.folderCards.remove(id) }
        } else {
            if isCard { home.tileRows.remove(id) } else { home.tileRows.insert(id) }
        }
    }

    /// Whether a section is shown on the home.
    func isSectionVisible(_ id: String) -> Bool {
        !home.hiddenSections.contains(id)
    }

    /// Shows or hides a section.
    mutating func setSection(_ id: String, visible: Bool) {
        if visible { home.hiddenSections.remove(id) } else { home.hiddenSections.insert(id) }
    }

    /// Sets whether a section is collapsed when the vault opens.
    mutating func setSection(_ id: String, collapsed: Bool) {
        if collapsed { home.collapsedSections.insert(id) } else { home.collapsedSections.remove(id) }
    }

    /// Moves elements like `List.onMove` (offsets in `orderedElements(folders:)`).
    mutating func moveElements(folders: [String], fromOffsets source: IndexSet, toOffset destination: Int) {
        var elements = orderedElements(folders: folders)
        elements.passYMove(fromOffsets: source, toOffset: destination)
        home.tileOrder = elements + home.tileOrder.filter { !elements.contains($0) }
    }

    /// Moves sections like `List.onMove` (offsets in `orderedSections`).
    mutating func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        var sections = orderedSections
        sections.passYMove(fromOffsets: source, toOffset: destination)
        home.sectionOrder = sections
    }

    /// A move of one card on the home (the long-press menu).
    enum CardMove: CaseIterable, Sendable {
        case toFront, earlier, later, toEnd
    }

    /// Whether `move` changes anything for the card `id` among the cards shown (`cards`, in home order).
    static func canMove(_ id: String, _ move: CardMove, among cards: [String]) -> Bool {
        guard let index = cards.firstIndex(of: id) else { return false }
        switch move {
        case .toFront, .earlier: return index > 0
        case .later, .toEnd: return index < cards.count - 1
        }
    }

    /// Moves the card `id` among the cards shown on the home (`cards`, in home order). The cards shown get their new
    /// order; the identifiers of elements not shown right now (rows, folders of another account) keep theirs after
    /// them.
    mutating func moveCard(_ id: String, _ move: CardMove, among cards: [String]) {
        guard let index = cards.firstIndex(of: id), Self.canMove(id, move, among: cards) else { return }
        var order = cards
        order.remove(at: index)
        let target = switch move {
        case .toFront: 0
        case .earlier: index - 1
        case .later: index + 1
        case .toEnd: order.count
        }
        order.insert(id, at: target)
        home.tileOrder = order + home.tileOrder.filter { !order.contains($0) }
    }

    /// Splits home elements into cards and folder rows. Both keep the user's order and together they are exactly the
    /// input: nothing disappears from the home.
    ///
    /// - Parameters:
    ///   - items: The elements in their natural order.
    ///   - id: The element identifier of an item (`passYHomeElementId`).
    ///
    func partitionCards<Item>(_ items: [Item], id: (Item) -> String) -> (cards: [Item], rows: [Item]) {
        let ordered = Self.ordered(items, by: home.tileOrder, id: id)
        var cards: [Item] = []
        var rows: [Item] = []
        for item in ordered {
            if isCard(id(item)) { cards.append(item) } else { rows.append(item) }
        }
        return (cards, rows)
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
