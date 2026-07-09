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

/// Tracks a Surfside commerce purchase as a single, self-contained event.
///
/// This is the event-based counterpart to the stateful sequence
/// `SurfsidePlugin.addProduct(...)` + `addTransaction(...)` + `setCommerceAction("purchase")`.
/// It emits the **same wire payload** — a commerce-action self-describing event
/// (`iglu:io.surfside.commerce/action`, payload `{"action": "purchase"}`) carrying the
/// product and transaction context entities — but assembled explicitly in one
/// `tracker.track(event)` call, with no mutable accumulator state to set up or clear.
///
/// Modeled on Snowplow's own ecommerce events (see `Sources/Ecommerce/Events/`): the
/// event's own data becomes context entities via `entitiesForProcessing`, and the tracker
/// still attaches the ambient global contexts (source, segment, location, user) on top.
/// The schema and `{"action": "purchase"}` payload come from `SurfsideCommerceEvent`.
@objc(SPSurfsidePurchaseEvent)
public class SurfsidePurchaseEvent: SurfsideCommerceEvent {
    /// The transaction (order total, currency, etc.) for this purchase.
    @objc
    public var transaction: CommerceTransactionEntity
    /// The products included in the purchase.
    @objc
    public var products: [CommerceProductEntity]

    /// The product/transaction data ride along as context entities, matching the order the
    /// stateful path accumulates them (products first, then the transaction).
    override internal var entitiesForProcessing: [SelfDescribingJson]? {
        return products + [transaction]
    }

    /// - Parameters:
    ///   - transaction: The transaction context describing the order total, currency, etc.
    ///   - products: The products included in the purchase.
    @objc
    public init(transaction: CommerceTransactionEntity,
                products: [CommerceProductEntity]) {
        self.transaction = transaction
        self.products = products
        super.init(action: "purchase")
    }
}
