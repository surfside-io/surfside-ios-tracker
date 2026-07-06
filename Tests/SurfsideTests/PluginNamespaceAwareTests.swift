//  Copyright (c) 2022-2025 Surfside Solutions Inc
//  All rights reserved.

import XCTest
@testable import SurfsideTracker

/// Regression tests for JJRC-147: `PluginNamespaceAware` plugins must receive the tracker
/// namespace automatically, however they are attached.
class PluginNamespaceAwareTests: XCTestCase {

    private class NamespaceRecordingPlugin: NSObject, PluginIdentifiable, PluginNamespaceAware, ConfigurationProtocol {
        var identifier = "namespaceRecorder"
        private(set) var receivedNamespace: String?

        func setTrackerNamespace(_ namespace: String) {
            receivedNamespace = namespace
        }

        func toStateMachine() -> StateMachineProtocol {
            return PluginStateMachine(
                identifier: identifier,
                entitiesConfiguration: nil,
                afterTrackConfiguration: nil,
                filterConfiguration: nil
            )
        }
    }

    override func tearDown() {
        Surfside.removeAllTrackers()
        super.tearDown()
    }

    func testPluginPassedAtTrackerCreationReceivesNamespace() {
        let plugin = NamespaceRecordingPlugin()
        let namespace = "nsCreation-" + UUID().uuidString

        _ = createTracker(namespace: namespace, configurations: [plugin])

        XCTAssertEqual(plugin.receivedNamespace, namespace)
    }

    func testPluginAddedAfterTrackerCreationReceivesNamespace() {
        let plugin = NamespaceRecordingPlugin()
        let namespace = "nsAdd-" + UUID().uuidString
        let tracker = createTracker(namespace: namespace, configurations: [])

        tracker.plugins.add(plugin: plugin)

        XCTAssertEqual(plugin.receivedNamespace, namespace)
    }

    func testSurfsideEventAttachesGlobalContextsWithoutExplicitNamespace() {
        let surfsideEvent = SurfsideEvent()
        let namespace = "nsSurfside-" + UUID().uuidString

        let expect = expectation(description: "Tracked event carries the user global context")
        let eventSink = EventSink { event in
            XCTAssertTrue(event.entities.contains { $0.schema == UserEntity.schema })
            expect.fulfill()
        }

        let tracker = createTracker(namespace: namespace, configurations: [surfsideEvent, eventSink])
        SurfsideController.shared.registerTracker(tracker)
        surfsideEvent.setUser(userId: "user-1", trackerNamespaces: [namespace])

        _ = tracker.track(Structured(category: "cat", action: "act"))

        wait(for: [expect], timeout: 10)
    }

    private func createTracker(namespace: String, configurations: [ConfigurationProtocol]) -> TrackerController {
        let networkConfig = NetworkConfiguration(networkConnection: MockNetworkConnection(requestOption: .post, statusCode: 200))
        let trackerConfig = TrackerConfiguration()
        trackerConfig.installAutotracking = false
        trackerConfig.lifecycleAutotracking = false
        return Surfside.createTracker(namespace: namespace,
                                      network: networkConfig,
                                      configurations: configurations + [trackerConfig])
    }
}
