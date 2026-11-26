import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - DeviceManagementView

/// A view that shows all the logged-in devices and allows the user to manage them.
///
struct DeviceManagementView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<DeviceManagementState, DeviceManagementAction, DeviceManagementEffect>

    // MARK: View

    var body: some View {
        PassYLoadingContent(state: store.state.loadingState) { devices in
            if devices.isEmpty {
                PassYEmptyState(Localizations.noDevicesFound, systemImage: "laptopcomputer.and.iphone")
                    .passYGroupedBackground()
            } else {
                devicesList(devices)
            }
        }
        .navigationBar(title: Localizations.devices, titleDisplayMode: .inline)
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
            send: DeviceManagementAction.toastShown,
        ))
    }

    // MARK: Private Views

    /// The list of devices.
    ///
    /// - Parameter devices: The devices to display.
    ///
    private func devicesList(_ devices: [DeviceListItem]) -> some View {
        Form {
            ForEach(devices) { device in
                DeviceRow(
                    store: store.child(
                        state: { _ in DeviceRowState(device: device) },
                        mapAction: DeviceManagementAction.deviceRow,
                        mapEffect: nil,
                    ),
                )
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty") {
    DeviceManagementView(store: Store(processor: StateProcessor(state: DeviceManagementState(
        loadingState: .data([]),
    ))))
}

#Preview("Devices") {
    DeviceManagementView(store: Store(processor: StateProcessor(state: DeviceManagementState(
        loadingState: .data([
            DeviceListItem(
                activityStatus: .today,
                deviceType: .iOS,
                displayName: "iPhone 15 Pro",
                firstLogin: Date(),
                id: "1",
                identifier: "abc123",
                isCurrentSession: true,
                isTrusted: true,
                lastActivityDate: Date(),
                pendingAuthRequestId: nil,
                pendingRequest: nil,
            ),
            DeviceListItem(
                activityStatus: .pastSevenDays,
                deviceType: .chromeExtension,
                displayName: "Chrome Extension",
                firstLogin: Date().addingTimeInterval(-86400 * 30),
                id: "2",
                identifier: "def456",
                isCurrentSession: false,
                isTrusted: false,
                lastActivityDate: Date().addingTimeInterval(-86400 * 3),
                pendingAuthRequestId: nil,
                pendingRequest: nil,
            ),
            DeviceListItem(
                activityStatus: .overThirtyDaysAgo,
                deviceType: .macOsDesktop,
                displayName: "macOS",
                firstLogin: Date().addingTimeInterval(-86400 * 90),
                id: "3",
                identifier: "ghi789",
                isCurrentSession: false,
                isTrusted: true,
                lastActivityDate: Date().addingTimeInterval(-86400 * 45),
                pendingAuthRequestId: nil,
                pendingRequest: nil,
            ),
        ]),
    ))))
}
#endif
