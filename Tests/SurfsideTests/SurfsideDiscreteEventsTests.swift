//  Copyright (c) 2022-2025 Surfside Solutions Inc, Snowplow Analytics Ltd
//  All rights reserved.
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

/// Unit tests for the discrete Surfside commerce events (`Sources/Surfside/Events/`).
///
/// Every one of these events is, on the wire, a commerce-action self-describing event
/// (`iglu:io.surfside.commerce/action`, payload `{"action": <action>}`) carrying context
/// entities. These tests pin the three things a subclass is responsible for: the shared
/// schema, the action string, and the entity set (identity + order) supplied via
/// `entitiesForProcessing`. `@testable` gives access to the `internal`
/// `entitiesForProcessing` and `payload`/`schema` members.
class SurfsideDiscreteEventsTests: XCTestCase {

    // MARK: - Fixtures

    private func product(_ id: String) -> CommerceProductEntity {
        return CommerceProductEntity(id: id, name: "Product \(id)", price: NSNumber(value: 9.99))
    }

    private func transaction(_ id: String) -> CommerceTransactionEntity {
        return CommerceTransactionEntity(id: id, revenue: "100")
    }

    private func promotion(_ id: String) -> CommercePromotionEntity {
        return CommercePromotionEntity(id: id, name: "Promo \(id)")
    }

    private func impression(_ id: String) -> CommerceImpressionEntity {
        return CommerceImpressionEntity(id: id, name: "Impression \(id)")
    }

    /// The schema URIs of an event's context entities, in order.
    private func entitySchemas(_ event: SurfsideCommerceEvent) -> [String] {
        return (event.entitiesForProcessing ?? []).map { $0.schema }
    }

    /// Asserts the invariant shared by every commerce event: the action schema and the
    /// expected action string in the payload.
    private func assertActionEnvelope(_ event: SurfsideCommerceEvent,
                                      action: String,
                                      file: StaticString = #file,
                                      line: UInt = #line) {
        XCTAssertEqual(event.schema, CommerceActionEntity.schema, file: file, line: line)
        XCTAssertEqual(event.payload["action"] as? String, action, file: file, line: line)
    }

    // MARK: - Product-only events

    func testProductViewEvent() {
        let event = SurfsideProductViewEvent(products: [product("p1"), product("p2")])
        assertActionEnvelope(event, action: "detail")
        XCTAssertEqual(entitySchemas(event),
                       [CommerceProductEntity.schema, CommerceProductEntity.schema])
        XCTAssertEqual(event.entitiesForProcessing?.first?.data["id"] as? String, "p1")
    }

    func testAddToCartEvent() {
        let event = SurfsideAddToCartEvent(products: [product("p1")])
        assertActionEnvelope(event, action: "add")
        XCTAssertEqual(entitySchemas(event), [CommerceProductEntity.schema])
    }

    func testCartViewEvent() {
        let event = SurfsideCartViewEvent(products: [product("p1")])
        assertActionEnvelope(event, action: "cart")
        XCTAssertEqual(entitySchemas(event), [CommerceProductEntity.schema])
    }

    func testRemoveFromCartEvent() {
        let event = SurfsideRemoveFromCartEvent(products: [product("p1")])
        assertActionEnvelope(event, action: "remove")
        XCTAssertEqual(entitySchemas(event), [CommerceProductEntity.schema])
    }

    func testProductClickEvent() {
        let event = SurfsideProductClickEvent(products: [product("p1")])
        assertActionEnvelope(event, action: "click")
        XCTAssertEqual(entitySchemas(event), [CommerceProductEntity.schema])
    }

    // MARK: - Transaction-carrying events

    func testPurchaseEvent() {
        let event = SurfsidePurchaseEvent(transaction: transaction("t1"),
                                          products: [product("p1"), product("p2")])
        assertActionEnvelope(event, action: "purchase")
        // Products come first, then the transaction — the order the stateful path uses.
        XCTAssertEqual(entitySchemas(event),
                       [CommerceProductEntity.schema,
                        CommerceProductEntity.schema,
                        CommerceTransactionEntity.schema])
    }

    func testCheckoutEventWithTransaction() {
        let event = SurfsideCheckoutEvent(products: [product("p1")],
                                          transaction: transaction("t1"))
        assertActionEnvelope(event, action: "checkout")
        XCTAssertEqual(entitySchemas(event),
                       [CommerceProductEntity.schema, CommerceTransactionEntity.schema])
    }

    func testCheckoutEventWithoutTransaction() {
        let event = SurfsideCheckoutEvent(products: [product("p1")])
        assertActionEnvelope(event, action: "checkout")
        // With no transaction, only the products ride along.
        XCTAssertEqual(entitySchemas(event), [CommerceProductEntity.schema])
    }

    func testRefundEvent() {
        let event = SurfsideRefundEvent(transaction: transaction("t1"),
                                        products: [product("p1")])
        assertActionEnvelope(event, action: "refund")
        XCTAssertEqual(entitySchemas(event),
                       [CommerceProductEntity.schema, CommerceTransactionEntity.schema])
    }

    func testRefundEventFullOrderHasNoProducts() {
        let event = SurfsideRefundEvent(transaction: transaction("t1"), products: [])
        assertActionEnvelope(event, action: "refund")
        XCTAssertEqual(entitySchemas(event), [CommerceTransactionEntity.schema])
    }

    // MARK: - Promotion / impression events

    func testPromotionClickEvent() {
        let event = SurfsidePromotionClickEvent(promotions: [promotion("pr1")])
        assertActionEnvelope(event, action: "promo_click")
        XCTAssertEqual(entitySchemas(event), [CommercePromotionEntity.schema])
    }

    func testPromotionViewEvent() {
        let event = SurfsidePromotionViewEvent(promotions: [promotion("pr1")])
        assertActionEnvelope(event, action: "promotion_view")
        XCTAssertEqual(entitySchemas(event), [CommercePromotionEntity.schema])
    }

    func testImpressionEvent() {
        let event = SurfsideImpressionEvent(impressions: [impression("i1"), impression("i2")])
        assertActionEnvelope(event, action: "impression")
        XCTAssertEqual(entitySchemas(event),
                       [CommerceImpressionEntity.schema, CommerceImpressionEntity.schema])
    }
}
