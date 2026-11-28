import BitwardenKit
import Foundation

public class MockAppInfoService: AppInfoService {
    public var appInfoStringValue = """
    Pass-Y © 2026 aiity
    Based on Bitwarden iOS © Bitwarden Inc. (GPLv3)

    📝 Bitwarden 1.0 (1)
    📦 Bundle: com.8bit.bitwarden
    📱 Device: iPhone14,2
    🍏 System: iOS 16.4
    """
    public var appInfoWithoutCopyrightStringValue = """
    📝 Bitwarden 1.0 (1)
    📦 Bundle: com.8bit.bitwarden
    📱 Device: iPhone14,2
    🍏 System: iOS 16.4
    """
    public var copyrightString = """
    Pass-Y © 2026 aiity
    Based on Bitwarden iOS © Bitwarden Inc. (GPLv3)
    """
    public var isBetaBuild = false
    public var versionString = "1.0 (1)"

    public var appInfoString: String {
        get async {
            appInfoStringValue
        }
    }

    public var appInfoWithoutCopyrightString: String {
        get async {
            appInfoWithoutCopyrightStringValue
        }
    }

    public init() {}
}
