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

class SurfsideCommerceEventTests: XCTestCase {
    
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
        
        tracker = Snowplow.createTracker(
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
        Snowplow.removeTracker(tracker)
        
        surfsideEvent = nil
        tracker = nil
        trackerNamespace = nil
        mockEmitter = nil
        
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func generateContextsForEvent(_ event: Event) -> [SelfDescribingJson] {
        return surfsideEvent.entitiesConfiguration?(event, "test") ?? []
    }
    
    private func trackTestEvent() -> Event {
        let event = Structured(category: "test", action: "test")
        tracker.track(event)
        return event
    }
    
    // MARK: - Commerce Context Tests - Product
    
    func testAddProductContext() {
        // Add product context
        surfsideEvent.addProduct(
            id: "product123",
            name: "Test Product",
            category: "Electronics",
            price: 29.99,
            quantity: 2,
            sku: "SKU123",
            variant: "Red",
            brand: "TestBrand",
            inventory_status: "in_stock",
            position: 1,
            list_price: 39.99,
            discount_amount: 10.0
        )
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify product context is generated
        let productContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertNotNil(productContext, "Product context should be generated")
        
        if let contextData = productContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "product123")
            XCTAssertEqual(contextData["name"] as? String, "Test Product")
            XCTAssertEqual(contextData["category"] as? String, "Electronics")
            XCTAssertEqual(contextData["price"] as? Double, 29.99)
            XCTAssertEqual(contextData["quantity"] as? Int, 2)
            XCTAssertEqual(contextData["sku"] as? String, "SKU123")
            XCTAssertEqual(contextData["variant"] as? String, "Red")
            XCTAssertEqual(contextData["brand"] as? String, "TestBrand")
            XCTAssertEqual(contextData["inventory_status"] as? String, "in_stock")
            XCTAssertEqual(contextData["position"] as? Int, 1)
            XCTAssertEqual(contextData["list_price"] as? Double, 39.99)
            XCTAssertEqual(contextData["discount_amount"] as? Double, 10.0)
        }
    }
    
    func testAddMultipleProducts() {
        // Add multiple products
        surfsideEvent.addProduct(id: "product1", name: "Product 1", price: 10.0)
        surfsideEvent.addProduct(id: "product2", name: "Product 2", price: 20.0)
        surfsideEvent.addProduct(id: "product3", name: "Product 3", price: 30.0)
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify all product contexts are generated
        let productContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertEqual(productContexts.count, 3, "Should have 3 product contexts")
        
        // Verify each product
        let productIds = productContexts.compactMap { context in
            (context.data as? [String: Any])?["id"] as? String
        }.sorted()
        XCTAssertEqual(productIds, ["product1", "product2", "product3"])
    }
    
    func testClearProductContexts() {
        // Add products
        surfsideEvent.addProduct(id: "product1", name: "Product 1", price: 10.0)
        surfsideEvent.addProduct(id: "product2", name: "Product 2", price: 20.0)
        
        // Verify products exist
        let contextsBeforeClear = generateContextsForEvent(Structured(category: "test", action: "test"))
        let productContextsBeforeClear = contextsBeforeClear.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertEqual(productContextsBeforeClear.count, 2)
        
        // Clear product contexts
        surfsideEvent.clearProductContexts()
        
        // Verify products are cleared
        let contextsAfterClear = generateContextsForEvent(Structured(category: "test", action: "test"))
        let productContextsAfterClear = contextsAfterClear.filter { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        XCTAssertEqual(productContextsAfterClear.count, 0)
    }
    
    // MARK: - Commerce Context Tests - Transaction
    
    func testAddTransactionContext() {
        // Add transaction context
        surfsideEvent.addTransaction(
            id: "trans123",
            total: 99.99,
            affiliation: "Online Store",
            tax_amount: 8.99,
            shipping_amount: 5.99,
            discount_amount: 10.0,
            discount_code: "SAVE10",
            order_sequence: 1,
            currency: "USD"
        )
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify transaction context is generated
        let transactionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        XCTAssertNotNil(transactionContext, "Transaction context should be generated")
        
        if let contextData = transactionContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "trans123")
            XCTAssertEqual(contextData["total"] as? Double, 99.99)
            XCTAssertEqual(contextData["affiliation"] as? String, "Online Store")
            XCTAssertEqual(contextData["tax_amount"] as? Double, 8.99)
            XCTAssertEqual(contextData["shipping_amount"] as? Double, 5.99)
            XCTAssertEqual(contextData["discount_amount"] as? Double, 10.0)
            XCTAssertEqual(contextData["discount_code"] as? String, "SAVE10")
            XCTAssertEqual(contextData["order_sequence"] as? Int, 1)
            XCTAssertEqual(contextData["currency"] as? String, "USD")
        }
    }
    
    func testTransactionContextReplacement() {
        // Add initial transaction
        surfsideEvent.addTransaction(id: "trans123", total: 99.99)
        
        // Add new transaction (should replace the previous one)
        surfsideEvent.addTransaction(id: "trans456", total: 199.99)
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify only one transaction context exists with the new values
        let transactionContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        XCTAssertEqual(transactionContexts.count, 1, "Should have only one transaction context")
        
        if let contextData = transactionContexts.first?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "trans456")
            XCTAssertEqual(contextData["total"] as? Double, 199.99)
        }
    }
    
    // MARK: - Commerce Context Tests - Action
    
    func testSetCommerceAction() {
        // Set commerce action
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify action context is generated
        let actionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        XCTAssertNotNil(actionContext, "Commerce action context should be generated")
        
        if let contextData = actionContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["action"] as? String, "purchase")
        }
    }
    
    func testCommerceActionReplacement() {
        // Set initial action
        surfsideEvent.setCommerceAction(action: "add_to_cart")
        
        // Set new action (should replace the previous one)
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify only one action context exists with the new value
        let actionContexts = contexts.filter { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        XCTAssertEqual(actionContexts.count, 1, "Should have only one action context")
        
        if let contextData = actionContexts.first?.data as? [String: Any] {
            XCTAssertEqual(contextData["action"] as? String, "purchase")
        }
    }
    
    // MARK: - Commerce Context Tests - Promotion
    
    func testAddPromotionContext() {
        // Add promotion context
        surfsideEvent.addPromotion(
            id: "promo123",
            name: "Summer Sale",
            creative: "banner_ad",
            position: "top",
            type: "discount"
        )
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify promotion context is generated
        let promotionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_promotion/jsonschema/1-0-0" }
        XCTAssertNotNil(promotionContext, "Promotion context should be generated")
        
        if let contextData = promotionContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "promo123")
            XCTAssertEqual(contextData["name"] as? String, "Summer Sale")
            XCTAssertEqual(contextData["creative"] as? String, "banner_ad")
            XCTAssertEqual(contextData["position"] as? String, "top")
            XCTAssertEqual(contextData["type"] as? String, "discount")
        }
    }
    
    // MARK: - Commerce Context Tests - Impression
    
    func testAddImpressionContext() {
        // Add impression context
        surfsideEvent.addImpression(
            id: "imp123",
            list: "search_results",
            position: 1,
            sku: "SKU123"
        )
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify impression context is generated
        let impressionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_impression/jsonschema/1-0-0" }
        XCTAssertNotNil(impressionContext, "Impression context should be generated")
        
        if let contextData = impressionContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["id"] as? String, "imp123")
            XCTAssertEqual(contextData["list"] as? String, "search_results")
            XCTAssertEqual(contextData["position"] as? Int, 1)
            XCTAssertEqual(contextData["sku"] as? String, "SKU123")
        }
    }
    
    // MARK: - Commerce Context Tests - Clear All
    
    func testClearAllCommerceContexts() {
        // Add various commerce contexts
        surfsideEvent.addProduct(id: "product1", name: "Product 1", price: 10.0)
        surfsideEvent.addTransaction(id: "trans123", total: 99.99)
        surfsideEvent.setCommerceAction(action: "purchase")
        surfsideEvent.addPromotion(id: "promo123", name: "Summer Sale")
        surfsideEvent.addImpression(id: "imp123", list: "search_results")
        
        // Verify all contexts exist
        let contextsBeforeClear = generateContextsForEvent(Structured(category: "test", action: "test"))
        XCTAssertGreaterThan(contextsBeforeClear.count, 0, "Should have commerce contexts before clear")
        
        // Clear all commerce contexts
        surfsideEvent.clearCommerceContexts()
        
        // Verify all commerce contexts are cleared
        let contextsAfterClear = generateContextsForEvent(Structured(category: "test", action: "test"))
        let commerceContextsAfterClear = contextsAfterClear.filter { context in
            context.schema.contains("iglu:io.surfside/commerce_")
        }
        XCTAssertEqual(commerceContextsAfterClear.count, 0, "All commerce contexts should be cleared")
    }
    
    // MARK: - Integration Tests - Commerce + Global Contexts
    
    func testCommerceContextsWithGlobalContexts() {
        // Set global contexts
        surfsideEvent.source(accountId: "account123", sourceId: "source456")
        surfsideEvent.segment(segmentId: "segment123", segmentVal: "high_value")
        
        // Add commerce contexts
        surfsideEvent.addProduct(id: "product123", name: "Test Product", price: 29.99)
        surfsideEvent.addTransaction(id: "trans123", total: 29.99)
        surfsideEvent.setCommerceAction(action: "purchase")
        
        // Track an event
        trackTestEvent()
        
        // Verify the event has both global and commerce contexts
        let trackedEvent = mockEmitter.trackedEvents.first
        let contexts = trackedEvent?.contexts ?? []
        
        // Check for global contexts
        let sourceContext = contexts.first { $0.schema == "iglu:io.surfside/source/jsonschema/1-0-0" }
        let segmentContext = contexts.first { $0.schema == "iglu:io.surfside/segment/jsonschema/1-0-0" }
        
        // Check for commerce contexts
        let productContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_product/jsonschema/1-0-0" }
        let transactionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_transaction/jsonschema/1-0-0" }
        let actionContext = contexts.first { $0.schema == "iglu:io.surfside/commerce_action/jsonschema/1-0-0" }
        
        XCTAssertNotNil(sourceContext, "Source context should be attached")
        XCTAssertNotNil(segmentContext, "Segment context should be attached")
        XCTAssertNotNil(productContext, "Product context should be attached")
        XCTAssertNotNil(transactionContext, "Transaction context should be attached")
        XCTAssertNotNil(actionContext, "Action context should be attached")
    }
    
    // MARK: - User Context Tests
    
    func testSetUserContext() {
        // Set user context
        surfsideEvent.setUser(
            userId: "user123",
            email: "test@example.com",
            firstName: "John",
            lastName: "Doe",
            phone: "555-1234",
            birthDate: "1990-01-01",
            gender: "M"
        )
        
        // Generate contexts for a test event
        let testEvent = Structured(category: "test", action: "test")
        let contexts = generateContextsForEvent(testEvent)
        
        // Verify user context is generated
        let userContext = contexts.first { $0.schema == "iglu:io.surfside/user/jsonschema/1-0-0" }
        XCTAssertNotNil(userContext, "User context should be generated")
        
        if let contextData = userContext?.data as? [String: Any] {
            XCTAssertEqual(contextData["userId"] as? String, "user123")
            XCTAssertEqual(contextData["email"] as? String, "test@example.com")
            XCTAssertEqual(contextData["firstName"] as? String, "John")
            XCTAssertEqual(contextData["lastName"] as? String, "Doe")
            XCTAssertEqual(contextData["phone"] as? String, "555-1234")
            XCTAssertEqual(contextData["birthDate"] as? String, "1990-01-01")
            XCTAssertEqual(contextData["gender"] as? String, "M")
        }
    }
}
