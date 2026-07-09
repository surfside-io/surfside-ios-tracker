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

/// The Surfside ClickHouse ingestion parses the self-describing envelopes positionally
/// and requires `schema` to precede `data`. Dictionary-based serialization emits keys in
/// hash order, so the envelopes are built with `SelfDescribingJson.envelope`/`jsonData`
/// instead; these tests pin that key order on the wire formats (`ue_pr` and `co`).
class SurfsidePayloadKeyOrderTests: XCTestCase {
    private let actionSchema = "iglu:io.surfside.commerce/action/jsonschema/1-0-0"

    /// JSONSerialization escapes `/` as `\/` inside JSON strings.
    private func escaped(_ schema: String) -> String {
        return schema.replacingOccurrences(of: "/", with: "\\/")
    }

    func testSelfDescribingJsonDataIsSchemaFirst() throws {
        let json = SelfDescribingJson(schema: actionSchema, andData: ["action": "purchase"])
        for _ in 0..<100 {
            let serialized = String(data: try json.jsonData(), encoding: .utf8)!
            XCTAssertTrue(
                serialized.hasPrefix("{\"schema\":\"\(escaped(actionSchema))\",\"data\":"),
                "envelope must serialize schema before data, got: \(serialized)")
        }
    }

    func testJsonDataRoundTripsThroughJSONParser() throws {
        let json = SelfDescribingJson(schema: actionSchema, andData: ["action": "purchase"])
        let parsed = try JSONSerialization.jsonObject(with: try json.jsonData()) as? [String: Any]
        XCTAssertEqual(parsed?["schema"] as? String, actionSchema)
        XCTAssertEqual((parsed?["data"] as? [String: Any])?["action"] as? String, "purchase")
    }

    func testEnvelopeEscapesSchemaString() throws {
        let envelope = try SelfDescribingJson.envelope(
            schema: "with \"quotes\" and \\backslash",
            dataJSON: Data("{}".utf8))
        let parsed = try JSONSerialization.jsonObject(with: envelope) as? [String: Any]
        XCTAssertEqual(parsed?["schema"] as? String, "with \"quotes\" and \\backslash")
    }

    func testUnstructEventPayloadIsSchemaFirstAtBothLevels() {
        let event = SelfDescribing(schema: actionSchema, payload: ["action": "purchase"])
        for _ in 0..<100 {
            let trackerEvent = TrackerEvent(event: event, state: TrackerState())
            let payload = Payload()
            trackerEvent.wrapProperties(to: payload, base64Encoded: false)

            guard let uePr = payload.dictionary[kSPUnstructured] as? String else {
                return XCTFail("no \(kSPUnstructured) in payload")
            }
            XCTAssertTrue(
                uePr.hasPrefix("{\"schema\":\"\(escaped(kSPUnstructSchema))\",\"data\":{\"schema\":\"\(escaped(actionSchema))\",\"data\":"),
                "unstruct envelope must be schema-first at both levels, got: \(uePr)")
        }
    }

    func testContextsPayloadIsSchemaFirstPerEntity() {
        let event = SelfDescribing(schema: actionSchema, payload: ["action": "purchase"])
        event.entities = [
            CommerceProductEntity(id: "p1", name: "Product"),
            CommerceTransactionEntity(id: "t1", revenue: "100"),
        ]
        for _ in 0..<100 {
            let trackerEvent = TrackerEvent(event: event, state: TrackerState())
            let payload = Payload()
            trackerEvent.wrapContexts(to: payload, base64Encoded: false)

            guard let co = payload.dictionary[kSPContext] as? String else {
                return XCTFail("no \(kSPContext) in payload")
            }
            XCTAssertTrue(
                co.hasPrefix("{\"schema\":\"\(escaped(kSPContextSchema))\",\"data\":["),
                "contexts envelope must be schema-first, got: \(co)")
            XCTAssertFalse(
                co.dropFirst().contains("{\"data\":"),
                "every entity must serialize schema before data, got: \(co)")
        }
    }
}
