import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SendBottomBar

/// The bottom bar of the Send list: the native search field and the "new send" control, like the vault's bar.
///
struct SendBottomBar: View {
    // MARK: Properties

    /// Called with the chosen send type.
    let addSend: (SendType) async -> Void

    /// The send type that is the only one that can be created, if restricted.
    let restrictedSendType: SendType?

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
                addControl
                    .frame(width: 44, height: 44)
                    .modifier(BarBackground(shape: Circle()))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background {
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

    // MARK: Private

    @ViewBuilder private var addControl: some View {
        let symbol = Image(systemName: "plus")
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        if let restrictedSendType {
            AsyncButton {
                await addSend(restrictedSendType)
            } label: {
                symbol
            }
            .accessibilityLabel(Localizations.add)
            .accessibilityIdentifier("AddItemFloatingActionButton")
        } else {
            Menu {
                ForEach(SendType.allCases) { type in
                    AsyncButton {
                        await addSend(type)
                    } label: {
                        Label(type.localizedName, systemImage: type == .text ? "doc.text" : "doc")
                    }
                }
            } label: {
                symbol
            }
            .accessibilityLabel(Localizations.add)
            .accessibilityIdentifier("AddItemFloatingActionButton")
        }
    }
}
