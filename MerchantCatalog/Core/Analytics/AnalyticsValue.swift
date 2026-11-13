/// A typed analytics property or user-property value.
///
/// Only the kinds the taxonomy uses.
enum AnalyticsValue: Equatable, Sendable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case bool(Bool)
    /// E.g. `price` (S5).
    case double(Double)
    /// E.g. `experiment_assignments` (S6): experiment id → variant.
    case stringMap([String: String])

    /// The plain value, as logs and the Diagnostics sheet show it.
    var description: String {
        switch self {
        case .string(let value): value
        case .int(let value): String(value)
        case .bool(let value): String(value)
        case .double(let value): String(value)
        case .stringMap(let values):
            "{" + values.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + "}"
        }
    }
}
