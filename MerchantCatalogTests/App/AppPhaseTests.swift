import SwiftUI
import Testing
@testable import MerchantCatalog

struct AppPhaseTests {
    @Test(arguments: [
        (ScenePhase.active, AppPhase.active),
        (.inactive, .inactive),
        (.background, .background),
    ])
    func mapsScenePhases(scenePhase: ScenePhase, appPhase: AppPhase) {
        #expect(AppPhase(scenePhase) == appPhase)
    }
}
