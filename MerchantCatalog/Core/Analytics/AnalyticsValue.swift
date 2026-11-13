/// A typed analytics property or user-property value.
///
/// Only the kinds the taxonomy uses so far; a string map (S6 `experiment_assignments`) arrives with
/// its property.
enum AnalyticsValue: Equatable, Sendable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case bool(Bool)
    /// E.g. `price` (S5).
    case double(Double)

    /// The plain value, as logs and the Diagnostics sheet show it.
    var description: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .bool(let value): String(value)
        case .double(let value): String(value)
        }
    }
}
