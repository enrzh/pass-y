import BitwardenResources
import SwiftUI
import UIKit

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
                .font(.body.weight(.semibold))
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
        // One container only: the glass capsule around the bar. The text field's own fill would be a second one.
        bar.setSearchFieldBackgroundImage(UIImage(), for: .normal)
        bar.searchTextField.backgroundColor = .clear
        bar.searchTextField.borderStyle = .none
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
