/// A typed analytics property or user-property value.
///
/// Only the kinds the taxonomy uses so far; `double` (S5 `price`) and a string map (S6
/// `experiment_assignments`) arrive with their first event or property.
enum AnalyticsValue: Equatable, Sendable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case bool(Bool)

    /// The plain value, as logs and the Diagnostics sheet show it.
    var description: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .bool(let value): String(value)
        }
    }
}
