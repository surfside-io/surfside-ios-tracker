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

/// Verifies that addTransaction()/addImpression() are stored as commerce contexts and
/// attached to the next setCommerceAction() event instead of firing standalone events (JJRC-148).
class SurfsideCommerceContextsTests: XCTestCase {

    func testTransactionAndProductAttachToSingleActionEvent() {
        let (plugin, namespace) = createTracker()

        plugin.addTransaction(id: "t-1", revenue: 59.98, trackerNamespaces: [namespace])
        plugin.addProduct(id: "p-1", name: "Product", trackerNamespaces: [namespace])
        plugin.setCommerceAction(action: "purchase", trackerNamespaces: [namespace])

        waitForTrackedEvents(count: 1)

        // Exactly one event: a standalone transaction event would have arrived first
        // on the tracker's serial processing queue.
        XCTAssertEqual(sink.trackedEvents.count, 1)
        let event = sink.trackedEvents[0]
        XCTAssertEqual(event.schema, CommerceActionEntity.schema)

        let transactionEntities = event.entities.filter { $0.schema == CommerceTransactionEntity.schema }
        XCTAssertEqual(transactionEntities.count, 1)
        XCTAssertEqual(transactionEntities.first?.data["id"] as? String, "t-1")
        // JJRC-283: revenue serializes as a JSON number, not a string (parity with the web SDK).
        XCTAssertEqual(transactionEntities.first?.data["revenue"] as? Double, 59.98)
        XCTAssertNil(transactionEntities.first?.data["revenue"] as? String)

        let productEntities = event.entities.filter { $0.schema == CommerceProductEntity.schema }
        XCTAssertEqual(productEntities.count, 1)
        XCTAssertEqual(productEntities.first?.data["id"] as? String, "p-1")
    }

    func testImpressionAttachesToActionEvent() {
        let (plugin, namespace) = createTracker()

        plugin.addImpression(id: "i-1", name: "Impression", price: 12.50, trackerNamespaces: [namespace])
        plugin.setCommerceAction(action: "impression", trackerNamespaces: [namespace])

        waitForTrackedEvents(count: 1)

        XCTAssertEqual(sink.trackedEvents.count, 1)
        let impressionEntities = sink.trackedEvents[0].entities.filter { $0.schema == CommerceImpressionEntity.schema }
        XCTAssertEqual(impressionEntities.count, 1)
        XCTAssertEqual(impressionEntities.first?.data["id"] as? String, "i-1")
        // JJRC-283: price serializes as a JSON number, not a string (parity with the web SDK).
        XCTAssertEqual(impressionEntities.first?.data["price"] as? Double, 12.50)
        XCTAssertNil(impressionEntities.first?.data["price"] as? String)
    }

    func testCommerceContextsAreClearedAfterAction() {
        let (plugin, namespace) = createTracker()

        plugin.addTransaction(id: "t-1", trackerNamespaces: [namespace])
        plugin.setCommerceAction(action: "purchase", trackerNamespaces: [namespace])
        plugin.setCommerceAction(action: "detail", trackerNamespaces: [namespace])

        waitForTrackedEvents(count: 2)

        XCTAssertEqual(sink.trackedEvents.count, 2)
        let secondEvent = sink.trackedEvents[1]
        XCTAssertTrue(secondEvent.entities.filter { $0.schema == CommerceTransactionEntity.schema }.isEmpty)
    }

    // MARK: - Utility functions

    private var sink: EventSink!
    private var eventTracked: ((Int) -> Void)?

    private func createTracker() -> (SurfsideEvent, String) {
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

        let namespace = "surfsideCommerceContexts" + UUID().uuidString

        sink = EventSink(callback: { [weak self] _ in
            guard let self = self else { return }
            self.eventTracked?(self.sink.trackedEvents.count)
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

        return (plugin, namespace)
    }

    private func waitForTrackedEvents(count: Int) {
        let expectation = expectation(description: "Tracked \(count) events")
        expectation.assertForOverFulfill = false
        eventTracked = { tracked in
            if tracked >= count {
                expectation.fulfill()
            }
        }
        // The events may already have been tracked before this subscription was set up.
        if sink.trackedEvents.count >= count {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        eventTracked = nil
    }
}
