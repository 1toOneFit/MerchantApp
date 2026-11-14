import Foundation
import Testing
@testable import MerchantCatalog

struct LaunchUserPropertiesTests {
    @Test(arguments: [
        (OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0), "26.0"),
        (OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0), "26.1"),
        (OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 2), "26.1.2"),
    ])
    func osVersionString(version: OperatingSystemVersion, text: String) {
        #expect(AppInfo.osVersionString(version) == text)
    }

    @Test(arguments: [
        ("arm64", ["SIMULATOR_MODEL_IDENTIFIER": "iPhone18,3"], "iPhone18,3"),
        ("iPhone17,1", [:], "iPhone17,1"),
        ("iPhone17,1", ["SIMULATOR_MODEL_IDENTIFIER": ""], "iPhone17,1"),
    ])
    func deviceModelPrefersTheSimulatedModel(machine: String, environment: [String: String], model: String) {
        #expect(AppInfo.deviceModel(machine: machine, environment: environment) == model)
    }

    @Test func launchPropertiesListTheSixLaunchProperties() {
        let app = AppInfo(
            appVersion: "1.0",
            buildNumber: "1",
            osVersion: "26.0",
            deviceModel: "iPhone18,3",
            isDebugBuild: true
        )
        let firstSeen = date("2026-11-13T10:00:00Z")

        #expect(UserProperty.launchProperties(app: app, firstSeenDate: firstSeen) == [
            .appVersion("1.0"),
            .buildNumber("1"),
            .osVersion("26.0"),
            .deviceModel("iPhone18,3"),
            .firstSeenDate(firstSeen),
            .isDebugBuild(true),
        ])
    }

    @Test func currentReadsTheRunningApp() {
        let app = AppInfo.current()

        #expect(app.appVersion == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(app.buildNumber == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(app.osVersion == AppInfo.osVersionString(ProcessInfo.processInfo.operatingSystemVersion))
        #expect(!app.deviceModel.isEmpty)
        #expect(app.isDebugBuild)
    }
}
