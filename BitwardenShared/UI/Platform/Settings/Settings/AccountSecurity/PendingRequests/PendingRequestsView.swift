import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - PendingRequestsView

/// A view that shows all the pending login requests and allows the user to approve or deny them.
///
struct PendingRequestsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<PendingRequestsState, PendingRequestsAction, PendingRequestsEffect>

    // MARK: View

    var body: some View {
        PassYLoadingContent(state: store.state.loadingState) { pendingRequests in
            if pendingRequests.isEmpty {
                PassYEmptyState(Localizations.noPendingRequests, systemImage: "iphone.and.arrow.forward")
                    .passYGroupedBackground()
            } else {
                pendingRequestsList(pendingRequests)
            }
        }
        .navigationBar(title: Localizations.pendingLogInRequests, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.loadData)
        }
        .refreshable { [weak store] in
            await store?.perform(.loadData)
        }
        .toast(store.binding(
            get: \.toast,
            send: PendingRequestsAction.toastShown,
        ))
    }

    // MARK: Private Views

    /// The list of pending requests, with "Decline all" as a destructive row in its own section.
    ///
    /// - Parameter pendingRequests: The pending login requests to display.
    ///
    private func pendingRequestsList(_ pendingRequests: [LoginRequest]) -> some View {
        Form {
            Section {
                ForEach(pendingRequests) { pendingRequest in
                    pendingRequestRow(pendingRequest)
                }
            }

            Section {
                PassYSettingsRow(
                    Localizations.declineAllRequests,
                    systemImage: "trash.fill",
                    role: .destructive,
                    accessory: .none,
                    identifier: "DeclineAllRequestsButton",
                ) {
                    store.send(.declineAllRequestsTapped)
                }
            }
        }
    }

    /// A pending request row: the fingerprint phrase, the device type and the time, opening the request.
    private func pendingRequestRow(_ pendingRequest: LoginRequest) -> some View {
        Button {
            store.send(.requestTapped(pendingRequest))
        } label: {
            HStack(spacing: PassYDesign.Spacing.medium) {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    PassYFingerprintPhrase(
                        title: Localizations.fingerprintPhrase,
                        phrase: pendingRequest.fingerprintPhrase ?? "",
                    )
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            deviceType(pendingRequest)
                            Spacer()
                            creationDate(pendingRequest)
                        }
                        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                            deviceType(pendingRequest)
                            creationDate(pendingRequest)
                        }
                    }
                }
                PassYDisclosureChevron()
            }
            .contentShape(Rectangle())
            .foregroundStyle(Color.primary)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.automatic)
        .foregroundStyle(Color.primary)
        .accessibilityIdentifier("LoginRequestCell")
    }

    /// The device type of a request.
    private func deviceType(_ request: LoginRequest) -> some View {
        Text(request.requestDeviceType)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("DeviceTypeValueLabel")
    }

    /// The creation time of a request.
    private func creationDate(_ request: LoginRequest) -> some View {
        Text(request.creationDate.formatted(.dateTime))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty") {
    PendingRequestsView(store: Store(processor: StateProcessor(state: PendingRequestsState(
        loadingState: .data([]),
    ))))
}

#Preview("Requests") {
    PendingRequestsView(store: Store(processor: StateProcessor(state: PendingRequestsState(
        loadingState: .data(
            [
                .fixture(
                    creationDate: .now,
                    fingerprintPhrase: "pineapple-on-pizza-is-the-best",
                    id: "1",
                ),
                .fixture(
                    creationDate: .now,
                    fingerprintPhrase: "coconuts-are-underrated",
                    id: "2",
                ),
            ],
        ),
    ))))
}
#endif
