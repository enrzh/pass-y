import BitwardenResources
import SwiftUI
import UIKit

// MARK: - VaultBottomBar

/// The bottom bar of the vault screen: a native search field and the "new item" menu, floating above the tab bar
/// (like the search + compose pair in Apple apps).
///
struct VaultBottomBar: View {
    // MARK: Properties

    /// Called when the user adds a folder.
    let addFolder: () -> Void

    /// Called with the chosen item type.
    let addItem: (BitwardenShared.CipherType) -> Void

    /// The item types the user can create.
    let availableItemTypes: [BitwardenShared.CipherType]

    /// Whether the search field is being edited.
    @Binding var isEditing: Bool

    /// The search text.
    @Binding var text: String

    // MARK: View

    var body: some View {
        HStack(spacing: 10) {
            VaultSearchBarRepresentable(isEditing: $isEditing, text: $text)
                .frame(height: 44)
                .modifier(BarBackground(shape: Capsule()))

            if !isEditing {
                VaultAddMenuView(
                    availableItemTypes: availableItemTypes,
                    addItem: addItem,
                    addFolder: addFolder,
                )
                .frame(width: 44, height: 44)
                .modifier(BarBackground(shape: Circle()))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEditing)
    }
}

// MARK: - BarBackground

/// Glass on iOS 26, material before.
private struct BarBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - VaultSearchBarRepresentable

/// A native `UISearchBar` (minimal style, no cancel button until editing) bound to the search text.
private struct VaultSearchBarRepresentable: UIViewRepresentable {
    @Binding var isEditing: Bool
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.searchBarStyle = .minimal
        bar.placeholder = Localizations.search
        bar.autocorrectionType = .no
        bar.autocapitalizationType = .none
        bar.delegate = context.coordinator
        bar.backgroundImage = UIImage()
        bar.accessibilityIdentifier = "VaultSearchField"
        return bar
    }

    func updateUIView(_ bar: UISearchBar, context: Context) {
        if bar.text != text { bar.text = text }
        bar.setShowsCancelButton(isEditing, animated: true)
        if !isEditing, bar.isFirstResponder { bar.resignFirstResponder() }
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: VaultSearchBarRepresentable
        init(_ parent: VaultSearchBarRepresentable) { self.parent = parent }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) { parent.isEditing = true }
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { parent.text = searchText }
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""
            parent.isEditing = false
            searchBar.text = ""
            searchBar.resignFirstResponder()
        }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    }
}
