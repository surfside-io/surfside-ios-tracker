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

/// A User Context entity
@objc(SPUserEntity)
public class UserEntity: SelfDescribingJson {
    /// Schema for the User Context — the platform identity schema. Raw
    /// `email`/`phone` are hashed on the device (see `Uid2`) and never emitted.
    public static let schema = "iglu:io.surfside.identity/user/jsonschema/1-0-2"

    /// Initialize a new User entity. `email` and `phone` are accepted raw and
    /// hashed here, so raw directly-identifying information never leaves the
    /// device; an unusable value hashes to `nil` and is simply omitted. All
    /// other fields are emitted as given.
    /// - Parameters:
    ///   - userId: The user ID
    ///   - email: The user email (hashed to `hashed_email`, never emitted raw)
    ///   - phone: The user phone number (hashed to `hashed_phone`, never emitted raw)
    ///   - address: The user's address
    ///   - age: The user's age
    ///   - company: The user's company
    ///   - createdAt: When the user was created
    ///   - dateOfBirth: The user's date of birth
    ///   - firstName: The user's first name
    ///   - gender: The user's gender
    ///   - lastName: The user's last name
    @objc
    public init(
        userId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        age: String? = nil,
        company: String? = nil,
        createdAt: String? = nil,
        dateOfBirth: String? = nil,
        firstName: String? = nil,
        gender: String? = nil,
        lastName: String? = nil
    ) {
        var data: [String: Any] = [:]

        if let userId = userId {
            data["userId"] = userId
        }

        if let hashedEmail = Uid2.hashEmail(email) {
            data["hashed_email"] = hashedEmail
        }

        if let hashedPhone = Uid2.hashPhone(phone) {
            data["hashed_phone"] = hashedPhone
        }

        let profileFields: [(String, String?)] = [
            ("address", address),
            ("age", age),
            ("company", company),
            ("createdAt", createdAt),
            ("dateOfBirth", dateOfBirth),
            ("firstName", firstName),
            ("gender", gender),
            ("lastName", lastName)
        ]
        for (key, value) in profileFields {
            if let value = value {
                data[key] = value
            }
        }

        super.init(schema: UserEntity.schema, andData: data)
    }
}
