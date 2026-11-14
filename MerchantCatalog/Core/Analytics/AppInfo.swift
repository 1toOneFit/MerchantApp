import Foundation

/// Facts about the running app and device that become launch user properties (Analytics.md § 2).
struct AppInfo: Equatable, Sendable {
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    /// Hardware identifier such as `iPhone17,1`; in the Simulator, the simulated device's.
    let deviceModel: String
    let isDebugBuild: Bool

    static func current() -> AppInfo {
        let bundle = Bundle.main
        let processInfo = ProcessInfo.processInfo
        return AppInfo(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            osVersion: osVersionString(processInfo.operatingSystemVersion),
            deviceModel: deviceModel(machine: machineIdentifier(), environment: processInfo.environment),
            isDebugBuild: isDebugConfiguration
        )
    }

    /// `26.0`, or `26.1.2` when there is a patch version.
    static func osVersionString(_ version: OperatingSystemVersion) -> String {
        let majorMinor = "\(version.majorVersion).\(version.minorVersion)"
        return version.patchVersion > 0 ? "\(majorMinor).\(version.patchVersion)" : majorMinor
    }

    /// The Simulator reports the Mac's `arm64` as its machine, so its own model identifier wins.
    static func deviceModel(machine: String, environment: [String: String]) -> String {
        if let simulated = environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated
        }
        return machine
    }

    private static func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private static var isDebugConfiguration: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
