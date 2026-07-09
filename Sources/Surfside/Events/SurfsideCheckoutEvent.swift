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

/// Tracks a checkout step — the `"checkout"` commerce action.
///
/// The checkout `step` and `option` (e.g. "shipping", "payment") live on the
/// `CommerceTransactionEntity`, so a checkout carries both the products being
/// checked out and a transaction describing the step. The transaction is optional
/// because a checkout can be tracked before any order total exists (e.g. the very
/// first step). See `SurfsideCommerceEvent` for the shared schema/payload behavior.
@objc(SPSurfsideCheckoutEvent)
public class SurfsideCheckoutEvent: SurfsideCommerceEvent {
    /// The transaction describing the checkout step/option and any known totals.
    @objc
    public var transaction: CommerceTransactionEntity?
    /// The product(s) being checked out.
    @objc
    public var products: [CommerceProductEntity]

    /// Products ride first, then the transaction (when present), matching the
    /// order the stateful path accumulates them. `compactMap` on the optional
    /// transaction drops it cleanly when `nil`.
    override internal var entitiesForProcessing: [SelfDescribingJson]? {
        return products + [transaction].compactMap { $0 }
    }

    /// - Parameters:
    ///   - products: The product(s) being checked out.
    ///   - transaction: The transaction describing the checkout step/option. Optional.
    @objc
    public init(products: [CommerceProductEntity],
                transaction: CommerceTransactionEntity? = nil) {
        self.products = products
        self.transaction = transaction
        super.init(action: "checkout")
    }
}
