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

import Foundation

/// The shared base for Surfside's discrete commerce events.
///
/// On the wire, *every* Surfside commerce event is the same thing: a single
/// self-describing commerce-action event — schema
/// `iglu:io.surfside.commerce/action`, payload `{"action": <action>}` — carrying
/// some commerce context entities (products, a transaction, promotions, or
/// impressions). The event *type* is what encodes the action; the entities are
/// what vary. This base factors out the two invariant pieces (the schema and the
/// `{"action": …}` payload) so each concrete event only has to declare its action
/// string and assemble its own entities.
///
/// This is the event-based counterpart to the stateful `SurfsidePlugin` sequence
/// (`addProduct(...)` / `addTransaction(...)` + `setCommerceAction(...)`): same
/// wire output, but assembled explicitly in one `tracker.track(event)` call with
/// no mutable accumulator state to set up or clear.
///
/// This class is abstract in practice — it does not override
/// `entitiesForProcessing`, so a subclass must supply its entities. Instantiating
/// it directly would emit an action event with no entities attached.
///
/// Why a base rather than a protocol: `SelfDescribingAbstract` is an `@objc`
/// class and the tracker's `track(_:)` takes an `Event` subclass, so events must
/// be classes. Swift single inheritance means the common bits live here, and each
/// event subclasses this. The `action` is stored on `init` (rather than a
/// computed override per subclass) because it never changes for a given event
/// type — a `SurfsideAddToCartEvent` is always `"add"`.
public class SurfsideCommerceEvent: SelfDescribingAbstract {
    /// The commerce action this event represents (e.g. `"add"`, `"checkout"`,
    /// `"purchase"`). Encoded verbatim into the event payload as `{"action": …}`.
    let action: String

    /// - Parameter action: The commerce action string for this event type.
    ///   Subclasses pass a fixed value (they model one action each).
    init(action: String) {
        self.action = action
    }

    /// The self-describing event schema — always the commerce-action schema,
    /// identical to what `setCommerceAction(...)` produces today.
    override var schema: String {
        return CommerceActionEntity.schema
    }

    /// The event payload — the action string. The event type encodes the action,
    /// so callers never pass one.
    override var payload: [String : Any] {
        return ["action": action]
    }
}
