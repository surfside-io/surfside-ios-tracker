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

/// A Commerce Promotion Context
@objc(SPCommercePromotionEntity)
public class CommercePromotionEntity: SelfDescribingJson {
    /// Schema for the Commerce Promotion Context
    public static let schema = "iglu:io.surfside.commerce/promotion/jsonschema/1-0-0"
    
    /// Initialize a Commerce Promotion Context
    /// - Parameters:
    ///   - id: The promotion ID
    ///   - name: The name of the promotion
    ///   - creative: The creative associated with the promotion
    ///   - position: The position of the promotion
    ///   - currency: The currency used for the promotion
    @objc
    public init(
        id: String? = nil,
        name: String? = nil,
        creative: String? = nil,
        position: String? = nil,
        currency: String? = nil
    ) {
        var data: [String: Any] = [:]
        
        if let id = id { data["id"] = id }
        if let name = name { data["name"] = name }
        if let creative = creative { data["creative"] = creative }
        if let position = position { data["position"] = position }
        if let currency = currency { data["currency"] = currency }
        
        super.init(schema: CommercePromotionEntity.schema, andData: data)
    }
}
