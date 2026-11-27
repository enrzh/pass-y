import BitwardenKit
import BitwardenSdk
import SwiftUI

// MARK: - VaultItemIconTile

/// The `PassYIconTile` of a vault list row: a login shows its website icon on a neutral tile and, until the icon is
/// loaded or without one, the tinted first letter of its name; a passkey, card, identity, note or key shows its type
/// symbol; groups (folders, collections, types, trash ...) and codes show the symbol and colour of their category
/// tile on the home screen.
struct VaultItemIconTile: View {
    // MARK: Properties

    /// The row's item.
    let item: VaultListItem

    /// The base URL of the website icons.
    let iconBaseURL: URL?

    /// Whether website icons are shown.
    let showWebIcons: Bool

    // MARK: View

    var body: some View {
        Group {
            switch item.itemType {
            case let .cipher(cipherItem, fido2):
                cipherTile(cipherItem, hasPasskey: fido2 != nil)
            case let .group(group, _):
                PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
            case let .totp(name, model):
                websiteOrLetterTile(name: name, item: VaultListItem(cipherListView: model.cipherListView))
            }
        }
        // UI tests find the icon kind through this identifier (the tile itself is decorative).
        .accessibilityIdentifier(item.iconAccessibilityId)
    }

    // MARK: Private

    /// The tile of a cipher row.
    @ViewBuilder
    private func cipherTile(_ cipherItem: CipherListView, hasPasskey: Bool) -> some View {
        let type = CipherType(cipherItem.type)
        if cipherItem.isDecryptionFailure {
            PassYIconTile(systemImage: "exclamationmark.triangle.fill", tint: .red)
        } else if type == .login, hasPasskey {
            PassYIconTile(systemImage: "person.badge.key.fill", tint: .blue)
        } else if type == .login {
            websiteOrLetterTile(name: cipherItem.name, item: item)
        } else {
            let group = VaultListGroup(tileFor: type)
            PassYIconTile(systemImage: group.tileSymbol, tint: group.tileColor)
        }
    }

    /// The website icon of a login on a neutral tile, the tinted first letter until it is loaded or without one.
    @ViewBuilder
    private func websiteOrLetterTile(name: String, item: VaultListItem?) -> some View {
        if showWebIcons, let iconBaseURL, let data = item?.cipherDecorativeIconDataView,
           let url = IconImageHelper.getIconImage(for: data, from: iconBaseURL) {
            CipherIconAsyncImage(
                url: url,
                uiImageContent: { image in
                    // A dark logo on transparency (e.g. chatgpt.com) gets a white tile: visible in dark mode too.
                    PassYIconTile(style: image.passYIsDarkOnTransparency ? .light : .plain) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(PassYDesign.Spacing.small - 1)
                    }
                },
                placeholder: { PassYIconTile(letter: name) },
            )
        } else {
            PassYIconTile(letter: name)
        }
    }
}

// MARK: - UIImage + dark logo

extension UIImage {
    /// The images already measured (a web icon is measured once, not per row body).
    private static let darkOnTransparencyCache = NSCache<UIImage, NSNumber>()

    /// Whether the image is a dark logo on a transparent background: at least a fifth of it is transparent and its
    /// visible pixels are dark on average (luminance below 0.3). Such an icon disappears on a dark tile; colourful icons
    /// and icons with their own background are not affected.
    var passYIsDarkOnTransparency: Bool {
        if let cached = Self.darkOnTransparencyCache.object(forKey: self) { return cached.boolValue }
        let result = Self.measureDarkOnTransparency(self)
        Self.darkOnTransparencyCache.setObject(NSNumber(value: result), forKey: self)
        return result
    }

    /// Draws the image into 16 x 16 RGBA pixels and measures transparency and the luminance of the visible pixels.
    static func measureDarkOnTransparency(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }
        var transparent = 0
        var luminance = 0.0
        var weight = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            if alpha < 0.1 {
                transparent += 1
                continue
            }
            // Premultiplied: divide by alpha for the colour itself.
            let red = Double(pixels[index]) / 255 / alpha
            let green = Double(pixels[index + 1]) / 255 / alpha
            let blue = Double(pixels[index + 2]) / 255 / alpha
            luminance += (0.2126 * red + 0.7152 * green + 0.0722 * blue) * alpha
            weight += alpha
        }
        guard weight > 0, transparent * 5 >= side * side else { return false }
        return luminance / weight < 0.3
    }
}

// MARK: - VaultListGroup + cipher type

extension VaultListGroup {
    /// The category of a cipher type (its symbol and colour are the row tile's).
    init(tileFor type: CipherType) {
        switch type {
        case .login: self = .login
        case .secureNote: self = .secureNote
        case .card: self = .card
        case .identity: self = .identity
        case .sshKey: self = .sshKey
        case .bankAccount: self = .bankAccount
        case .driversLicense: self = .driversLicense
        case .passport: self = .passport
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Item tiles") {
    HStack(spacing: 12) {
        VaultItemIconTile(
            item: VaultListItem(cipherListView: .fixture(id: "1", name: "GitHub"))!,
            iconBaseURL: nil,
            showWebIcons: false,
        )
        VaultItemIconTile(
            item: VaultListItem(id: "2", itemType: .group(.folder(id: "1", name: "Work"), 3)),
            iconBaseURL: nil,
            showWebIcons: false,
        )
        VaultItemIconTile(
            item: VaultListItem(id: "3", itemType: .group(.card, 3)),
            iconBaseURL: nil,
            showWebIcons: false,
        )
    }
    .padding()
}
#endif
