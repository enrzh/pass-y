import AVFoundation
import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ScanCodeView

/// A view that shows the camera to scan QR codes.
struct ScanCodeView: View {
    // MARK: Properties

    /// The AVCaptureSession used to scan qr codes
    let cameraSession: AVCaptureSession

    /// The maximum dynamic type size for the view
    ///     Default is `.xxLarge`
    var maxDynamicTypeSize: DynamicTypeSize = .xxLarge

    /// The `Store` for this view.
    @ObservedObject var store: Store<ScanCodeState, ScanCodeAction, ScanCodeEffect>

    // MARK: Views

    var body: some View {
        content
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(Localizations.scanQrTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismissPressed)
                }
            }
            .task {
                await store.perform(.appeared)
            }
            .onDisappear {
                Task {
                    await store.perform(.disappeared)
                }
            }
    }

    var content: some View {
        ZStack {
            CameraPreviewView(session: cameraSession)
            overlayContent
        }
        .edgesIgnoringSafeArea(.horizontal)
    }

    var informationContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(Localizations.pointYourCameraAtTheQRCode)
                .font(.headline)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text(Localizations.cannotScanQRCode)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(Localizations.enterKeyManually, systemImage: "keyboard") {
                    store.send(.manualEntryPressed)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .dynamicTypeSize(...maxDynamicTypeSize)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder var overlayContent: some View {
        GeometryReader { proxy in
            if proxy.size.width <= proxy.size.height {
                verticalOverlay
            } else {
                horizontalOverlay
            }
        }
    }

    private var horizontalOverlay: some View {
        GeometryReader { geoProxy in
            let size = geoProxy.size
            let orientation = UIDevice.current.orientation
            let infoBlock = infoBlock(width: size.width / 3, height: size.height)
            HStack(spacing: 0.0) {
                if case .landscapeRight = orientation {
                    infoBlock
                }
                Spacer()
                qrCornerGuides(length: size.height)
                Spacer()
                if orientation != .landscapeRight {
                    infoBlock
                }
            }
        }
    }

    private var verticalOverlay: some View {
        GeometryReader { geoProxy in
            let size = geoProxy.size
            VStack(spacing: 0.0) {
                Spacer()
                qrCornerGuides(length: size.width)
                Spacer()
                infoBlock(width: size.width, height: size.height / 3)
            }
        }
    }

    private func infoBlock(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .frame(
                width: width,
                height: height,
            )
            .foregroundColor(.black)
            .opacity(0.5)
            .overlay {
                informationContent
                    .padding(36)
            }
    }

    private func qrCornerGuides(length: CGFloat) -> some View {
        CornerBorderShape(cornerLength: length * 0.1, lineWidth: 3)
            .stroke(lineWidth: 3)
            .foregroundStyle(.white)
            .frame(
                width: length * 0.65,
                height: length * 0.65,
            )
    }
}

#if DEBUG
#Preview("Scan Code View") {
    NavigationView {
        ScanCodeView(
            cameraSession: AVCaptureSession(),
            store: Store(
                processor: StateProcessor(
                    state: ScanCodeState(),
                ),
            ),
        )
    }
    .navigationViewStyle(.stack)
}
#endif
