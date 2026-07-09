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

/// A Surfside Location Context entity
@objc(SPLocationEntity)
public class LocationEntity: SelfDescribingJson {
    /// Schema for the Location Entity
    public static let schema = "iglu:io.surfside.local-business/location/jsonschema/1-0-0"
    
    /// Initialize a new Location entity
    /// - Parameters:
    ///   - id: The unique identifier for the location
    ///   - latitude: The latitude coordinate of the location
    ///   - longitude: The longitude coordinate of the location
    ///   - countryCode: The ISO country code (e.g., "US", "CA")
    ///   - zip: The postal/zip code
    ///   - stateLabel: The full state name (e.g., "California")
    ///   - state: The state abbreviation (e.g., "CA")
    ///   - city: The city name
    ///   - street: The street address
    ///   - name: The location name or business name
    ///   - parent: The parent location identifier
    ///   - type: The type of location (e.g., "store", "warehouse")
    ///   - category: The category of location (e.g., "retail", "office")
    public init(
        id: String? = nil,
        latitude: String? = nil,
        longitude: String? = nil,
        countryCode: String? = nil,
        zip: String? = nil,
        stateLabel: String? = nil,
        state: String? = nil,
        city: String? = nil,
        street: String? = nil,
        name: String? = nil,
        parent: String? = nil,
        type: String? = nil,
        category: String? = nil
    ) {
        var data: [String: Any] = [:]
        
        if let id = id { data["id"] = id }
        if let latitude = latitude { data["latitude"] = latitude }
        if let longitude = longitude { data["longitude"] = longitude }
        if let countryCode = countryCode { data["country_code"] = countryCode }
        if let zip = zip { data["zip"] = zip }
        if let stateLabel = stateLabel { data["state_label"] = stateLabel }
        if let state = state { data["state"] = state }
        if let city = city { data["city"] = city }
        if let street = street { data["street"] = street }
        if let name = name { data["name"] = name }
        if let parent = parent { data["parent"] = parent }
        if let type = type { data["type"] = type }
        if let category = category { data["category"] = category }

        super.init(schema: LocationEntity.schema, andData: data)
    }
}
