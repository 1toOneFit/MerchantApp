import SwiftUI

extension AppPhase {
    /// Maps SwiftUI's scene phase; an unknown future phase counts as `.inactive`, which sends no
    /// lifecycle event.
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        @unknown default: self = .inactive
        }
    }
}
