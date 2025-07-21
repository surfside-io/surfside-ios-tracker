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

/// An Identify User Event
/// Used when tracking a Surfside user identification
@objc(SPSurfsideIdentifyUserEvent)
public class IdentifyUserEvent: SelfDescribing {
    /// Schema for the Identify User Event
    public static let schema = "iglu:io.surfside.user/identify/jsonschema/1-0-0"
    
    /// The user ID
    @objc
    public let userId: String?
    
    /// The user email
    @objc
    public let email: String?
    
    /// The user phone number
    @objc
    public let phone: String?
    
    /// Initialize an Identify User Event
    /// - Parameters:
    ///   - userId: The user ID
    ///   - email: The user email
    ///   - phone: The user phone number
    @objc
    public init(userId: String? = nil, email: String? = nil, phone: String? = nil) {
        self.userId = userId
        self.email = email
        self.phone = phone
        
        var payload: [String: Any] = [:]
        if let userId = userId {
            payload["userId"] = userId
        }
        if let email = email {
            payload["email"] = email
        }
        if let phone = phone {
            payload["phone"] = phone
        }
        
        super.init(schema: IdentifyUserEvent.schema, payload: payload)
    }
}
