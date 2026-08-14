//  Copyright (c) 2013-present Snowplow Analytics Ltd. All rights reserved.
//
//  This program is licensed to you under the Apache License Version 2.0,
//  and you may not use this file except in compliance with the Apache License
//  Version 2.0. You may obtain a copy of the Apache License Version 2.0 at
//  http://www.apache.org/licenses/LICENSE-2.0.
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the Apache License Version 2.0 is distributed on
//  an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
//  express or implied. See the Apache License Version 2.0 for the specific
//  language governing permissions and limitations there under.

import XCTest
@testable import SurfsideTracker

/// Verifies that the Surfside persistent-context setters attach entities to
/// tracked events through Snowplow's native `tracker.globalContexts` system (JJRC-146).
class SurfsideGlobalContextsTests: XCTestCase {

    func testSetUserAttachesGlobalContextToEvents() {
        let (tracker, plugin, namespace) = createTracker()

        plugin.setUser(userId: "user-1", email: "user@example.com", phone: "+12345678901", trackerNamespaces: [namespace])

        let entities = entitiesAttachedToTrackedEvent(on: tracker)
        let userEntities = entities.filter { $0.schema == UserEntity.schema }
        XCTAssertEqual(userEntities.count, 1)
        let data = userEntities.first?.data
        XCTAssertEqual(data?["userId"] as? String, "user-1")
        // Raw PII is hashed on-device and never emitted — that absence is the point.
        XCTAssertNil(data?["email"])
        XCTAssertNil(data?["phone"])
        XCTAssertEqual(data?["hashed_email"] as? String, "tMmiiTI7IaAcPpQPFQ65uMVCWH8av9jw4cwf/F5HVRQ=")
        XCTAssertEqual(data?["hashed_phone"] as? String, "EObwtHBUqDNZR33LNSMdtt5cafsYFuGmuY4ZLenlue4=")
    }

    func testSetSurfIdAttachesUidContextToEvents() {
        let (tracker, plugin, namespace) = createTracker()

        plugin.setSurfId(surfId: "surf-1", trackerNamespaces: [namespace])

        let entities = entitiesAttachedToTrackedEvent(on: tracker)
        let uidEntities = entities.filter { $0.schema == UidContextEntity.schema }
        XCTAssertEqual(uidEntities.count, 1)
        XCTAssertEqual(uidEntities.first?.data["uid2"] as? String, "surf-1")
    }

    func testGetResolvedIdentityReturnsUid2AndUserId() {
        let (_, plugin, namespace) = createTracker()

        plugin.setUser(userId: "user-1", trackerNamespaces: [namespace])
        plugin.setSurfId(surfId: "surf-1", trackerNamespaces: [namespace])

        let identity = plugin.getResolvedIdentity(trackerNamespace: namespace)
        XCTAssertEqual(identity["userId"], "user-1")
        XCTAssertEqual(identity["uid2"], "surf-1")
    }

    func testCallingSetterAgainReplacesExistingContext() {
        let (tracker, plugin, namespace) = createTracker()

        plugin.setUser(userId: "first", trackerNamespaces: [namespace])
        plugin.setUser(userId: "second", trackerNamespaces: [namespace])

        let entities = entitiesAttachedToTrackedEvent(on: tracker)
        let userEntities = entities.filter { $0.schema == UserEntity.schema }
        XCTAssertEqual(userEntities.count, 1)
        XCTAssertEqual(userEntities.first?.data["userId"] as? String, "second")
    }

    func testSettersRegisterTaggedNativeGlobalContexts() {
        let (tracker, plugin, namespace) = createTracker()

        plugin.setUser(userId: "user-1", trackerNamespaces: [namespace])
        plugin.setSurfId(surfId: "surf-1", trackerNamespaces: [namespace])

        let tags = Set(tracker.globalContexts?.tags ?? [])
        XCTAssertTrue(tags.contains("surfside-user"))
        XCTAssertTrue(tags.contains("surfside-surfId"))
    }

    // MARK: - Utility functions

    private var sink: EventSink!
    private var afterTrack: ((InspectableEvent) -> Void)?

    private func createTracker() -> (TrackerController, SurfsideEvent, String) {
        let trackerConfig = TrackerConfiguration()
        trackerConfig.appId = "anAppId"
        trackerConfig.platformContext = false
        trackerConfig.geoLocationContext = false
        trackerConfig.base64Encoding = false
        trackerConfig.sessionContext = false
        trackerConfig.installAutotracking = false
        trackerConfig.lifecycleAutotracking = false
        trackerConfig.applicationContext = false
        trackerConfig.screenContext = false

        let networkConfig = NetworkConfiguration(networkConnection: MockNetworkConnection(requestOption: .post, statusCode: 200))

        let namespace = "surfsideGlobalContexts" + UUID().uuidString

        sink = EventSink(callback: { [weak self] event in
            self?.afterTrack?(event)
        })

        let tracker = Surfside.createTracker(
            namespace: namespace,
            network: networkConfig,
            configurations: [
                sink,
                trackerConfig
            ])

        let plugin = SurfsideEvent()
        tracker.plugins.add(plugin: plugin)
        SurfsideController.shared.registerTracker(tracker)

        return (tracker, plugin, namespace)
    }

    /// Tracks a plain structured event and returns the entities attached to it.
    private func entitiesAttachedToTrackedEvent(on tracker: TrackerController) -> [SelfDescribingJson] {
        let expectation = expectation(description: "Event tracked")
        var entities: [SelfDescribingJson] = []
        afterTrack = { event in
            entities = event.entities
            expectation.fulfill()
        }
        _ = tracker.track(Structured(category: "category", action: "action"))
        wait(for: [expectation], timeout: 1)
        afterTrack = nil
        return entities
    }
}
