import BitwardenKit
import SwiftUI

// MARK: - Card list

// The list construction of Pass-Y (PassYDesign): every list page is a `List` with `passYCardList()`, its sections
// are `PassYCardSection`s (rounded cards on the grouped page colour) and its rows `PassYRow`s; an empty list shows a
// `PassYEmptyState` through `passYEmptyListState()`.

extension View {
    /// The list style of every Pass-Y list page (vault home, group pages, search results, Send, folders): an
    /// inset-grouped list whose sections are rounded cards on the grouped page colour.
    ///
    /// The list keeps the system background: hiding it (`scrollContentBackground`) on the vault list made SwiftUI
    /// rebuild the visible rows on unrelated state changes such as a toast
    /// (`VaultListPerfTests.test_unrelatedChanges_doNotRebuildRows`). An empty list's message uses
    /// `passYEmptyListState()` instead.
    ///
    /// - Parameter reservesBottomBarSpace: Whether the list keeps room below its last row for the floating bottom bar
    ///   (a content margin, not a spacer row: a spacer row drew a stray separator line below short lists) and fades
    ///   its content softly under the bar.
    ///
    func passYCardList(reservesBottomBarSpace: Bool = true) -> some View {
        listStyle(.insetGrouped)
            .modifier(PassYBottomBarScrollSpace(isEnabled: reservesBottomBarSpace))
    }

    /// The empty-state message laid over an empty list: centered, on the grouped page colour. An empty grouped list
    /// draws an almost white background instead of the grouped page colour, which showed as a light band above the
    /// bottom bar on an empty folder page; the message covers it with the page colour.
    func passYEmptyListState() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    /// Gives a native `Form` the grouped page colour so its cards stay visible (also inside sheets).
    func passYGroupedBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }

    /// Starts the system row separator at this view's leading edge (plus `offset`): the text column of a row, so the
    /// line does not run under the icon (Apple Passwords).
    func passYListSeparatorLeading(_ offset: CGFloat = 0) -> some View {
        alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + offset }
    }

    /// Room below the last row of a list for the floating bottom bar. A content margin, not a spacer row: a spacer row
    /// drew a stray separator line in the empty area below short lists.
    func passYBottomBarContentMargin() -> some View {
        contentMargins(.bottom, FloatingActionButton.bottomOffsetPadding, for: .scrollContent)
    }

    /// Fades list content out under the floating bottom bar (scroll edge effect) so rows do not shine through.
    func softBottomScrollEdge() -> some View {
        scrollEdgeEffectStyle(.soft, for: .bottom)
    }
}

/// The bottom bar room and soft scroll edge of `passYCardList`.
private struct PassYBottomBarScrollSpace: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .passYBottomBarContentMargin()
                .softBottomScrollEdge()
        } else {
            content
        }
    }
}

// MARK: - PassYCardSection

/// A card of a `passYCardList()`: a `Section` with an optional `PassYSectionHeader` (title and count).
///
/// ```swift
/// List {
///     PassYCardSection("Folders", count: folders.count) {
///         ForEach(folders) { folder in FolderRow(folder) }
///     }
/// }
/// .passYCardList()
/// ```
///
struct PassYCardSection<Content: View>: View {
    /// The header title, `nil` for a card without header.
    let title: String?

    /// The count shown in the header.
    var count: Int?

    /// The rows.
    @ViewBuilder let content: () -> Content

    /// Creates a card section.
    init(_ title: String? = nil, count: Int? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.count = count
        self.content = content
    }

    var body: some View {
        Section {
            content()
        } header: {
            if let title {
                PassYSectionHeader(title, count: count)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Card list") {
    List {
        PassYCardSection("Folders", count: 2) {
            PassYRow(title: "Work", showsDisclosure: true) {
                PassYIconTile(systemImage: "folder.fill", tint: .blue)
            }
            PassYRow(title: "Personal", showsDisclosure: true) {
                PassYIconTile(systemImage: "folder.fill", tint: .blue)
            }
        }
        PassYCardSection {
            PassYRow(title: "GitHub", subtitles: ["octo@example.test"]) {
                PassYIconTile(letter: "GitHub")
            }
        }
    }
    .passYCardList(reservesBottomBarSpace: false)
}
#endif
