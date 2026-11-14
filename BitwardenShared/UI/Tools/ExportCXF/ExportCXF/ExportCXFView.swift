import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ExportCXFView

/// A view to export credentials in the Credential Exchange flow.
///
struct ExportCXFView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ExportCXFState, ExportCXFAction, ExportCXFEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: symbolName)
                        .font(.system(size: 52))
                        .foregroundStyle(isFailure ? Color.red : Color.accentColor)
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
            case .start:
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            case let .prepared(results):
                Section {
                    ForEach(results) { result in
                        exportingTypeRow(result: result)
                    }
                } header: {
                    Text(Localizations.itemsToExport)
                        .accessibilityIdentifier("SectionTitle")
                }
            case .failure:
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

                AsyncButton {
                    await store.perform(.cancel)
                } label: {
                    Text(Localizations.cancel).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("CancelButton")
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

    // MARK: Private

    /// Whether the export failed.
    private var isFailure: Bool {
        if case .failure = store.state.status { return true }
        return false
    }

    /// The SF Symbol for the current status.
    private var symbolName: String {
        isFailure ? "xmark.circle.fill" : "square.and.arrow.up"
    }

    /// The row for an exporting type result.
    @ViewBuilder
    private func exportingTypeRow(result: CXFCredentialsResult) -> some View {
        HStack {
            Text(result.localizedTypePlural)
            Spacer()
            Text("\(result.count)")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(result.type)ExportTotal")
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Start") {
    ExportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ExportCXFState(),
            ),
        ),
    )
    .navStackWrapped
}

#Preview("Prepared") {
    ExportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ExportCXFState(
                    status: .prepared(
                        itemsToExport: [
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
    ExportCXFView(
        store: Store(
            processor: StateProcessor(
                state: ExportCXFState(
                    status: .failure(
                        message: "Something went wrong",
                    ),
                ),
            ),
        ),
    ).navStackWrapped
}

#endif
