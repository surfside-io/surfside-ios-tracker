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

/// The Commerce Transaction Context
/// Represents information about an ecommerce related action that has taken place.
@objc(SPCommerceTransactionEntity)
public class CommerceTransactionEntity: SelfDescribingJson {
    /// Schema for the Commerce Transaction Context
    public static let schema = "iglu:io.surfside.commerce/transaction/jsonschema/1-0-0"
    
    /// Initialize a Commerce Transaction Context
    /// - Parameters:
    ///   - id: The transaction id
    ///   - affiliation: The store of affiliation from which this transaction occurred
    ///   - revenue: Specifies the total revenue or grand total associated with the transaction
    ///   - tax: The total tax associated with the transaction
    ///   - shipping: The shipping cost associated with the transaction
    ///   - coupon: The transaction coupon redeemed with the transaction
    ///   - list: The list that the associated products belong to
    ///   - step: A number representing a step in the checkout process
    ///   - option: Additional field describing the selected checkout option
    ///   - currency: The currency used for the transaction
    @objc
    public init(
        id: String? = nil,
        affiliation: String? = nil,
        revenue: NSNumber? = nil,
        tax: NSNumber? = nil,
        shipping: NSNumber? = nil,
        coupon: String? = nil,
        list: String? = nil,
        step: NSNumber? = nil,
        option: String? = nil,
        currency: String? = nil
    ) {
        var data: [String: Any] = [:]
        
        if let id = id { data["id"] = id }
        if let affiliation = affiliation { data["affiliation"] = affiliation }
        if let revenue = revenue { data["revenue"] = revenue.doubleValue }
        if let tax = tax { data["tax"] = tax.doubleValue }
        if let shipping = shipping { data["shipping"] = shipping.doubleValue }
        if let coupon = coupon { data["coupon"] = coupon }
        if let list = list { data["list"] = list }
        if let step = step { data["step"] = step.intValue }
        if let option = option { data["option"] = option }
        if let currency = currency { data["currency"] = currency }
        
        super.init(schema: CommerceTransactionEntity.schema, andData: data)
    }
}
