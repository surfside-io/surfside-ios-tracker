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

/// A Commerce Product Context
@objc(SPCommerceProductEntity)
public class CommerceProductEntity: SelfDescribingJson {
    /// Schema for the Commerce Product Context
    public static let schema = "iglu:io.surfside.commerce/product/jsonschema/1-0-0"
    
    /// Initialize a Commerce Product Context
    /// - Parameters:
    ///   - id: The product ID
    ///   - name: The name of the product
    ///   - list: The list the product belongs to
    ///   - brand: The brand associated with the product
    ///   - category: The category the product belongs to
    ///   - variant: The variant of the product
    ///   - price: The price of the product
    ///   - quantity: The quantity of the product
    ///   - coupon: The coupon code associated with the product
    ///   - position: The position of the product in a list or collection
    ///   - currency: The currency used for the product price
    @objc
    public init(
        id: String? = nil,
        name: String? = nil,
        list: String? = nil,
        brand: String? = nil,
        category: String? = nil,
        variant: String? = nil,
        price: NSNumber? = nil,
        quantity: NSNumber? = nil,
        coupon: String? = nil,
        position: NSNumber? = nil,
        currency: String? = nil
    ) {
        var data: [String: Any] = [:]
        
        if let id = id { data["id"] = id }
        if let name = name { data["name"] = name }
        if let list = list { data["list"] = list }
        if let brand = brand { data["brand"] = brand }
        if let category = category { data["category"] = category }
        if let variant = variant { data["variant"] = variant }
        if let price = price { data["price"] = price.doubleValue }
        if let quantity = quantity { data["quantity"] = quantity.intValue }
        if let coupon = coupon { data["coupon"] = coupon }
        if let position = position { data["position"] = position.intValue }
        if let currency = currency { data["currency"] = currency }
        
        super.init(schema: CommerceProductEntity.schema, andData: data)
    }
}
