/*
 * Copyright (c) 2022-2025 Surfside Solutions Inc, Snowplow Analytics Ltd
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import XCTest
@testable import SnowplowTracker

class SurfsideEventTests: XCTestCase {
    
    var surfsideEvent: SurfsideEvent!
    var tracker: TrackerController!
    var trackerNamespace: String!
    
    override func setUp() {
        super.setUp()
        
        trackerNamespace = "testTracker"
        
        // Create a real tracker for testing
        let networkConfig = NetworkConfiguration(endpoint: "https://test.com")
        let trackerConfig = TrackerConfiguration()
        trackerConfig.trackerVersionSuffix = "test"
        
        tracker = Snowplow.createTracker(
            namespace: trackerNamespace,
            network: networkConfig,
            configurations: [trackerConfig]
        )
        
        // Register the tracker with the SurfsideController
        SurfsideController.shared.trackers[trackerNamespace] = tracker
        
        // Create SurfsideEvent and add it as a plugin to the tracker
        surfsideEvent = SurfsideEvent()
        tracker.plugins.add(plugin: surfsideEvent)
        
        // Clear any existing global contexts
        tracker.globalContexts?.removeAll()
    }
    
    override func tearDown() {
        // Clean up tracker and global contexts
        tracker.globalContexts?.removeAll()
        tracker.plugins.remove(identifier: surfsideEvent.identifier)
        SurfsideController.shared.trackers.removeAll()
        
        // Remove the tracker from Snowplow
        Snowplow.removeTracker(tracker)
        
        surfsideEvent = nil
        tracker = nil
        trackerNamespace = nil
        
        super.tearDown()
    }
    
    // MARK: - Global Context Tests - Source
    
    func testSourceContextUpdate() {
        // Set initial source context
        surfsideEvent.source(accountId: "account123", sourceId: "source456")
        
        // Verify global context was added to the tracker
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 1)
        
        // Find the source context
        let sourceContextConfig = globalContexts.first { $0.tag == "surfside-source" }
        XCTAssertNotNil(sourceContextConfig, "Source context should be added with tag 'surfside-source'")
        
        // Verify the source context generates the correct entity
        if let contextConfig = sourceContextConfig {
            let generatedContexts = contextConfig.contextGenerator.generateContexts(event: Structured(category: "test", action: "test"), eventSchema: "test")
            XCTAssertEqual(generatedContexts.count, 1)
            
            let sourceContext = generatedContexts.first
            XCTAssertEqual(sourceContext?.schema, "iglu:io.surfside/source/jsonschema/1-0-0")
            let contextData = sourceContext?.data as? [String: Any]
            XCTAssertEqual(contextData?["accountId"] as? String, "account123")
            XCTAssertEqual(contextData?["sourceId"] as? String, "source456")
        }
    }
    
    func testSourceContextUpdateReplacement() {
        // Set initial source context
        surfsideEvent.source(accountId: "account123", sourceId: "source456")
        
        // Update source context with new values
        surfsideEvent.source(accountId: "newAccount", sourceId: "newSource")
        
        // Verify there's still only one global context (old one replaced)
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 1)
        
        // Find the source context
        let sourceContextConfig = globalContexts.first { $0.tag == "surfside-source" }
        XCTAssertNotNil(sourceContextConfig, "Source context should still exist after update")
        
        // Verify the source context now has the updated values
        if let contextConfig = sourceContextConfig {
            let generatedContexts = contextConfig.contextGenerator.generateContexts(event: Structured(category: "test", action: "test"), eventSchema: "test")
            XCTAssertEqual(generatedContexts.count, 1)
            
            let sourceContext = generatedContexts.first
            XCTAssertEqual(sourceContext?.schema, "iglu:io.surfside/source/jsonschema/1-0-0")
            let contextData = sourceContext?.data as? [String: Any]
            XCTAssertEqual(contextData?["accountId"] as? String, "newAccount")
            XCTAssertEqual(contextData?["sourceId"] as? String, "newSource")
        }
    }
    
    // MARK: - Global Context Tests - Segment
    
    func testSegmentContextUpdate() {
        // Set initial segment context
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "high_value")
        
        // Verify global context was added to the tracker
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 1)
        
        // Find the segment context
        let segmentContextConfig = globalContexts.first { $0.tag == "surfside-segment" }
        XCTAssertNotNil(segmentContextConfig, "Segment context should be added with tag 'surfside-segment'")
        
        // Verify the segment context generates the correct entity
        if let contextConfig = segmentContextConfig {
            let generatedContexts = contextConfig.contextGenerator.generateContexts(event: Structured(category: "test", action: "test"), eventSchema: "test")
            XCTAssertEqual(generatedContexts.count, 1)
            
            let segmentContext = generatedContexts.first
            XCTAssertEqual(segmentContext?.schema, "iglu:io.surfside/segment/jsonschema/1-0-0")
            let contextData = segmentContext?.data as? [String: Any]
            XCTAssertEqual(contextData?["segmentId"] as? String, "segment123")
            XCTAssertEqual(contextData?["segmentVal"] as? String, "high_value")
        }
    }
    
    func testRemoveSegmentContext() {
        // Set initial segment context
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "high_value")
        
        // Verify context was added
        let globalContextsBefore = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContextsBefore.count, 1)
        
        // Remove segment context
        surfsideEvent.removeSegment()
        
        // Verify context was removed
        let globalContextsAfter = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContextsAfter.count, 0)
        
        // Verify the specific segment context is gone
        let segmentContextConfig = globalContextsAfter.first { $0.tag == "surfside-segment" }
        XCTAssertNil(segmentContextConfig, "Segment context should be removed")
    }
    
    // MARK: - Global Context Tests - Location
    
    func testLocationContextUpdate() {
        // Set initial location context
        surfsideEvent.setLocation(
            locationId: "store123",
            locationCity: "New York",
            locationState: "NY",
            locationCountry: "US",
            locationLatitude: 40.7128,
            locationLongitude: -74.0060
        )
        
        // Verify global context was added to the tracker
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 1)
        
        // Find the location context
        let locationContextConfig = globalContexts.first { $0.tag == "surfside-location" }
        XCTAssertNotNil(locationContextConfig, "Location context should be added with tag 'surfside-location'")
        
        // Verify the location context generates the correct entity
        if let contextConfig = locationContextConfig {
            let generatedContexts = contextConfig.contextGenerator.generateContexts(event: Structured(category: "test", action: "test"), eventSchema: "test")
            XCTAssertEqual(generatedContexts.count, 1)
            
            let locationContext = generatedContexts.first
            XCTAssertEqual(locationContext?.schema, "iglu:io.surfside/location/jsonschema/1-0-0")
            let contextData = locationContext?.data as? [String: Any]
            XCTAssertEqual(contextData?["id"] as? String, "store123")
            XCTAssertEqual(contextData?["city"] as? String, "New York")
            XCTAssertEqual(contextData?["state"] as? String, "NY")
            XCTAssertEqual(contextData?["country_code"] as? String, "US")
            XCTAssertEqual(contextData?["latitude"] as? Double, 40.7128)
            XCTAssertEqual(contextData?["longitude"] as? Double, -74.0060)
        }
    }
    
    func testRemoveLocationContext() {
        // Set initial location context
        surfsideEvent.setLocation(
            locationId: "store123",
            locationCity: "New York",
            locationLatitude: 40.7128,
            locationLongitude: -74.0060
        )
        
        // Verify context was added
        let globalContextsBefore = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContextsBefore.count, 1)
        
        // Remove location context
        surfsideEvent.removeLocation()
        
        // Verify context was removed
        let globalContextsAfter = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContextsAfter.count, 0)
        
        // Verify the specific location context is gone
        let locationContextConfig = globalContextsAfter.first { $0.tag == "surfside-location" }
        XCTAssertNil(locationContextConfig, "Location context should be removed")
    }
    
    // MARK: - Multiple Context Tests
    
    func testMultipleGlobalContexts() {
        // Set multiple global contexts
        surfsideEvent.source(accountId: "account123", sourceId: "source456")
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "high_value")
        surfsideEvent.setLocation(
            locationId: "store123",
            locationCity: "New York",
            locationState: "NY",
            locationLatitude: 40.7128,
            locationLongitude: -74.0060
        )
        
        // Verify all contexts were added
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 3)
        
        // Verify each context exists
        let sourceContext = globalContexts.first { $0.tag == "surfside-source" }
        let segmentContext = globalContexts.first { $0.tag == "surfside-segment" }
        let locationContext = globalContexts.first { $0.tag == "surfside-location" }
        
        XCTAssertNotNil(sourceContext, "Source context should exist")
        XCTAssertNotNil(segmentContext, "Segment context should exist")
        XCTAssertNotNil(locationContext, "Location context should exist")
    }
    
    // MARK: - Commerce Context Tests
    
    func testCommerceContexts() {
        // Add commerce contexts
        surfsideEvent.addProduct(id: "product123", name: "Test Product", price: 29.99)
        surfsideEvent.addTransaction(id: "trans123", total: 29.99)
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Verify commerce contexts are managed by the plugin
        // Note: Commerce contexts are handled differently - they're attached via the plugin's entitiesConfiguration
        // We can't directly test them through globalContexts, but we can verify the plugin is properly configured
        XCTAssertNotNil(surfsideEvent.entitiesConfiguration, "Plugin should have entities configuration")
        
        // Test that the plugin generates contexts for an event
        let testEvent = Structured(category: "test", action: "test")
        let generatedContexts = surfsideEvent.entitiesConfiguration?(testEvent, "test") ?? []
        
        // Should have commerce contexts (product, transaction, action)
        XCTAssertGreaterThan(generatedContexts.count, 0, "Commerce contexts should be generated")
        
        // Verify commerce action context
        let actionContext = generatedContexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        XCTAssertNotNil(actionContext, "Commerce action context should be present")
        
        if let actionData = actionContext?.data as? [String: Any] {
            XCTAssertEqual(actionData["action"] as? String, "purchase")
        }
    }
}
