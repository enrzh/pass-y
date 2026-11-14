import BitwardenResources
import SwiftUI
import UIKit

// MARK: - Notification.Name

extension Notification.Name {
    /// Asks the bottom search bar to resign first responder immediately (posted when the vault tab disappears).
    static let vaultSearchResign = Notification.Name("de.aiity.passy.vaultSearchResign")
}

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

            if isEditing || !text.isEmpty {
                SearchCancelButton {
                    text = ""
                    isEditing = false
                    NotificationCenter.default.post(name: .vaultSearchResign, object: nil)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
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
        // The bar swallows touches in its whole area so they never reach list rows underneath.
        .contentShape(Rectangle())
        // Like system toolbars, the floating bar stops growing at the largest non-accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background {
            // Solid below, soft fade above: rows never show through the glass or behind the tab bar.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .frame(height: 28)
                Color(.systemGroupedBackground)
            }
            .padding(.top, -28)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isEditing || !text.isEmpty)
    }
}

// MARK: - BarBackground

/// Glass on iOS 26, material before.
struct BarBackground<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - SearchCancelButton

/// The cancel control of the bottom bars: clears the search and closes the keyboard. It is a real SwiftUI button
/// because the `UISearchBar` cancel button did not clear the search after the keyboard had been closed with the
/// Search key (it only re-activated the field).
struct SearchCancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(BarBackground(shape: Circle()))
        .accessibilityLabel(Localizations.cancel)
        .accessibilityIdentifier("VaultSearchCancel")
    }
}

// MARK: - VaultSearchBarRepresentable

/// A native `UISearchBar` (minimal style, no cancel button until editing) bound to the search text.
struct VaultSearchBarRepresentable: UIViewRepresentable {
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
        context.coordinator.observeResign(of: bar)
        return bar
    }

    func updateUIView(_ bar: UISearchBar, context: Context) {
        if bar.text != text { bar.text = text }
        bar.setShowsCancelButton(false, animated: false)
        if !isEditing, bar.isFirstResponder { bar.resignFirstResponder() }
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: VaultSearchBarRepresentable
        private var resignObserver: NSObjectProtocol?

        init(_ parent: VaultSearchBarRepresentable) { self.parent = parent }

        deinit { resignObserver.map(NotificationCenter.default.removeObserver) }

        func observeResign(of bar: UISearchBar) {
            resignObserver = NotificationCenter.default.addObserver(
                forName: .vaultSearchResign, object: nil, queue: .main,
            ) { [weak bar] _ in bar?.resignFirstResponder() }
        }

        /// Set while a cancel tap is being processed: UIKit may re-activate the field right after the cancel
        /// (when the bar was not first responder), which must not leave the vault in search mode.
        private var isCancelling = false

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            if isCancelling {
                searchBar.resignFirstResponder()
                return
            }
            parent.isEditing = true
        }

        // UIKit also ends editing when the screen navigates away (e.g. opening a result); keep the + button in sync.
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) { parent.isEditing = false }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { parent.text = searchText }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            isCancelling = true
            parent.text = ""
            parent.isEditing = false
            searchBar.text = ""
            searchBar.resignFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak searchBar] in
                searchBar?.resignFirstResponder()
                self?.parent.isEditing = false
                self?.isCancelling = false
            }
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    }
}
