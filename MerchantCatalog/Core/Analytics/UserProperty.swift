import Foundation

/// User properties from Analytics.md § 2. They describe the installation rather than one event and
/// are set when their value changes. `saved_products_count` (S5) and `experiment_assignments` (S6)
/// arrive with their stages.
enum UserProperty: Equatable, Sendable {
    case appVersion(String)
    case buildNumber(String)
    case osVersion(String)
    case deviceModel(String)
    /// The installation date; sent as `yyyy-MM-dd` in UTC.
    case firstSeenDate(Date)
    case isDebugBuild(Bool)

    var name: String {
        switch self {
        case .appVersion: "app_version"
        case .buildNumber: "build_number"
        case .osVersion: "os_version"
        case .deviceModel: "device_model"
        case .firstSeenDate: "first_seen_date"
        case .isDebugBuild: "is_debug_build"
        }
    }

    var value: AnalyticsValue {
        switch self {
        case .appVersion(let value), .buildNumber(let value), .osVersion(let value), .deviceModel(let value):
            .string(value)
        case .firstSeenDate(let date):
            .string(date.formatted(Self.dayStyle))
        case .isDebugBuild(let value):
            .bool(value)
        }
    }

    /// `yyyy-MM-dd` in UTC.
    private static let dayStyle = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
}

/// A user property's change as providers receive it; `oldValue` is `nil` the first time it is set
/// in this process.
struct UserPropertyChange: Equatable, Sendable {
    let name: String
    let oldValue: AnalyticsValue?
    let newValue: AnalyticsValue
}
