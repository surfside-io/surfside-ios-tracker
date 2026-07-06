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
@testable import SurfsideTracker

class SurfsideIntegrationTests: XCTestCase {
    
    var surfsideEvent: SurfsideEvent!
    var tracker: TrackerController!
    var trackerNamespace: String!
    var mockEmitter: MockEmitter!
    
    override func setUp() {
        super.setUp()
        
        trackerNamespace = "testTracker"
        
        // Create a mock emitter to capture events
        mockEmitter = MockEmitter()
        
        // Create a real tracker for testing
        let networkConfig = NetworkConfiguration(endpoint: "https://test.com")
        let trackerConfig = TrackerConfiguration()
        trackerConfig.trackerVersionSuffix = "test"
        
        tracker = Surfside.createTracker(
            namespace: trackerNamespace,
            network: networkConfig,
            configurations: [trackerConfig]
        )
        
        // Replace the emitter with our mock
        tracker.emitter = mockEmitter
        
        // Register the tracker with the SurfsideController
        SurfsideController.shared.trackers[trackerNamespace] = tracker
        
        // Create SurfsideEvent and add it as a plugin to the tracker
        surfsideEvent = SurfsideEvent()
        tracker.plugins.add(plugin: surfsideEvent)
        
        // Clear any existing global contexts
        tracker.globalContexts?.removeAll()
        mockEmitter.reset()
    }
    
    override func tearDown() {
        // Clean up tracker and global contexts
        tracker.globalContexts?.removeAll()
        tracker.plugins.remove(identifier: surfsideEvent.identifier)
        SurfsideController.shared.trackers.removeAll()
        
        // Remove the tracker from Snowplow
        Surfside.removeTracker(tracker)
        
        surfsideEvent = nil
        tracker = nil
        trackerNamespace = nil
        mockEmitter = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func trackTestEvent() -> Event {
        let event = Structured(category: "test", action: "test")
        tracker.track(event)
        return event
    }
    
    private func getTrackedEventContexts() -> [SelfDescribingJson] {
        guard let trackedEvent = mockEmitter.trackedEvents.first else {
            return []
        }
        return trackedEvent.contexts
    }
    
    // MARK: - Complete E-commerce Flow Tests
    
    func testCompleteEcommerceFlow() {
        // Set up global contexts
        surfsideEvent.source(accountId: "account123", sourceId: "mobile_app")
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "premium")
        surfsideEvent.setLocation(id: "store123", city: "New York", state: "NY")
        surfsideEvent.setUser(userId: "user123", email: "test@example.com")
        
        // Add commerce contexts for a purchase
        surfsideEvent.addProduct(id: "product1", name: "iPhone", price: 999.99, quantity: 1)
        surfsideEvent.addProduct(id: "product2", name: "Case", price: 29.99, quantity: 1)
        surfsideEvent.addTransaction(id: "trans123", total: 1029.98, tax_amount: 82.40)
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Track the purchase event
        trackTestEvent()
        
        // Verify all contexts are attached
        let contexts = getTrackedEventContexts()
        
        // Global contexts
        let sourceContext = contexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let segmentContext = contexts.first { $0.schema == "iglu:io.surfside/segment/jsonschema/1-0-0" }
        let locationContext = contexts.first { $0.schema == "iglu:io.surfside/location/jsonschema/1-0-0" }
        let userContext = contexts.first { $0.schema == "iglu:io.surfside/user/jsonschema/1-0-0" }
        
        // Commerce contexts
        let productContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        let transactionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        let actionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        
        // Verify all contexts exist
        XCTAssertNotNil(sourceContext, "Source context should be attached")
        XCTAssertNotNil(segmentContext, "Segment context should be attached")
        XCTAssertNotNil(locationContext, "Location context should be attached")
        XCTAssertNotNil(userContext, "User context should be attached")
        XCTAssertEqual(productContexts.count, 2, "Should have 2 product contexts")
        XCTAssertNotNil(transactionContext, "Transaction context should be attached")
        XCTAssertNotNil(actionContext, "Action context should be attached")
        
        // Verify context data
        if let sourceData = sourceContext?.data as? [String: Any] {
            XCTAssertEqual(sourceData["accountId"] as? String, "account123")
            XCTAssertEqual(sourceData["sourceId"] as? String, "mobile_app")
        }
        
        if let actionData = actionContext?.data as? [String: Any] {
            XCTAssertEqual(actionData["action"] as? String, "purchase")
        }
        
        if let transactionData = transactionContext?.data as? [String: Any] {
            XCTAssertEqual(transactionData["id"] as? String, "trans123")
            XCTAssertEqual(transactionData["total"] as? Double, 1029.98)
            XCTAssertEqual(transactionData["tax_amount"] as? Double, 82.40)
        }
    }
    
    // MARK: - Multiple Events with Persistent Contexts
    
    func testMultipleEventsWithPersistentGlobalContexts() {
        // Set up global contexts
        surfsideEvent.source(accountId: "account123", sourceId: "mobile_app")
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "premium")
        
        // Track first event
        trackTestEvent()
        let firstEventContexts = getTrackedEventContexts()
        
        // Reset mock emitter for second event
        mockEmitter.reset()
        
        // Track second event
        trackTestEvent()
        let secondEventContexts = getTrackedEventContexts()
        
        // Verify both events have the same global contexts
        let firstSourceContext = firstEventContexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let secondSourceContext = secondEventContexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        
        XCTAssertNotNil(firstSourceContext, "First event should have source context")
        XCTAssertNotNil(secondSourceContext, "Second event should have source context")
        
        // Verify context data is the same
        let firstSourceData = firstSourceContext?.data as? [String: Any]
        let secondSourceData = secondSourceContext?.data as? [String: Any]
        
        XCTAssertEqual(firstSourceData?["accountId"] as? String, "account123")
        XCTAssertEqual(secondSourceData?["accountId"] as? String, "account123")
        XCTAssertEqual(firstSourceData?["sourceId"] as? String, "mobile_app")
        XCTAssertEqual(secondSourceData?["sourceId"] as? String, "mobile_app")
    }
    
    // MARK: - Context Updates Between Events
    
    func testContextUpdatesAffectSubsequentEvents() {
        // Set initial global context
        surfsideEvent.source(accountId: "account123", sourceId: "mobile_app")
        
        // Track first event
        trackTestEvent()
        let firstEventContexts = getTrackedEventContexts()
        
        // Update global context
        surfsideEvent.source(accountId: "newAccount", sourceId: "web_app")
        
        // Reset mock emitter for second event
        mockEmitter.reset()
        
        // Track second event
        trackTestEvent()
        let secondEventContexts = getTrackedEventContexts()
        
        // Verify first event has old context
        let firstSourceContext = firstEventContexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let firstSourceData = firstSourceContext?.data as? [String: Any]
        XCTAssertEqual(firstSourceData?["accountId"] as? String, "account123")
        XCTAssertEqual(firstSourceData?["sourceId"] as? String, "mobile_app")
        
        // Verify second event has new context
        let secondSourceContext = secondEventContexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let secondSourceData = secondSourceContext?.data as? [String: Any]
        XCTAssertEqual(secondSourceData?["accountId"] as? String, "newAccount")
        XCTAssertEqual(secondSourceData?["sourceId"] as? String, "web_app")
    }
    
    // MARK: - Commerce Context Lifecycle
    
    func testCommerceContextLifecycle() {
        // Set up commerce contexts for first purchase
        surfsideEvent.addProduct(id: "product1", name: "Product 1", price: 10.0)
        surfsideEvent.addTransaction(id: "trans1", total: 10.0)
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Track first purchase event
        trackTestEvent()
        let firstEventContexts = getTrackedEventContexts()
        
        // Verify first event has commerce contexts
        let firstProductContext = firstEventContexts.first { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        let firstTransactionContext = firstEventContexts.first { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        let firstActionContext = firstEventContexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        
        XCTAssertNotNil(firstProductContext, "First event should have product context")
        XCTAssertNotNil(firstTransactionContext, "First event should have transaction context")
        XCTAssertNotNil(firstActionContext, "First event should have action context")
        
        // Clear commerce contexts
        surfsideEvent.clearCommerceContexts()
        
        // Reset mock emitter for second event
        mockEmitter.reset()
        
        // Track second event
        trackTestEvent()
        let secondEventContexts = getTrackedEventContexts()
        
        // Verify second event has no commerce contexts
        let secondProductContext = secondEventContexts.first { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        let secondTransactionContext = secondEventContexts.first { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        let secondActionContext = secondEventContexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        
        XCTAssertNil(secondProductContext, "Second event should not have product context")
        XCTAssertNil(secondTransactionContext, "Second event should not have transaction context")
        XCTAssertNil(secondActionContext, "Second event should not have action context")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmptyStringParameters() {
        // Test with empty string parameters
        surfsideEvent.source(accountId: "", sourceId: "")
        surfsideEvent.segment(segmentId: "", segmentVal: "")
        surfsideEvent.setLocation(id: "", city: "", state: "")
        
        // Track event
        trackTestEvent()
        let contexts = getTrackedEventContexts()
        
        // Verify contexts are still created (empty strings are valid)
        let sourceContext = contexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let segmentContext = contexts.first { $0.schema == "iglu:io.surfside/segment/jsonschema/1-0-0" }
        let locationContext = contexts.first { $0.schema == "iglu:io.surfside/location/jsonschema/1-0-0" }
        
        XCTAssertNotNil(sourceContext, "Source context should be created with empty strings")
        XCTAssertNotNil(segmentContext, "Segment context should be created with empty strings")
        XCTAssertNotNil(locationContext, "Location context should be created with empty strings")
    }
    
    func testNilOptionalParameters() {
        // Test with nil optional parameters
        surfsideEvent.addProduct(
            id: "product1",
            name: "Product 1",
            category: nil,
            price: 10.0,
            quantity: nil,
            sku: nil,
            variant: nil,
            brand: nil,
            inventory_status: nil,
            position: nil,
            list_price: nil,
            discount_amount: nil
        )
        
        // Track event
        trackTestEvent()
        let contexts = getTrackedEventContexts()
        
        // Verify product context is created with required fields only
        let productContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertNotNil(productContext, "Product context should be created with nil optional parameters")
        
        if let contextData = productContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "product1")
            XCTAssertEqual(contextData["name"] as? String, "Product 1")
            XCTAssertEqual(contextData["price"] as? Double, 10.0)
            XCTAssertNil(contextData["category"], "Category should be nil")
            XCTAssertNil(contextData["sku"], "SKU should be nil")
        }
    }
    
    // MARK: - Plugin Lifecycle Tests
    
    func testPluginRemovalClearsContexts() {
        // Set up contexts
        surfsideEvent.source(accountId: "account123", sourceId: "mobile_app")
        surfsideEvent.addProduct(id: "product1", name: "Product 1", price: 10.0)
        
        // Verify contexts exist
        let globalContexts = tracker.globalContexts?.getAll() ?? []
        XCTAssertEqual(globalContexts.count, 1, "Should have one global context")
        
        // Remove plugin
        tracker.plugins.remove(identifier: surfsideEvent.identifier)
        
        // Track event (should not have Surfside contexts)
        trackTestEvent()
        let contexts = getTrackedEventContexts()
        
        // Verify no Surfside contexts are attached
        let surfsideContexts = contexts.filter { $0.schema.contains("iglu:io.surfside/") }
        XCTAssertEqual(surfsideContexts.count, 0, "Should have no Surfside contexts after plugin removal")
    }
    
    // MARK: - Performance Tests
    
    func testLargeNumberOfProducts() {
        // Add many products
        for i in 1...100 {
            surfsideEvent.addProduct(id: "product\(i)", name: "Product \(i)", price: Double(i))
        }
        
        // Track event
        let startTime = CFAbsoluteTimeGetCurrent()
        trackTestEvent()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Verify all products are attached
        let contexts = getTrackedEventContexts()
        let productContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertEqual(productContexts.count, 100, "Should have 100 product contexts")
        
        // Verify performance (should complete in reasonable time)
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "Should complete within 1 second")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentContextUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent updates complete")
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        
        // Perform concurrent updates
        for i in 1...10 {
            group.enter()
            queue.async {
                self.surfsideEvent.source(accountId: "account\(i)", sourceId: "source\(i)")
                self.surfsideEvent.addProduct(id: "product\(i)", name: "Product \(i)", price: Double(i))
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Track event after all updates
            self.trackTestEvent()
            let contexts = self.getTrackedEventContexts()
            
            // Verify we have contexts (exact values may vary due to concurrency)
            let sourceContext = contexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
            let productContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
            
            XCTAssertNotNil(sourceContext, "Should have source context")
            XCTAssertGreaterThan(productContexts.count, 0, "Should have product contexts")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
