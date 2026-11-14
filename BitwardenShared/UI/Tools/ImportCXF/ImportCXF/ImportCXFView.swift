import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ImportCXFView

/// A view to import credentials in the Credential Exchange protocol flow.
///
struct ImportCXFView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ImportCXFState, Void, ImportCXFEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: symbolName)
                        .font(.system(size: 52))
                        .foregroundStyle(symbolStyle)
                        .accessibilityHidden(true)
                    Text(store.state.title)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(store.state.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            switch store.state.status {
            case .importing:
                Section {
                    ProgressView(value: store.state.progress)
                        .accessibilityIdentifier("ImportProgress")
                        .accessibilityLabel(store.state.title)
                }
            case let .success(_, results):
                Section {
                    ForEach(results) { result in
                        importedTypeRow(result: result)
                    }
                }
            case .start,
                 .failure:
                EmptyView()
            }
        }
        .passYNativeFormBackground()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if store.state.showMainButton {
                    AsyncButton {
                        await store.perform(.mainButtonTapped)
                    } label: {
                        Text(store.state.mainButtonTitle).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("MainButton")
                }

                if store.state.showCancelButton {
                    AsyncButton {
                        await store.perform(.cancel)
                    } label: {
                        Text(Localizations.cancel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("CancelButton")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: store.state.status)
        .task {
            await store.perform(.appeared)
        }
        .apply { view in
            if #available(iOS 16.0, *) {
                view.toolbar(.hidden)
            } else {
                view.navigationBarHidden(true)
            }
        }
    }

    /// The SF Symbol for the current status.
    private var symbolName: String {
        switch store.state.status {
        case .start, .importing: "square.and.arrow.down"
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        }
    }

    /// The symbol color for the current status.
    private var symbolStyle: Color {
        switch store.state.status {
        case .success: .green
        case .failure: .red
        default: .accentColor
        }
    }

    // MARK: Private

    /// The row for an imported type result.
    @ViewBuilder
    private func importedTypeRow(result: CXFCredentialsResult) -> some View {
        HStack {
            Text(result.localizedTypePlural)
            Spacer()
            Text("\(result.count)")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(result.type)ImportTotal")
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Start") {
    ImportCXFView(store: Store(processor: StateProcessor(state: ImportCXFState())))
        .navStackWrapped
}

#Preview("Importing") {
    ImportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ImportCXFState(
                    progress: 0.3,
                    status: .importing,
                ),
            ),
        ),
    ).navStackWrapped
}

#Preview("Success") {
    ImportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ImportCXFState(
                    status: .success(
                        totalImportedCredentials: 30,
                        importedResults: [
                            CXFCredentialsResult(count: 13, type: .password),
                            CXFCredentialsResult(count: 7, type: .passkey),
                            CXFCredentialsResult(count: 10, type: .card),
                        ],
                    ),
                ),
            ),
        ),
    ).navStackWrapped
}

#Preview("Failure") {
    ImportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ImportCXFState(
                    status: .failure(
                        message: "Something went wrong",
                    ),
                ),
            ),
        ),
    ).navStackWrapped
}

#endif
