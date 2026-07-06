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

class TestMultipleInstances: XCTestCase {
    override func setUp() {
        Surfside.removeAllTrackers()
    }

    override func tearDown() {
        Surfside.removeAllTrackers()
    }

    func testSingleInstanceIsReconfigurable() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        XCTAssertEqual(t1.network?.endpoint, "https://snowplowanalytics.fake/com.snowplowanalytics.snowplow/tp2")
        let t2 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        XCTAssertEqual(t2.network?.endpoint, "https://snowplowanalytics.fake2/com.snowplowanalytics.snowplow/tp2")
        XCTAssertEqual(["t1"], Surfside.instancedTrackerNamespaces)
        XCTAssertTrue(t1.network?.endpoint == t2.network?.endpoint)
    }

    func testMultipleInstances() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        XCTAssertEqual(t1.network?.endpoint, "https://snowplowanalytics.fake/com.snowplowanalytics.snowplow/tp2")
        let t2 = Surfside.createTracker(namespace: "t2", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        XCTAssertEqual(t2.network?.endpoint, "https://snowplowanalytics.fake2/com.snowplowanalytics.snowplow/tp2")
        XCTAssertFalse(t1 === t2)
        let expectedNamespaces = Set<String>(["t1", "t2"])
        XCTAssertEqual(expectedNamespaces, Set<String>(Surfside.instancedTrackerNamespaces))
    }

    func testDefaultTracker() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        _ = Surfside.createTracker(namespace: "t2", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        let td = Surfside.defaultTracker()
        XCTAssertEqual(t1.namespace, td?.namespace)
    }

    func testUpdateDefaultTracker() {
        _ = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        let t2 = Surfside.createTracker(namespace: "t2", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        _ = Surfside.setAsDefault(tracker: t2)
        let td = Surfside.defaultTracker()
        XCTAssertEqual(t2.namespace, td?.namespace)
    }

    func testRemoveTracker() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        let t2 = Surfside.createTracker(namespace: "t2", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        _ = Surfside.remove(tracker: t1)
        XCTAssertNotNil(t2)
        XCTAssertEqual(["t2"], Surfside.instancedTrackerNamespaces)
    }

    func testRecreateTrackerWhichWasRemovedWithSameNamespace() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        _ = Surfside.remove(tracker: t1)
        let t2 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        XCTAssertFalse(t1 === t2)
        XCTAssertEqual(["t1"], Surfside.instancedTrackerNamespaces)
    }

    func testRemoveDefaultTracker() {
        let t1 = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        _ = Surfside.remove(tracker: t1)
        let td = Surfside.defaultTracker()
        XCTAssertNil(td)
        XCTAssertEqual([], Surfside.instancedTrackerNamespaces)
    }

    func testRemoveAllTrackers() {
        _ = Surfside.createTracker(namespace: "t1", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake"))
        _ = Surfside.createTracker(namespace: "t2", network: NetworkConfiguration(endpoint: "snowplowanalytics.fake2"))
        Surfside.removeAllTrackers()
        XCTAssertEqual([], Surfside.instancedTrackerNamespaces)
    }
}
